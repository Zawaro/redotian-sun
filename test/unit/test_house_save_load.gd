extends Node

# House persistence: entity-entry serialization (house_id + legacy player_id
# alias) and MapLoader house resolution.

const _SAVE_LOAD := preload("res://scripts/editor/EditorSaveLoad.gd")


func test_save_entry_writes_house_and_syncs_player_alias():
    var entry := _SAVE_LOAD.build_entity_entry({"id": "nod_buggy", "house_id": "Nod"})
    TestHelper.assert_eq(entry.get("house_id", ""), "Nod", "house_id written")
    TestHelper.assert_eq(int(entry.get("player_id", -1)), 1, "player_id alias synced from house")
    TestHelper.assert_true(not entry.has("cell"), "cell is attached by the caller, not here")


func test_save_entry_keeps_explicit_player_id():
    var entry := _SAVE_LOAD.build_entity_entry({"id": "gdi_buggy", "player_id": 5})
    TestHelper.assert_eq(int(entry.get("player_id", -1)), 5, "explicit player_id preserved")
    TestHelper.assert_true(not entry.has("house_id"), "no house_id invented")


func test_save_entry_house_with_explicit_player_wins():
    var entry := _SAVE_LOAD.build_entity_entry(
        {"id": "unit", "house_id": "Neutral", "player_id": 7}
    )
    TestHelper.assert_eq(entry.get("house_id", ""), "Neutral", "house_id kept")
    TestHelper.assert_eq(int(entry.get("player_id", -1)), 7, "explicit player_id untouched")


func test_save_entry_legacy_fields_survive():
    var entry := (
        _SAVE_LOAD
        . build_entity_entry(
            {
                "id": "tib_tree",
                "rotation_y": 90.0,
                "current_health": 40,
                "resource_type_id": "tiberium_green",
            }
        )
    )
    TestHelper.assert_eq(float(entry.get("rotation_y", 0.0)), 90.0, "rotation_y preserved")
    TestHelper.assert_eq(int(entry.get("current_health", 0)), 40, "current_health preserved")
    TestHelper.assert_eq(
        entry.get("resource_type_id", ""), "tiberium_green", "override key preserved"
    )


func test_resolve_house_id_prefers_explicit():
    TestHelper.assert_eq(
        MapLoader.resolve_house_id({"house_id": "Nod", "player_id": 0}),
        "Nod",
        "explicit house_id wins over player_id"
    )


func test_resolve_house_id_legacy_player_alias():
    TestHelper.assert_eq(
        MapLoader.resolve_house_id({"player_id": 1}), "Nod", "legacy player_id 1 -> Nod"
    )
    TestHelper.assert_eq(
        MapLoader.resolve_house_id({"player_id": 0}), "GDI", "legacy player_id 0 -> GDI"
    )


func test_resolve_house_id_no_house_information():
    TestHelper.assert_eq(
        MapLoader.resolve_house_id({"player_id": 6}), "", "player slot past house list -> empty"
    )
    TestHelper.assert_eq(MapLoader.resolve_house_id({}), "", "empty entry -> empty house")
