extends Node

# Game content tests — consumer subdir conventions per layer root, last-wins
# layering, borrowing, the cross-game id-collision validator, and boot
# isolation (only the active game's content is loaded). Global state is
# snapshotted and restored around every mutating test.

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


func _make_def(id: String, roots: Array) -> GameDefinition:
    var def := GameDefinition.new()
    def.id = id
    def.rules = load(FIXTURES + "/rules.tres") as GlobalRules
    for root: String in roots:
        def.data_sets.append(root)
    return def


# --- consumer subdir conventions ---------------------------------------------


func test_consumers_register_their_subdirs_per_root():
    var snap := TestHelper.snapshot_game_context(_gc)
    var def := _make_def("conv", [FIXTURES + "/game_a/", FIXTURES + "/game_b/"])
    _gc._defs["conv"] = def
    _gc.select_game("conv")
    for game_dir in ["game_a", "game_b"]:
        TestHelper.assert_true(
            _ef._data_sets.has("%s/%s/entities/" % [FIXTURES, game_dir]),
            "EntityFactory scans entities/ of " + game_dir
        )
        TestHelper.assert_true(
            _tc._data_sets.has("%s/%s/terrain_objects/" % [FIXTURES, game_dir]),
            "TerrainCatalog scans terrain_objects/ of " + game_dir
        )
        TestHelper.assert_true(
            _tc._data_sets.has("%s/%s/art/terrain/" % [FIXTURES, game_dir]),
            "TerrainCatalog scans art/terrain/ of " + game_dir
        )
        TestHelper.assert_true(
            _tc._data_sets.has("%s/%s/theaters/" % [FIXTURES, game_dir]),
            "TerrainCatalog scans theaters/ of " + game_dir
        )
        TestHelper.assert_true(
            _am._data_sets.has("%s/%s/audio/" % [FIXTURES, game_dir]),
            "AudioManager scans audio/ of " + game_dir
        )
    TestHelper.restore_game_context(_gc, snap)


func test_missing_subdirs_warn_and_continue():
    var snap := TestHelper.snapshot_game_context(_gc)
    var def := _make_def("sparse", [FIXTURES + "/game_a/"])
    _gc._defs["sparse"] = def
    _gc.select_game("sparse")
    # game_a ships only entities/ — the other consumers warn but survive and
    # register nothing.
    TestHelper.assert_true(_ef.get_entity_data("A_UNIT") != null, "entities still registered")
    TestHelper.assert_eq(_am._audio_cache.size(), 0, "no audio registered, no crash")
    TestHelper.assert_eq(_tc._theaters.size(), 0, "no theaters registered, no crash")
    TestHelper.restore_game_context(_gc, snap)


# --- last-wins layering ------------------------------------------------------


func test_later_root_overrides_same_id():
    var snap := TestHelper.snapshot_game_context(_gc)
    var def := _make_def("layered", [FIXTURES + "/layer_shared/", FIXTURES + "/layer_own/"])
    _gc._defs["layered"] = def
    _gc.select_game("layered")
    var unit: EntityData = _ef.get_entity_data("L_UNIT")
    TestHelper.assert_true(unit != null, "L_UNIT resolves")
    if unit:
        TestHelper.assert_eq(unit.strength, 200, "game-own layer wins over shared layer")
    TestHelper.restore_game_context(_gc, snap)


func test_layer_order_reversal_flips_winner():
    var snap := TestHelper.snapshot_game_context(_gc)
    var def := _make_def("layered_rev", [FIXTURES + "/layer_own/", FIXTURES + "/layer_shared/"])
    _gc._defs["layered_rev"] = def
    _gc.select_game("layered_rev")
    var unit: EntityData = _ef.get_entity_data("L_UNIT")
    TestHelper.assert_true(unit != null, "L_UNIT resolves")
    if unit:
        TestHelper.assert_eq(unit.strength, 100, "reversed order flips the winner")
    TestHelper.restore_game_context(_gc, snap)


func test_disjoint_ids_merge_across_roots():
    var snap := TestHelper.snapshot_game_context(_gc)
    var def := _make_def("merge", [FIXTURES + "/game_a/", FIXTURES + "/game_b/"])
    _gc._defs["merge"] = def
    _gc.select_game("merge")
    TestHelper.assert_true(_ef.get_entity_data("A_UNIT") != null, "A_UNIT merged")
    TestHelper.assert_true(_ef.get_entity_data("B_UNIT") != null, "B_UNIT merged")
    TestHelper.restore_game_context(_gc, snap)


# --- borrowing ---------------------------------------------------------------


func test_borrowed_root_resolves_foreign_ids():
    var snap := TestHelper.snapshot_game_context(_gc)
    var def := _make_def("borrower", [FIXTURES + "/game_a/", FIXTURES + "/game_b/"])
    _gc._defs["borrower"] = def
    _gc.select_game("borrower")
    TestHelper.assert_true(
        _ef.get_entity_data("A_UNIT") != null, "borrowed game_a content registers"
    )
    TestHelper.restore_game_context(_gc, snap)


# --- cross-game id collision validator ---------------------------------------


func test_sibling_games_claiming_same_id_collide():
    var a := _make_def("col_game1", [FIXTURES + "/col1/"])
    var b := _make_def("col_game2", [FIXTURES + "/col2/"])
    var errors := GameContext.validate_id_collisions([a, b])
    TestHelper.assert_eq(errors.size(), 1, "exactly one collision reported")
    if errors.size() == 1:
        TestHelper.assert_true("X_UNIT" in errors[0], "error names the colliding id")
        TestHelper.assert_true("col_game1" in errors[0], "error names the first game")
        TestHelper.assert_true("col_game2" in errors[0], "error names the second game")


func test_shared_dir_listed_by_both_is_not_a_collision():
    var a := _make_def("sharer_a", [FIXTURES + "/layer_shared/"])
    var b := _make_def("sharer_b", [FIXTURES + "/layer_shared/"])
    TestHelper.assert_eq(
        GameContext.validate_id_collisions([a, b]).size(), 0, "same dir is layering, not collision"
    )


func test_override_of_borrowed_root_is_not_a_collision():
    var a := _make_def("owner_a", [FIXTURES + "/layer_shared/"])
    var b := _make_def("overrider_b", [FIXTURES + "/layer_shared/", FIXTURES + "/layer_own/"])
    TestHelper.assert_eq(
        GameContext.validate_id_collisions([a, b]).size(),
        0,
        "b overriding borrowed content is layering"
    )


func test_validator_runs_on_demand_not_at_boot():
    # Booting the real game must not scan other games' content: the factory's
    # registered data sets are exactly the active game's roots.
    var snap := TestHelper.snapshot_game_context(_gc)
    _gc.select_game("ts")
    TestHelper.assert_eq(_ef._data_sets.size(), 1, "only the active game's entity roots registered")
    TestHelper.assert_true(_ef._data_sets[0] == "res://games/ts/entities/", "and it is the ts root")
    TestHelper.restore_game_context(_gc, snap)
