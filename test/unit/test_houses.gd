extends Node

# House id vocabulary helpers and the EntityData.owner string contract


func test_house_id_index_round_trip():
    TestHelper.assert_eq(Houses.id_for(0), "GDI", "house 0 is GDI")
    TestHelper.assert_eq(Houses.id_for(1), "Nod", "house 1 is Nod")
    TestHelper.assert_eq(Houses.id_for(2), "Neutral", "house 2 is Neutral")
    TestHelper.assert_eq(Houses.id_for(3), "Special", "house 3 is Special")
    TestHelper.assert_eq(Houses.id_for(-1), "", "out-of-range index -> empty id")
    TestHelper.assert_eq(Houses.id_for(4), "", "index past list -> empty id")
    TestHelper.assert_eq(Houses.index_for("Nod"), 1, "Nod -> index 1")
    TestHelper.assert_eq(Houses.index_for("not_a_house"), -1, "unknown id -> -1")


func test_display_name_for():
    TestHelper.assert_eq(Houses.display_name_for("Nod"), "Nod", "display name for Nod")
    TestHelper.assert_eq(
        Houses.display_name_for("bogus"), "bogus", "unknown id passes through display"
    )


func test_ids_match_owner_vocabulary():
    TestHelper.assert_eq(Houses.IDS.size(), 4, "house list has four entries")
    for owner in ["GDI", "Nod", "Neutral"]:
        TestHelper.assert_true(
            Houses.index_for(owner) >= 0, "EntityData.owner value is a house id: " + owner
        )
    TestHelper.assert_true(Houses.index_for("Special") >= 0, "Special is a house id")
