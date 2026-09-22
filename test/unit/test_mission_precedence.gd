extends Node

# Mission override precedence via PlayerManager.begin_mission — mission credits
# and house beat the active game's GlobalRules / default roster. PlayerManager
# is rebuilt to defaults after every test so later suites see clean state.

var _gc: Node = null
var _pm: Node = null
var _fc: Node = null


func _guard() -> bool:
    if _gc == null or _pm == null or _fc == null:
        TestHelper.fail("GameContext/PlayerManager/FactionCatalog not injected")
        return false
    return true


func _cleanup() -> void:
    _pm._players.clear()
    _pm._local_player_id = 0
    _pm._init_defaults()


func _make_map_config(local_credits: int, local_house: String) -> MapConfig:
    var config := MapConfig.new()
    var local := MapConfig.PlayerConfig.new()
    local.player_id = 0
    local.starting_credits = local_credits
    local.faction_id = local_house
    config.players.append(local)
    var ai := MapConfig.PlayerConfig.new()
    ai.player_id = 1
    ai.starting_credits = 999
    config.players.append(ai)
    return config


func test_mission_credits_beat_global() -> void:
    if not _guard():
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _gc.select_game("ts")
    TestHelper.assert_eq(_gc.rules.starting_credits, 10000, "ts global credits are 10000")
    var mission := Mission.new()
    mission.starting_credits = 50
    _pm.begin_mission(mission)
    var player: PlayerData = _pm.get_player_data(0)
    TestHelper.assert_eq(player.free_credits, 50, "mission credits override global rules")
    _cleanup()
    TestHelper.restore_game_context(_gc, snap)


func test_inherit_credits_use_global_rules() -> void:
    if not _guard():
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _gc.select_game("ts")
    var mission := Mission.new()
    mission.starting_credits = -1
    _pm.begin_mission(mission)
    var player: PlayerData = _pm.get_player_data(0)
    TestHelper.assert_eq(
        player.free_credits, _gc.rules.starting_credits, "mission -1 inherits global rules"
    )
    _cleanup()
    TestHelper.restore_game_context(_gc, snap)


func test_mission_house_overrides_default_roster() -> void:
    if not _guard():
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _gc.select_game("ts")
    var mission := Mission.new()
    mission.player_house = "Nod"
    _pm.begin_mission(mission)
    var player: PlayerData = _pm.get_player_data(0)
    TestHelper.assert_eq(player.faction_id, "Nod", "mission player_house overrides the roster")
    _cleanup()
    TestHelper.restore_game_context(_gc, snap)


func test_empty_house_uses_default_roster() -> void:
    if not _guard():
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _gc.select_game("ts")
    var playable: Array[Faction] = _fc.get_playable()
    TestHelper.assert_true(playable.size() > 0, "ts has a playable roster")
    var mission := Mission.new()
    mission.player_house = ""
    _pm.begin_mission(mission)
    var player: PlayerData = _pm.get_player_data(0)
    TestHelper.assert_eq(
        player.faction_id, playable[0].id, "empty player_house takes the first playable faction"
    )
    _cleanup()
    TestHelper.restore_game_context(_gc, snap)


func test_map_credits_used_when_mission_inherits() -> void:
    if not _guard():
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _gc.select_game("ts")
    var mission := Mission.new()
    mission.starting_credits = -1
    mission.player_house = ""
    var config := _make_map_config(200, "")
    _pm.begin_mission(mission, config)
    TestHelper.assert_eq(
        _pm.get_player_data(0).free_credits, 200, "map credits fill the mission's -1 inherit"
    )
    config.free()
    _cleanup()
    TestHelper.restore_game_context(_gc, snap)


func test_mission_credits_beat_map_config() -> void:
    if not _guard():
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _gc.select_game("ts")
    var mission := Mission.new()
    mission.starting_credits = 50
    mission.player_house = ""
    var config := _make_map_config(200, "")
    _pm.begin_mission(mission, config)
    TestHelper.assert_eq(
        _pm.get_player_data(0).free_credits, 50, "mission credits beat the map override"
    )
    config.free()
    _cleanup()
    TestHelper.restore_game_context(_gc, snap)


func test_map_house_used_when_mission_house_empty() -> void:
    if not _guard():
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _gc.select_game("ts")
    var mission := Mission.new()
    mission.player_house = ""
    var config := _make_map_config(0, "Nod")
    _pm.begin_mission(mission, config)
    TestHelper.assert_eq(
        _pm.get_player_data(0).faction_id, "Nod", "map house fills the mission's empty house"
    )
    config.free()
    _cleanup()
    TestHelper.restore_game_context(_gc, snap)


func test_mission_house_beats_map_house() -> void:
    if not _guard():
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _gc.select_game("ts")
    var mission := Mission.new()
    mission.player_house = "GDI"
    var config := _make_map_config(0, "Nod")
    _pm.begin_mission(mission, config)
    TestHelper.assert_eq(
        _pm.get_player_data(0).faction_id, "GDI", "mission house beats the map house"
    )
    config.free()
    _cleanup()
    TestHelper.restore_game_context(_gc, snap)


func test_no_map_config_uses_global() -> void:
    if not _guard():
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _gc.select_game("ts")
    var mission := Mission.new()
    mission.starting_credits = -1
    _pm.begin_mission(mission)
    TestHelper.assert_eq(
        _pm.get_player_data(0).free_credits,
        _gc.rules.starting_credits,
        "no map config inherits global rules"
    )
    _cleanup()
    TestHelper.restore_game_context(_gc, snap)
