extends Node

const _MAP_CONFIG_SCRIPT_PATH: String = "res://scripts/data/MapConfig.gd"

var _players: Dictionary = {}
var _local_player_id: int = 0


func get_local_player_id() -> int:
    return _local_player_id


func get_player_data(player_id: int) -> PlayerData:
    if not _players.has(player_id):
        var data := PlayerData.new()
        data.player_id = player_id
        _players[player_id] = data
    return _players[player_id] as PlayerData


func is_enemy(a_id: int, b_id: int) -> bool:
    var a := get_player_data(a_id)
    var b := get_player_data(b_id)
    return a.team_id != b.team_id


func get_all_players() -> Array[PlayerData]:
    var result: Array[PlayerData] = []
    for key in _players:
        result.append(_players[key] as PlayerData)
    return result


func get_players_by_team(team_id: int) -> Array[PlayerData]:
    var result: Array[PlayerData] = []
    for key in _players:
        var data := _players[key] as PlayerData
        if data.team_id == team_id:
            result.append(data)
    return result


func _ready() -> void:
    var map_config: Node = _find_map_config()
    if map_config:
        _init_from_map_config(map_config)
    else:
        _init_defaults()


func _find_map_config() -> Node:
    var tree := get_tree()
    if not tree:
        return null
    var root := tree.current_scene
    if not root:
        return null
    var config_script: GDScript = load(_MAP_CONFIG_SCRIPT_PATH) as GDScript
    if not config_script:
        return null
    for child in root.get_children():
        if child.get_script() == config_script:
            return child
    return null


func _init_from_map_config(config: Node) -> void:
    var rules: GlobalRules = _get_global_rules()
    var player_configs: Array = config.get("players") as Array
    for pc in player_configs:
        var pc_node = pc
        if not pc_node:
            continue
        var default_credits: int = rules.starting_credits if rules else 0
        var pc_credits: int = pc_node.get("starting_credits")
        var credits: int = pc_credits if pc_credits >= 0 else default_credits
        var data := _make_player(
            pc_node.get("player_id"),
            pc_node.get("faction_id"),
            pc_node.get("color"),
            pc_node.get("team_id"),
            pc_node.get("spawn_index"),
            pc_node.get("display_name"),
            pc_node.get("is_bot"),
            credits,
        )
        _players[data.player_id] = data
        if not data.is_bot and _local_player_id == 0:
            _local_player_id = data.player_id

    if _local_player_id == 0 and not _players.is_empty():
        var first_id: int = _players.keys()[0] as int
        var first: PlayerData = _players[first_id] as PlayerData
        if first.is_bot:
            push_warning("[PlayerManager] All players are bots, setting local player to first bot")
            _local_player_id = first_id


func _make_player(
    player_id: int,
    faction_id: String,
    color: Color,
    team_id: int,
    spawn_index: int,
    display_name: String,
    is_bot: bool,
    credits: int,
) -> PlayerData:
    var data := PlayerData.new()
    data.player_id = player_id
    data.faction_id = faction_id
    data.color = color
    data.team_id = team_id
    data.spawn_index = spawn_index
    data.display_name = display_name
    data.is_bot = is_bot
    data.credits = credits
    return data


func _init_defaults() -> void:
    var rules: GlobalRules = _get_global_rules()
    var starting_credits: int = rules.starting_credits if rules else 10000

    var human := _make_player(
        0, "GDI", Color(0.3, 0.4, 0.6), 1, 0, "Player", false, starting_credits
    )
    _players[0] = human

    var ai := _make_player(
        1, "Nod", Color(0.6, 0.3, 0.3), 2, 1, "AI Opponent", true, starting_credits
    )
    _players[1] = ai

    _local_player_id = 0


func _get_global_rules() -> GlobalRules:
    var entity_factory := get_node_or_null("/root/EntityFactory")
    if entity_factory and entity_factory.has_method("get_global_rules"):
        return entity_factory.get_global_rules() as GlobalRules
    return null
