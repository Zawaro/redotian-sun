extends Node

# FactionCatalog unit tests — fixture roster loading, ordering, playable
# filtering, last-wins layering, missing-dir survival, and game-switch reset.
# GameContext is snapshotted and restored around every mutating test.

const FACTION_FIXTURE: String = "res://test/fixtures/factions/"
const FACTION_OVERRIDE: String = "res://test/fixtures/factions_override/"
const FACTION_TIE: String = "res://test/fixtures/factions_tie/"
const MISSING_FIXTURE: String = "res://test/fixtures/does_not_exist/"

var _gc: Node = null
var _fc: Node = null


func _ready() -> void:
    if has_node("/root/GameContext"):
        _gc = get_node("/root/GameContext")
    if has_node("/root/FactionCatalog"):
        _fc = get_node("/root/FactionCatalog")


func _ids(factions: Array) -> Array[String]:
    var out: Array[String] = []
    for faction in factions:
        out.append((faction as Faction).id)
    return out


func test_registers_fixture_roster():
    if _fc == null:
        TestHelper.fail("FactionCatalog not injected")
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _fc.reset_content()
    _fc.register_data_set(FACTION_FIXTURE)
    TestHelper.assert_true(_fc.get_faction("Alpha") != null, "fixture faction loads")
    TestHelper.assert_eq(_ids(_fc.get_ordered()), ["Beta", "Alpha", "Gamma"], "roster ordered")
    TestHelper.assert_eq(_ids(_fc.get_playable()), ["Beta", "Alpha"], "passive faction excluded")
    TestHelper.restore_game_context(_gc, snap)


func test_order_tie_breaks_by_id():
    if _fc == null:
        TestHelper.fail("FactionCatalog not injected")
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _fc.reset_content()
    _fc.register_data_set(FACTION_TIE)
    TestHelper.assert_eq(
        _ids(_fc.get_ordered()), ["Alpha", "Zulu"], "equal order ties break by ascending id"
    )
    TestHelper.restore_game_context(_gc, snap)


func test_later_root_overrides_id():
    if _fc == null:
        TestHelper.fail("FactionCatalog not injected")
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _fc.reset_content()
    _fc.register_data_set(FACTION_FIXTURE)
    _fc.register_data_set(FACTION_OVERRIDE)
    var gamma: Faction = _fc.get_faction("Gamma")
    TestHelper.assert_true(gamma != null, "overridden id still resolves")
    if gamma:
        TestHelper.assert_eq(gamma.display_name, "Gamma Guild Override", "later root wins the id")
    TestHelper.restore_game_context(_gc, snap)


func test_register_is_idempotent_per_path():
    if _fc == null:
        TestHelper.fail("FactionCatalog not injected")
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _fc.reset_content()
    _fc.register_data_set(FACTION_FIXTURE)
    var size: int = _fc._data_sets.size()
    _fc.register_data_set(FACTION_FIXTURE)
    TestHelper.assert_eq(_fc._data_sets.size(), size, "same path not registered twice")
    TestHelper.restore_game_context(_gc, snap)


func test_missing_directory_warns_without_crash():
    if _fc == null:
        TestHelper.fail("FactionCatalog not injected")
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _fc.reset_content()
    _fc.register_data_set(MISSING_FIXTURE)
    TestHelper.assert_true(
        _fc._data_sets.has(MISSING_FIXTURE), "missing dir still registers, no crash"
    )
    TestHelper.assert_eq(_fc.get_ordered().size(), 0, "no factions from a missing dir")
    TestHelper.restore_game_context(_gc, snap)


func test_game_switch_reloads_factions():
    if _fc == null:
        TestHelper.fail("FactionCatalog not injected")
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _fc.reset_content()
    _fc.register_data_set(FACTION_FIXTURE)
    TestHelper.assert_true(_fc.get_faction("Alpha") != null, "fixture loaded before switch")
    _gc.select_game("ts")
    TestHelper.assert_true(_fc.get_faction("Alpha") == null, "old game's factions dropped")
    TestHelper.assert_true(_fc.get_faction("GDI") != null, "new game's factions loaded")
    TestHelper.restore_game_context(_gc, snap)


func test_unload_empties_registry():
    if _fc == null:
        TestHelper.fail("FactionCatalog not injected")
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _gc.select_game("")
    TestHelper.assert_eq(_fc.get_ordered().size(), 0, "unload clears the registry")
    TestHelper.assert_eq(Houses.ids().size(), 0, "unload clears the house roster")
    TestHelper.restore_game_context(_gc, snap)
