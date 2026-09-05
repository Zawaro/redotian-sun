extends Node

# GameContext tests — resolution order (flag → persisted → default), discovery,
# select/unload lifecycle, rules access contract, persistence, reset-cycle
# completeness, and the per-game boot smoke. Global state is snapshotted and
# restored around every mutating test so suite order stays irrelevant.

const FIXTURES: String = "res://test/fixtures/gamectx"

var _gc: Node = null
var _ef: Node = null
var _tc: Node = null
var _am: Node = null


func _ready() -> void:
    if has_node("/root/GameContext"):
        _gc = get_node("/root/GameContext")
    if has_node("/root/EntityFactory"):
        _ef = get_node("/root/EntityFactory")
    if has_node("/root/TerrainCatalog"):
        _tc = get_node("/root/TerrainCatalog")
    if has_node("/root/AudioManager"):
        _am = get_node("/root/AudioManager")


# --- resolution order (static, pure) ---------------------------------------


func test_flag_parsed_from_arg_list():
    TestHelper.assert_eq(GameContext.extract_flag_id(PackedStringArray(["--game", "ts"])), "ts")
    TestHelper.assert_eq(
        GameContext.extract_flag_id(PackedStringArray(["--headless", "--game", "ra2"])), "ra2"
    )


func test_flag_absent_or_valueless_returns_empty():
    TestHelper.assert_eq(GameContext.extract_flag_id(PackedStringArray([])), "")
    TestHelper.assert_eq(GameContext.extract_flag_id(PackedStringArray(["--game"])), "")
    TestHelper.assert_eq(GameContext.extract_flag_id(PackedStringArray(["--other", "x"])), "")


func test_flag_wins_over_persisted_and_default():
    TestHelper.assert_eq(GameContext.resolve_game_id("a", "b", ["a", "b", "ts"]), "a")


func test_persisted_used_when_no_flag():
    TestHelper.assert_eq(GameContext.resolve_game_id("", "b", ["b", "ts"]), "b")


func test_default_used_when_nothing_set():
    TestHelper.assert_eq(GameContext.resolve_game_id("", "", ["ra2", "ts"]), "ts")


func test_unknown_flag_falls_back_to_persisted():
    TestHelper.assert_eq(GameContext.resolve_game_id("nope", "b", ["b", "ts"]), "b")


func test_unknown_persisted_falls_back_to_default():
    TestHelper.assert_eq(GameContext.resolve_game_id("", "nope", ["ra2", "ts"]), "ts")


func test_default_returned_even_when_not_discovered():
    # A missing default game cannot be repaired by resolution; select refuses.
    TestHelper.assert_eq(GameContext.resolve_game_id("", "", ["other"]), "ts")


# --- discovery ---------------------------------------------------------------


func test_discovery_skips_definition_with_mismatched_id():
    var gc2: Node = load("res://scripts/core/GameContext.gd").new()
    gc2._scan_games_root(FIXTURES + "/discovery")
    TestHelper.assert_true(gc2._defs.has("good_id"), "matching definition registered")
    TestHelper.assert_true(
        not gc2._defs.has("bad_id"), "directory name registered, not file content id"
    )
    TestHelper.assert_true(not gc2._defs.has("wrong_id"), "mismatched definition skipped")
    TestHelper.assert_eq(gc2.list_games().size(), 1, "only the valid definition is listed")
    gc2.free()


func test_list_games_contains_ts_sorted_by_id():
    TestHelper.assert_true(_gc != null, "GameContext autoload present")
    if not _gc:
        return
    var games: Array = _gc.list_games()
    TestHelper.assert_true(games.size() >= 1, "at least the default game is discovered")
    var ids: Array = []
    for def in games:
        ids.append(def.id)
    TestHelper.assert_true(ids.has("ts"), "ts discovered from res://games/ts/game.tres")
    for i in range(1, ids.size()):
        TestHelper.assert_true(ids[i - 1] < ids[i], "list_games sorted by id")


# --- select / unload lifecycle ----------------------------------------------


func _make_def(id: String, roots: Array) -> GameDefinition:
    var def := GameDefinition.new()
    def.id = id
    def.rules = load(FIXTURES + "/rules.tres") as GlobalRules
    for root: String in roots:
        def.data_sets.append(root)
    return def


func _track_emissions() -> Array:
    var emitted: Array = []
    _gc.game_changed.connect(func(def: GameDefinition) -> void: emitted.append(def))
    return emitted


func test_select_game_switches_roster_and_rules():
    TestHelper.assert_true(_gc != null and _ef != null, "autoloads present")
    if not _gc or not _ef:
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    var emitted := _track_emissions()
    var def := _make_def("fake_a", [FIXTURES + "/game_a/"])
    _gc._defs["fake_a"] = def
    _gc.select_game("fake_a")
    TestHelper.assert_true(_gc.current == def, "current points at the selected definition")
    TestHelper.assert_true(_ef.get_entity_data("A_UNIT") != null, "fake roster registered")
    TestHelper.assert_true(
        _ef.get_entity_data("GDI_LIGHT_INFANTRY") == null, "previous roster cleared"
    )
    TestHelper.assert_true(_ef._global_rules == def.rules, "rules rebound to the new game")
    TestHelper.assert_eq(emitted.size(), 1, "game_changed emitted exactly once")
    if emitted.size() == 1:
        TestHelper.assert_true(emitted[0] == def, "game_changed carries the new definition")
    TestHelper.restore_game_context(_gc, snap)


func test_select_game_unknown_id_keeps_current():
    var snap := TestHelper.snapshot_game_context(_gc)
    _gc.select_game("ts")
    var before: GameDefinition = _gc.current
    var roster_before: int = _ef._entity_cache.size()
    _gc.select_game("nope")
    TestHelper.assert_true(_gc.current == before, "unknown id refused, current kept")
    TestHelper.assert_eq(_ef._entity_cache.size(), roster_before, "roster untouched")
    TestHelper.restore_game_context(_gc, snap)


func test_select_game_empty_unloads_all_content():
    var snap := TestHelper.snapshot_game_context(_gc)
    _gc.select_game("")
    TestHelper.assert_true(_gc.current == null, "no active game after unload")
    TestHelper.assert_true(_ef._entity_cache.is_empty(), "entity cache cleared")
    TestHelper.assert_true(_ef._global_rules == null, "factory rules cleared")
    TestHelper.assert_true(_tc._theaters.is_empty(), "theater registry cleared")
    TestHelper.assert_true(_am._audio_cache.is_empty(), "audio cache cleared")
    TestHelper.assert_true(GlobalRules.get_current() == null, "get_current null after unload")
    TestHelper.restore_game_context(_gc, snap)


# --- rules validation at select ---------------------------------------------


func test_broken_rules_refuse_selection():
    var snap := TestHelper.snapshot_game_context(_gc)
    var emitted := _track_emissions()
    var def := _make_def("broken", [FIXTURES + "/game_a/"])
    def.rules = GlobalRules.new()
    var loc := Locomotor.new()
    loc.id = "walk"
    loc.terrain_speeds = {"missing_land": 1.0}
    def.rules.locomotors = {"walk": loc}
    _gc._defs["broken"] = def
    _gc.select_game("broken")
    TestHelper.assert_true(_gc.current != def, "selection refused")
    TestHelper.assert_true(not _ef.get_entity_data("A_UNIT"), "refused game registered nothing")
    TestHelper.assert_eq(emitted.size(), 0, "no game_changed on refused selection")
    TestHelper.restore_game_context(_gc, snap)


# --- rules access contract ---------------------------------------------------


func test_get_current_reflects_active_game():
    var snap := TestHelper.snapshot_game_context(_gc)
    _gc.select_game("ts")
    TestHelper.assert_true(_gc.rules != null, "active game exposes rules")
    TestHelper.assert_true(
        GlobalRules.get_current() == _gc.rules, "get_current routes to active game rules"
    )
    TestHelper.assert_true(
        GlobalRules.get_current() == _ef._global_rules, "factory holds the same instance"
    )
    TestHelper.restore_game_context(_gc, snap)


func test_set_global_rules_monkeypatch_still_works():
    var snap := TestHelper.snapshot_game_context(_gc)
    _gc.select_game("ts")
    var original: GlobalRules = _ef._global_rules
    var custom := GlobalRules.new()
    _ef.set_global_rules(custom)
    TestHelper.assert_true(
        GlobalRules.get_current() == custom, "monkeypatch visible through get_current"
    )
    _ef.set_global_rules(original)
    TestHelper.assert_true(GlobalRules.get_current() == original, "restore returns the game rules")
    TestHelper.restore_game_context(_gc, snap)


# --- persistence -------------------------------------------------------------


func test_save_game_choice_preserves_other_sections():
    var snap := TestHelper.snapshot_game_context(_gc)
    var path := "user://test_gamectx_settings.cfg"
    var saved_path: String = _gc._config_path
    _gc._config_path = path
    var seed_cfg := ConfigFile.new()
    seed_cfg.set_value("camera", "edge_scroll_enabled", false)
    seed_cfg.set_value("keybinds:ts", "camera_up", "Q")
    seed_cfg.save(path)
    _gc.save_game_choice("ra2")
    var cfg := ConfigFile.new()
    TestHelper.assert_eq(cfg.load(path), OK, "settings file loadable after save")
    if cfg.load(path) == OK:
        TestHelper.assert_eq(cfg.get_value("game", "id", ""), "ra2", "game id persisted")
        TestHelper.assert_eq(
            cfg.get_value("camera", "edge_scroll_enabled", true),
            false,
            "shared camera section preserved"
        )
        TestHelper.assert_eq(
            cfg.get_value("keybinds:ts", "camera_up", ""), "Q", "keybind section preserved"
        )
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    _gc._config_path = saved_path
    TestHelper.restore_game_context(_gc, snap)


# --- reset-cycle completeness (repeated selects must not leak state) ---------


func test_repeated_select_cycles_leave_no_stale_state():
    var snap := TestHelper.snapshot_game_context(_gc)
    _gc.select_game("ts")
    var roster: int = _ef._entity_cache.size()
    var audio: int = _am._audio_cache.size()
    var theaters: int = _tc._theaters.size()
    TestHelper.assert_true(roster > 0, "ts roster non-empty before cycle")
    TestHelper.assert_true(audio > 0, "ts audio non-empty before cycle")
    TestHelper.assert_true(theaters > 0, "ts theaters non-empty before cycle")

    var def := _make_def("cycle_fake", [FIXTURES + "/game_a/"])
    _gc._defs["cycle_fake"] = def
    _gc.select_game("cycle_fake")
    TestHelper.assert_true(_ef.get_entity_data("A_UNIT") != null, "fake roster active")
    TestHelper.assert_eq(_ef._entity_cache.size(), 1, "previous roster fully cleared")
    TestHelper.assert_eq(_am._audio_cache.size(), 0, "audio cache cleared on switch")
    TestHelper.assert_eq(_tc._theaters.size(), 0, "theater registry cleared on switch")

    _gc.select_game("ts")
    TestHelper.assert_eq(_ef._entity_cache.size(), roster, "roster restored exactly")
    TestHelper.assert_eq(_am._audio_cache.size(), audio, "audio restored exactly")
    TestHelper.assert_eq(_tc._theaters.size(), theaters, "theaters restored exactly")
    TestHelper.restore_game_context(_gc, snap)


# --- per-game boot smoke -----------------------------------------------------


func test_every_discovered_game_boots():
    var snap := TestHelper.snapshot_game_context(_gc)
    var games: Array = _gc.list_games()
    TestHelper.assert_true(games.size() >= 1, "at least one game discovered")
    for def: GameDefinition in games:
        _gc.select_game(def.id)
        TestHelper.assert_true(_gc.current == def, "smoke: %s selected" % def.id)
        TestHelper.assert_true(_ef._entity_cache.size() > 0, "smoke: %s roster non-empty" % def.id)
        TestHelper.assert_true(
            _tc._theaters.size() > 0, "smoke: %s theater registry non-empty" % def.id
        )
        TestHelper.assert_eq(
            def.rules.validate_locomotor_keys().size(), 0, "smoke: %s locomotors valid" % def.id
        )
        TestHelper.assert_eq(
            def.rules.validate_warhead_armor_keys().size(),
            0,
            "smoke: %s warhead/armor valid" % def.id
        )
        _gc.select_game("ts")
    TestHelper.restore_game_context(_gc, snap)
