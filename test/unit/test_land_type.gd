extends Node

# LandType and Locomotor resource defaults, behavior, and GlobalRules registry lookups

const _NEW_LAT_IDS: Array[String] = ["sand", "pavement", "green", "crystal", "mold"]
const _GROUND_LOCOMOTORS: Array[String] = [
    "Foot", "Track", "Wheel", "Hover", "Amphibious", "Jumpjet", "Subterranean"
]
const _RULES_PATH := "res://games/ts/global_rules.tres"

var _ts: Node = null


## Restore the shared TerrainSystem grid after this suite so later suites that
## rely on the 50x50 default are not poisoned by the persistence fixtures.
func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE and is_instance_valid(_ts):
        _ts.init_grid(50, 50)


func _make_land_types() -> GlobalRules:
    var rules := GlobalRules.new()
    for lt_id in ["clear", "rough", "road", "water", "cliff"]:
        var lt := LandType.new()
        lt.id = lt_id
        rules.land_types[lt_id] = lt
    return rules


func test_land_type_defaults():
    var lt := LandType.new()
    TestHelper.assert_eq(lt.id, "", "LandType id defaults empty")
    TestHelper.assert_eq(lt.display_name, "", "LandType display_name defaults empty")
    TestHelper.assert_eq(lt.color, Color.WHITE, "LandType color defaults white")
    TestHelper.assert_eq(lt.group, "", "LandType group defaults empty")


func test_locomotor_defaults():
    var lm := Locomotor.new()
    TestHelper.assert_eq(lm.id, "", "Locomotor id defaults empty")
    TestHelper.assert_true(lm.terrain_speeds.is_empty(), "terrain_speeds defaults empty")
    TestHelper.assert_eq(lm.climb_tolerance, 1, "climb_tolerance defaults 1")
    TestHelper.assert_eq(lm.is_fly, false, "is_fly defaults false")


func test_locomotor_passability():
    var foot := Locomotor.new()
    foot.terrain_speeds = {"clear": 1.0, "rough": 0.89, "water": 0.0}
    TestHelper.assert_true(foot.is_passable("clear"), "positive speed passable")
    TestHelper.assert_true(foot.is_passable("rough"), "slow surface still passable")
    TestHelper.assert_eq(foot.is_passable("water"), false, "0.0 speed impassable")
    TestHelper.assert_eq(foot.is_passable("cliff"), false, "absent key impassable")


func test_hover_passes_everything():
    var hover := Locomotor.new()
    hover.is_hover = true
    TestHelper.assert_true(hover.is_passable("water"), "hover passes water")
    TestHelper.assert_true(hover.is_passable("cliff"), "hover passes cliff")


func test_fly_passes_everything():
    var fly := Locomotor.new()
    fly.is_fly = true
    TestHelper.assert_true(fly.is_passable("water"), "fly passes water")
    TestHelper.assert_true(fly.is_passable("anything"), "fly passes any land type")


func test_speed_multiplier():
    var wheel := Locomotor.new()
    wheel.terrain_speeds = {"clear": 1.0, "rough": 0.5, "road": 1.25}
    TestHelper.assert_eq(wheel.get_speed_multiplier("clear"), 1.0, "clear -> 1.0")
    TestHelper.assert_eq(wheel.get_speed_multiplier("rough"), 0.5, "rough -> 0.5")
    TestHelper.assert_eq(wheel.get_speed_multiplier("road"), 1.25, "road -> 1.25 bonus")
    TestHelper.assert_eq(wheel.get_speed_multiplier("water"), 1.0, "absent key -> full speed")


func test_get_land_type_known():
    var rules := _make_land_types()
    var lt := rules.get_land_type("water")
    TestHelper.assert_true(lt != null, "known land type found")
    TestHelper.assert_eq(lt.id, "water", "returns correct land type")


func test_get_land_type_unknown():
    var rules := _make_land_types()
    TestHelper.assert_eq(rules.get_land_type("lava"), null, "unknown land type -> null")


func test_get_locomotor_known():
    var rules := GlobalRules.new()
    var wheel := Locomotor.new()
    wheel.id = "Wheel"
    rules.locomotors["Wheel"] = wheel
    TestHelper.assert_eq(rules.get_locomotor("Wheel"), wheel, "known locomotor found")


func test_get_locomotor_unknown():
    var rules := GlobalRules.new()
    TestHelper.assert_eq(rules.get_locomotor("Jetpack"), null, "unknown locomotor -> null")


func test_registered_tres_load():
    var rules := load("res://games/ts/global_rules.tres") as GlobalRules
    TestHelper.assert_true(rules != null, "global_rules.tres loads")
    if rules == null:
        return
    var lm_ids: Array = [
        "Foot", "Track", "Wheel", "Hover", "Amphibious", "Fly", "Jumpjet", "Subterranean", "Ship"
    ]
    for lm_id in lm_ids:
        TestHelper.assert_true(rules.get_locomotor(lm_id) != null, "locomotor registered: " + lm_id)
    for lt_id in ["clear", "rough", "road", "water", "cliff"]:
        TestHelper.assert_true(rules.get_land_type(lt_id) != null, "land type registered: " + lt_id)
    TestHelper.assert_true(
        rules.validate_locomotor_keys().is_empty(), "registered locomotors validate clean"
    )


func test_new_lat_types_registered_and_grouped():
    var rules := load(_RULES_PATH) as GlobalRules
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


func test_shipped_land_types_carry_group():
    var rules := load(_RULES_PATH) as GlobalRules
    TestHelper.assert_true(rules != null, "global_rules.tres loads")
    if rules == null:
        return
    for lt_id in ["clear", "rough", "road", "water", "cliff", "resource"]:
        var lt := rules.get_land_type(lt_id)
        TestHelper.assert_true(lt != null, "land type registered: " + lt_id)
        if lt != null:
            TestHelper.assert_true(lt.group != "", "shipped land type has a group: " + lt_id)


func test_locomotors_pass_new_lats_at_clear_speed():
    for lm_id in _GROUND_LOCOMOTORS:
        var lm := load("res://games/ts/locomotors/%s.tres" % lm_id) as Locomotor
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


func test_land_type_override_round_trip():
    _ts.init_grid(6, 6)
    var cell := Vector2i(3, 3)
    _ts.set_land_type(cell, "rough")
    var path := "user://test_land_types_roundtrip.json"
    _ts.export_to_json(path)
    _ts.clear()
    _ts.import_from_json(path)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    TestHelper.assert_eq(
        _ts.get_painted_land_type(cell), "rough", "painted override survives round-trip"
    )


func test_default_land_type_not_persisted():
    _ts.init_grid(6, 6)
    var cell := Vector2i(3, 3)
    _ts.set_land_type(cell, "clear")
    TestHelper.assert_eq(_ts.get_painted_land_type(cell), "", "clear is stored as no override")
    var path := "user://test_land_types_default.json"
    _ts.export_to_json(path)
    var file := FileAccess.open(path, FileAccess.READ)
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    TestHelper.assert_true(parsed is Dictionary, "export parses")
    if parsed is Dictionary:
        var land: Dictionary = parsed.get("land_types", {})
        TestHelper.assert_true(land.is_empty(), "clear override not persisted")


func test_land_types_absent_key_loads_clean():
    _ts.init_grid(6, 6)
    var path := "user://test_land_types_absent.json"
    _ts.export_to_json(path)
    _ts.set_land_type(Vector2i(3, 3), "rough")
    _ts.import_from_json(path)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    TestHelper.assert_eq(
        _ts.get_painted_land_type(Vector2i(3, 3)), "", "no land_types key -> no override"
    )
