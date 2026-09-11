extends Node

# House id vocabulary helpers — the roster is projected from FactionCatalog,
# and the EntityData.owner string contract.

const FACTION_FIXTURE: String = "res://test/fixtures/factions/"

var _fc: Node = null


func _ready() -> void:
    if has_node("/root/FactionCatalog"):
        _fc = get_node("/root/FactionCatalog")


func _apply_fixture_roster() -> void:
    var beta := load(FACTION_FIXTURE + "beta.tres") as Faction
    var alpha := load(FACTION_FIXTURE + "alpha.tres") as Faction
    var gamma := load(FACTION_FIXTURE + "gamma.tres") as Faction
    Houses.apply_roster([beta, alpha, gamma])


func _restore_roster() -> void:
    if _fc:
        Houses.apply_roster(_fc.get_ordered())
    else:
        Houses.clear_roster()


func test_house_id_index_round_trip():
    _apply_fixture_roster()
    TestHelper.assert_eq(Houses.id_for(0), "Beta", "house 0 is the first rostered faction")
    TestHelper.assert_eq(Houses.id_for(1), "Alpha", "house 1 is the second rostered faction")
    TestHelper.assert_eq(Houses.id_for(2), "Gamma", "house 2 is the third rostered faction")
    TestHelper.assert_eq(Houses.id_for(-1), "", "out-of-range index -> empty id")
    TestHelper.assert_eq(Houses.id_for(3), "", "index past list -> empty id")
    TestHelper.assert_eq(Houses.index_for("Alpha"), 1, "Alpha -> index 1")
    TestHelper.assert_eq(Houses.index_for("not_a_house"), -1, "unknown id -> -1")
    _restore_roster()


func test_display_name_for():
    _apply_fixture_roster()
    TestHelper.assert_eq(
        Houses.display_name_for("Alpha"), "Alpha Corp", "display name comes from the faction"
    )
    TestHelper.assert_eq(
        Houses.display_name_for("bogus"), "bogus", "unknown id passes through display"
    )
    _restore_roster()


func test_empty_roster_fallback():
    Houses.clear_roster()
    TestHelper.assert_eq(Houses.id_for(0), "", "no roster -> empty id")
    TestHelper.assert_eq(Houses.index_for("Beta"), -1, "no roster -> unknown id")
    TestHelper.assert_eq(
        Houses.display_name_for("Beta"), "Beta", "no roster -> display passes through"
    )
    _restore_roster()


func test_ids_match_owner_vocabulary():
    if _fc == null:
        TestHelper.fail("FactionCatalog not injected")
        return
    Houses.apply_roster(_fc.get_ordered())
    for owner in ["GDI", "Nod", "Neutral"]:
        TestHelper.assert_true(
            Houses.index_for(owner) >= 0, "EntityData.owner value is a house id: " + owner
        )
    TestHelper.assert_true(Houses.index_for("Special") >= 0, "Special is a house id")
