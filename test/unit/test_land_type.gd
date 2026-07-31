extends Node

# LandType and Locomotor resource defaults, behavior, and GlobalRules registry lookups

var _test_passed := 0
var _test_failed := 0


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
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_locomotor_defaults():
    var lm := Locomotor.new()
    TestHelper.assert_eq(lm.id, "", "Locomotor id defaults empty")
    TestHelper.assert_true(lm.terrain_speeds.is_empty(), "terrain_speeds defaults empty")
    TestHelper.assert_eq(lm.climb_tolerance, 1, "climb_tolerance defaults 1")
    TestHelper.assert_eq(lm.is_fly, false, "is_fly defaults false")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_locomotor_passability():
    var foot := Locomotor.new()
    foot.terrain_speeds = {"clear": 1.0, "rough": 0.89, "water": 0.0}
    TestHelper.assert_true(foot.is_passable("clear"), "positive speed passable")
    TestHelper.assert_true(foot.is_passable("rough"), "slow surface still passable")
    TestHelper.assert_eq(foot.is_passable("water"), false, "0.0 speed impassable")
    TestHelper.assert_eq(foot.is_passable("cliff"), false, "absent key impassable")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_hover_passes_everything():
    var hover := Locomotor.new()
    hover.is_hover = true
    TestHelper.assert_true(hover.is_passable("water"), "hover passes water")
    TestHelper.assert_true(hover.is_passable("cliff"), "hover passes cliff")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_fly_passes_everything():
    var fly := Locomotor.new()
    fly.is_fly = true
    TestHelper.assert_true(fly.is_passable("water"), "fly passes water")
    TestHelper.assert_true(fly.is_passable("anything"), "fly passes any land type")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_speed_multiplier():
    var wheel := Locomotor.new()
    wheel.terrain_speeds = {"clear": 1.0, "rough": 0.5, "road": 1.25}
    TestHelper.assert_eq(wheel.get_speed_multiplier("clear"), 1.0, "clear -> 1.0")
    TestHelper.assert_eq(wheel.get_speed_multiplier("rough"), 0.5, "rough -> 0.5")
    TestHelper.assert_eq(wheel.get_speed_multiplier("road"), 1.25, "road -> 1.25 bonus")
    TestHelper.assert_eq(wheel.get_speed_multiplier("water"), 1.0, "absent key -> full speed")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_get_land_type_known():
    var rules := _make_land_types()
    var lt := rules.get_land_type("water")
    TestHelper.assert_true(lt != null, "known land type found")
    TestHelper.assert_eq(lt.id, "water", "returns correct land type")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_get_land_type_unknown():
    var rules := _make_land_types()
    TestHelper.assert_eq(rules.get_land_type("lava"), null, "unknown land type -> null")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_get_locomotor_known():
    var rules := GlobalRules.new()
    var wheel := Locomotor.new()
    wheel.id = "Wheel"
    rules.locomotors["Wheel"] = wheel
    TestHelper.assert_eq(rules.get_locomotor("Wheel"), wheel, "known locomotor found")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_get_locomotor_unknown():
    var rules := GlobalRules.new()
    TestHelper.assert_eq(rules.get_locomotor("Jetpack"), null, "unknown locomotor -> null")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_registered_tres_load():
    var rules := load("res://resources/global_rules.tres") as GlobalRules
    TestHelper.assert_true(rules != null, "global_rules.tres loads")
    if rules == null:
        _test_passed += TestHelper._passed
        _test_failed += TestHelper._failed
        TestHelper.reset()
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
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
