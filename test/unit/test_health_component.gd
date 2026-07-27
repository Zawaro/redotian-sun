extends Node

# HealthComponent armor/veterancy integration — take_damage looks up the
# sibling StatsComponent armor + veteran level in GlobalRules.

var _test_passed := 0
var _test_failed := 0


func _sync() -> void:
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func _make_entity(armor: String, veteran: int) -> Node3D:
    var parent := Node3D.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.armor = armor
    stats.veteran_level = veteran
    parent.add_child(stats)
    var hc := HealthComponent.new()
    hc.name = "HealthComponent"
    hc.max_health = 100
    hc.current_health = 100
    parent.add_child(hc)
    return parent


func _rules_available() -> bool:
    return EntityFactory and EntityFactory.get_global_rules() != null


func test_heavy_armor_take_damage():
    if not _rules_available():
        _test_failed += 1
        print("    FAIL: GlobalRules not loaded")
        return
    var e := _make_entity("heavy", 0)
    var hc: HealthComponent = e.get_node("HealthComponent")
    hc.take_damage(100)
    TestHelper.assert_eq(hc.current_health, 60, "heavy armor: 100 - 40")
    _sync()
    e.free()


func test_veteran_plus_none_armor():
    if not _rules_available():
        _test_failed += 1
        print("    FAIL: GlobalRules not loaded")
        return
    var e := _make_entity("none", 1)
    var hc: HealthComponent = e.get_node("HealthComponent")
    hc.take_damage(100)
    TestHelper.assert_eq(hc.current_health, 25, "veteran 1 armor: 100 - 75")
    _sync()
    e.free()


func test_minimum_one_damage_gets_through():
    if not _rules_available():
        _test_failed += 1
        print("    FAIL: GlobalRules not loaded")
        return
    var e := _make_entity("concrete", 0)
    var hc: HealthComponent = e.get_node("HealthComponent")
    hc.take_damage(2)
    TestHelper.assert_eq(hc.current_health, 99, "concrete floors at 1 damage")
    _sync()
    e.free()
