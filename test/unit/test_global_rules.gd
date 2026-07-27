extends Node

# GlobalRules helper tests — armor/veteran damage, veteran multipliers,
# production multiplier, slope coefficient, build-time scaling.

var _test_passed := 0
var _test_failed := 0


func _sync() -> void:
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func _assert_approx(got: float, expected: float, msg: String) -> void:
    TestHelper.assert_true(
        is_equal_approx(got, expected), "%s — expected %s, got %s" % [msg, expected, got]
    )
    _sync()


# --- Armor damage ---


func test_heavy_armor_reduces_damage():
    var gr := GlobalRules.new()
    TestHelper.assert_eq(gr.compute_final_damage(100, "heavy", 0), 40, "heavy armor 0.4 modifier")
    _sync()


func test_no_armor_is_identity():
    var gr := GlobalRules.new()
    TestHelper.assert_eq(gr.compute_final_damage(25, "none", 0), 25, "none armor identity")
    _sync()


func test_minimum_one_damage():
    var gr := GlobalRules.new()
    TestHelper.assert_eq(gr.compute_final_damage(2, "concrete", 0), 1, "concrete floors at 1")
    _sync()


func test_zero_base_damage():
    var gr := GlobalRules.new()
    TestHelper.assert_eq(gr.compute_final_damage(0, "none", 0), 0, "zero stays zero")
    _sync()


# --- Veterancy ---


func test_veteran_combat_multiplier():
    var gr := GlobalRules.new()
    _assert_approx(gr.veteran_combat_multiplier(1), 1.25, "veteran_combat level 1")


func test_veteran_level_clamped_to_cap():
    var gr := GlobalRules.new()
    _assert_approx(gr.veteran_speed_multiplier(9), 1.60, "level clamped to cap 2")


func test_veteran_armor_reduces_incoming():
    var gr := GlobalRules.new()
    TestHelper.assert_eq(gr.compute_final_damage(100, "none", 1), 75, "veteran armor level 1")
    _sync()


func test_zero_level_is_neutral():
    var gr := GlobalRules.new()
    _assert_approx(gr.veteran_combat_multiplier(0), 1.0, "level 0 neutral")


# --- Production ---


func test_single_factory_no_bonus():
    var gr := GlobalRules.new()
    _assert_approx(gr.production_speed_multiplier(1), 1.0, "single factory")


func test_multiple_factories_bonus():
    var gr := GlobalRules.new()
    _assert_approx(gr.production_speed_multiplier(3), 2.0, "three factories, 0.5 each")


func test_build_time_scales_with_build_speed():
    var data := EntityData.new()
    data.cost = 1000
    data.build_time = 0.0
    _assert_approx(data.get_build_time(0.8), 48.0, "cost-derived build time")


# --- Movement slope ---


func test_tracked_uphill_slower():
    var gr := GlobalRules.new()
    var c := gr.movement_slope_coefficient("Track", 0.5)
    TestHelper.assert_true(c < 1.0 and c >= gr.tracked_uphill, "tracked uphill in range")
    _sync()


func test_wheeled_downhill_faster():
    var gr := GlobalRules.new()
    var c := gr.movement_slope_coefficient("Wheel", -0.5)
    TestHelper.assert_true(c > 1.0 and c <= gr.wheeled_downhill, "wheeled downhill in range")
    _sync()


func test_flat_terrain_neutral():
    var gr := GlobalRules.new()
    _assert_approx(gr.movement_slope_coefficient("Track", 0.0), 1.0, "flat is neutral")


func test_foot_locomotor_unaffected():
    var gr := GlobalRules.new()
    _assert_approx(gr.movement_slope_coefficient("Foot", 0.8), 1.0, "foot unaffected")
