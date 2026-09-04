extends Node

# Houses helpers, LAT group data, and house_id save/load round-trip behavior

const _SAVE_LOAD_SCRIPT := preload("res://scripts/editor/EditorSaveLoad.gd")
const _NEW_LAT_IDS: Array[String] = ["sand", "pavement", "green", "crystal", "mold"]
const _GROUND_LOCOMOTORS: Array[String] = [
    "Foot", "Track", "Wheel", "Hover", "Amphibious", "Jumpjet", "Subterranean"
]


func test_house_id_and_index_round_trip():
    TestHelper.assert_eq(Houses.id_for(0), "gdi", "house 0 is gdi")
    TestHelper.assert_eq(Houses.id_for(1), "nod", "house 1 is nod")
    TestHelper.assert_eq(Houses.id_for(2), "neutral", "house 2 is neutral")
    TestHelper.assert_eq(Houses.id_for(3), "special", "house 3 is special")
    TestHelper.assert_eq(Houses.id_for(-1), "", "out-of-range index -> empty id")
    TestHelper.assert_eq(Houses.id_for(4), "", "index past list -> empty id")
    TestHelper.assert_eq(Houses.index_for("nod"), 1, "nod -> index 1")
    TestHelper.assert_eq(Houses.index_for("not_a_house"), -1, "unknown id -> -1")
    TestHelper.assert_eq(Houses.display_name_for("nod"), "Nod", "display name for nod")
    TestHelper.assert_eq(
        Houses.display_name_for("bogus"), "bogus", "unknown id passes through display"
    )


func test_land_type_group_defaults_empty():
    var lt := LandType.new()
    TestHelper.assert_eq(lt.group, "", "LandType group defaults empty")


func test_shipped_lat_resources_registered_and_grouped():
    var rules := load("res://resources/global_rules.tres") as GlobalRules
    TestHelper.assert_true(rules != null, "global_rules.tres loads")
    if rules == null:
        return
    for lat_id in _NEW_LAT_IDS:
        var lt := rules.get_land_type(lat_id)
        TestHelper.assert_true(lt != null, "new LAT registered: " + lat_id)
        if lt == null:
            continue
        TestHelper.assert_eq(lt.id, lat_id, "LAT id matches file: " + lat_id)
        TestHelper.assert_true(lt.display_name != "", "LAT has display name: " + lat_id)
        TestHelper.assert_true(lt.group != "", "LAT has a group: " + lat_id)
    var clear_lt := rules.get_land_type("clear")
    TestHelper.assert_true(clear_lt != null and clear_lt.group != "", "clear keeps its group")


func test_fixture_land_types_share_group():
    var a := LandType.new()
    a.id = "sand_dune"
    a.group = "Sand"
    var b := LandType.new()
    b.id = "sand_rough"
    b.group = "Sand"
    TestHelper.assert_eq(a.group, b.group, "fixture LATs group together under Sand")


func test_locomotors_pass_new_lats_at_clear_speed():
    for lm_id in _GROUND_LOCOMOTORS:
        var lm := load("res://resources/locomotors/%s.tres" % lm_id) as Locomotor
        TestHelper.assert_true(lm != null, "locomotor loads: " + lm_id)
        if lm == null:
            continue
        var clear_speed: float = lm.get_speed_multiplier("clear")
        for lat_id in _NEW_LAT_IDS:
            TestHelper.assert_true(lm.is_passable(lat_id), "%s passes %s" % [lm_id, lat_id])
            TestHelper.assert_eq(
                lm.get_speed_multiplier(lat_id),
                clear_speed,
                "%s speed on %s equals clear" % [lm_id, lat_id]
            )


func test_save_entry_writes_house_and_syncs_player_alias():
    var entry := _SAVE_LOAD_SCRIPT.build_entity_entry({"id": "nod_buggy", "house_id": "nod"})
    TestHelper.assert_eq(entry.get("house_id", ""), "nod", "house_id written")
    TestHelper.assert_eq(int(entry.get("player_id", -1)), 1, "player_id alias synced from house")


func test_save_entry_keeps_explicit_player_id():
    var entry := _SAVE_LOAD_SCRIPT.build_entity_entry({"id": "gdi_buggy", "player_id": 5})
    TestHelper.assert_eq(int(entry.get("player_id", -1)), 5, "explicit player_id preserved")
    TestHelper.assert_true(not entry.has("house_id"), "no house_id invented")


func test_save_entry_house_with_explicit_player_wins():
    var entry := _SAVE_LOAD_SCRIPT.build_entity_entry(
        {"id": "unit", "house_id": "neutral", "player_id": 7}
    )
    TestHelper.assert_eq(entry.get("house_id", ""), "neutral", "house_id kept")
    TestHelper.assert_eq(int(entry.get("player_id", -1)), 7, "explicit player_id untouched")


func test_save_entry_legacy_fields_survive():
    var entry := (
        _SAVE_LOAD_SCRIPT
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
    TestHelper.assert_true(not entry.has("cell"), "cell is attached by the caller, not here")


func test_resolve_house_id_prefers_explicit():
    TestHelper.assert_eq(
        MapLoader.resolve_house_id({"house_id": "nod", "player_id": 0}),
        "nod",
        "explicit house_id wins over player_id"
    )


func test_resolve_house_id_legacy_player_alias():
    TestHelper.assert_eq(
        MapLoader.resolve_house_id({"player_id": 1}), "nod", "legacy player_id 1 -> nod"
    )
    TestHelper.assert_eq(
        MapLoader.resolve_house_id({"player_id": 0}), "gdi", "legacy player_id 0 -> gdi"
    )


func test_resolve_house_id_no_house_information():
    TestHelper.assert_eq(
        MapLoader.resolve_house_id({"player_id": 6}), "", "player slot past house list -> empty"
    )
    TestHelper.assert_eq(MapLoader.resolve_house_id({}), "", "empty entry -> empty house")
