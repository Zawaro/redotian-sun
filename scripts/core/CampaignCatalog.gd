extends Node

## CampaignCatalog autoload — the registry for a game's campaigns and missions,
## mirroring FactionCatalog/EntityFactory/TerrainCatalog data-set loading. Scans
## `<layer root>/campaigns/` and `<layer root>/missions/`, caches each by id
## (later roots win), and resets on `game_changed`. Missing directories and
## failed loads warn and continue — never crash gameplay.

var _campaigns: Dictionary = {}
var _missions: Dictionary = {}
var _data_sets: Array[String] = []


func _ready() -> void:
    GameContext.game_changed.connect(_on_game_changed)
    _load_from_context()


func _load_from_context() -> void:
    reset_content()
    var def := GameContext.current
    if def == null:
        return
    for root in def.data_sets:
        var base := root.trim_suffix("/")
        register_data_set(base + "/campaigns/", base + "/missions/")


func _on_game_changed(_def: GameDefinition) -> void:
    _load_from_context()


## Clears all registered campaigns and missions. Called before every
## (re)registration.
func reset_content() -> void:
    _campaigns.clear()
    _missions.clear()
    _data_sets.clear()


## Registers a campaigns/missions directory pair, recursing into subdirectories
## and caching each resource by id (later roots win). Idempotent per campaign
## path.
func register_data_set(campaigns_path: String, missions_path: String) -> void:
    if _data_sets.has(campaigns_path):
        return
    _data_sets.append(campaigns_path)
    _scan_directory(campaigns_path, _campaigns, "campaign", _is_campaign)
    _scan_directory(missions_path, _missions, "mission", _is_mission)


## The campaign registered under `campaign_id`, or null.
func get_campaign(campaign_id: String) -> Campaign:
    return _campaigns.get(campaign_id) as Campaign


## The mission registered under `mission_id`, or null.
func get_mission(mission_id: String) -> Mission:
    return _missions.get(mission_id) as Mission


## All registered campaigns, ordered by id.
func list_campaigns() -> Array[Campaign]:
    var out: Array[Campaign] = []
    for campaign in _campaigns.values():
        out.append(campaign as Campaign)
    out.sort_custom(func(a: Campaign, b: Campaign) -> bool: return a.id < b.id)
    return out


func _scan_directory(path: String, cache: Dictionary, kind: String, is_valid: Callable) -> void:
    var dir := DirAccess.open(path)
    if not dir:
        push_warning("CampaignCatalog: cannot open directory: %s" % path)
        return
    dir.list_dir_begin()
    var file_name := dir.get_next()
    while file_name != "":
        var resource_path := file_name.trim_suffix(".remap")
        if resource_path.ends_with(".tres"):
            var resource := load(path.path_join(resource_path))
            if resource != null and is_valid.call(resource):
                cache[(resource as Resource).get("id")] = resource
            else:
                push_warning(
                    "CampaignCatalog: %s is not a %s" % [path.path_join(resource_path), kind]
                )
        elif dir.current_is_dir() and not file_name.begins_with("."):
            _scan_directory(path.path_join(file_name), cache, kind, is_valid)
        file_name = dir.get_next()
    dir.list_dir_end()


static func _is_campaign(resource: Object) -> bool:
    return resource is Campaign


static func _is_mission(resource: Object) -> bool:
    return resource is Mission
