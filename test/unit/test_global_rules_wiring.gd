extends Node

# GlobalRules wiring tests — veterancy (armor/combat/speed), slope, production, repair

var _test_passed := 0
var _test_failed := 0


func _make_rules() -> GlobalRules:
    var rules := GlobalRules.new()
    rules.veteran_combat = 0.25
    rules.veteran_speed = 0.30
    rules.veteran_armor = 0.25
    rules.veteran_cap = 2
    rules.tracked_uphill = 0.5
    rules.tracked_downhill = 1.1
    rules.wheeled_uphill = 0.5
    rules.wheeled_downhill = 1.2
    rules.multiple_factory = 0.5
    rules.build_speed = 0.8
    rules.repair_step = 8
    for aid in ["none", "wood", "light", "heavy", "concrete"]:
        var at := ArmorType.new()
        at.id = aid
        rules.armor_types[aid] = at
    var sa := WarheadData.new()
    sa.id = "SA"
    sa.armor_damage_multipliers = {
        "none": 1.0, "wood": 0.6, "light": 0.4, "heavy": 0.25, "concrete": 0.1
    }
    rules.warheads["SA"] = sa
    return rules


# --- Veterancy: combat multiplier ---


func test_veteran_combat_multiplier():
    var rules := _make_rules()
    TestHelper.assert_eq(rules.get_veteran_combat_multiplier(0), 1.0, "level 0 -> 1.0")
    TestHelper.assert_eq(rules.get_veteran_combat_multiplier(1), 1.25, "level 1 -> 1.25")
    TestHelper.assert_eq(rules.get_veteran_combat_multiplier(2), 1.5, "level 2 -> 1.5")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_veteran_combat_multiplier_capped():
    var rules := _make_rules()
    TestHelper.assert_eq(rules.get_veteran_combat_multiplier(9), 1.5, "level 9 clamped to cap 2")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_veteran_speed_multiplier():
    var rules := _make_rules()
    TestHelper.assert_eq(rules.get_veteran_speed_multiplier(1), 1.3, "level 1 -> 1.3")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_veteran_armor_multiplier():
    var rules := _make_rules()
    TestHelper.assert_eq(
        rules.get_veteran_armor_multiplier(1), 0.75, "level 1 -> 0.75 (25% reduction)"
    )
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_veteran_armor_reduces_damage():
    var entity := Node3D.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.veteran_level = 1
    entity.add_child(stats)
    var hc := HealthComponent.new()
    hc.name = "HealthComponent"
    hc.max_health = 200
    hc.current_health = 200
    entity.add_child(hc)
    hc.take_damage(100)
    TestHelper.assert_eq(hc.current_health, 125, "veteran armor reduces 100 -> 75 damage")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()


func test_rookie_takes_full_damage():
    var entity := Node3D.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.veteran_level = 0
    entity.add_child(stats)
    var hc := HealthComponent.new()
    hc.name = "HealthComponent"
    hc.max_health = 200
    hc.current_health = 200
    entity.add_child(hc)
    hc.take_damage(100)
    TestHelper.assert_eq(hc.current_health, 100, "rookie takes full 100 damage")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()


# --- Veterancy: combat damage via get_effective_damage ---


func test_get_effective_damage_veteran():
    var entity := Node3D.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.veteran_level = 1
    entity.add_child(stats)
    var combat := CombatComponent.new()
    combat.name = "CombatComponent"
    entity.add_child(combat)
    var weapon := WeaponData.new()
    weapon.damage = 20
    TestHelper.assert_eq(combat.get_effective_damage(weapon), 25, "veteran combat 20 -> 25")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()


func test_get_effective_damage_rookie():
    var entity := Node3D.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.veteran_level = 0
    entity.add_child(stats)
    var combat := CombatComponent.new()
    combat.name = "CombatComponent"
    entity.add_child(combat)
    var weapon := WeaponData.new()
    weapon.damage = 20
    TestHelper.assert_eq(combat.get_effective_damage(weapon), 20, "rookie combat unchanged")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()


# --- Slope coefficients ---


func test_slope_tracked_uphill():
    var rules := _make_rules()
    TestHelper.assert_eq(rules.tracked_uphill, 0.5, "tracked uphill coefficient read")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_slope_wheeled_downhill():
    var rules := _make_rules()
    TestHelper.assert_eq(rules.wheeled_downhill, 1.2, "wheeled downhill coefficient read")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


# --- Production constants ---


func test_build_time_uses_rules_speed():
    var data := EntityData.new()
    data.id = "TEST_BUILDING"
    data.cost = 1000
    data.build_time = 0.0
    var with_rules := data.get_build_time(0.8)
    var fallback := data.get_build_time()
    TestHelper.assert_eq(with_rules, fallback, "rules build_speed matches constant fallback at 0.8")
    TestHelper.assert_eq(with_rules, 48.0, "1000 cost at 0.8 build speed -> 48s")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_build_time_explicit_overrides():
    var data := EntityData.new()
    data.id = "TEST_BUILDING"
    data.cost = 1000
    data.build_time = 20.0
    TestHelper.assert_eq(data.get_build_time(0.8), 20.0, "explicit build_time wins")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_multiple_factory_bonus():
    var rules := _make_rules()
    TestHelper.assert_eq(rules.multiple_factory, 0.5, "multiple_factory read from rules")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


# --- Repair step ---


func test_repair_step_from_rules():
    var rules := _make_rules()
    TestHelper.assert_eq(rules.repair_step, 8, "repair_step read from rules")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
