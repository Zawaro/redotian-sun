extends Node

# Locomotor/LandType registry validation and EntityData zone consistency checks

var _test_passed := 0
var _test_failed := 0

var _saved_rules: GlobalRules = null
var _entity_factory: Node = null


func _make_rules() -> GlobalRules:
    var rules := GlobalRules.new()
    for lt_id in ["clear", "water"]:
        var lt := LandType.new()
        lt.id = lt_id
        rules.land_types[lt_id] = lt
    return rules


func _inject_rules(rules: GlobalRules) -> void:
    var root: Node = Engine.get_main_loop().root
    _entity_factory = root.get_node_or_null("EntityFactory")
    if _entity_factory:
        _saved_rules = _entity_factory.get_global_rules()
        _entity_factory.set_global_rules(rules)


func _restore_rules() -> void:
    if _entity_factory and _entity_factory.has_method("set_global_rules"):
        _entity_factory.set_global_rules(_saved_rules)


func test_validate_clean_registry():
    var rules := _make_rules()
    var lm := Locomotor.new()
    lm.id = "Foot"
    lm.terrain_speeds = {"clear": 1.0, "water": 0.0}
    rules.locomotors["Foot"] = lm
    TestHelper.assert_true(rules.validate_locomotor_keys().is_empty(), "valid keys -> no errors")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_validate_dangling_terrain_key():
    var rules := _make_rules()
    var lm := Locomotor.new()
    lm.id = "Wheel"
    lm.terrain_speeds = {"clear": 1.0, "lava": 0.5}
    rules.locomotors["Wheel"] = lm
    var errors := rules.validate_locomotor_keys()
    TestHelper.assert_eq(errors.size(), 1, "one dangling key error")
    TestHelper.assert_true(errors[0].contains("lava"), "error names missing land type")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_movement_zone_compatible():
    TestHelper.assert_true(
        EntityData.is_movement_zone_compatible("Foot", "Infantry"), "Foot + Infantry ok"
    )
    (
        TestHelper
        . assert_true(
            EntityData.is_movement_zone_compatible("Subterranean", "Subterannean"),
            "Subterranean + Subterannean ok",
        )
    )
    (
        TestHelper
        . assert_eq(
            EntityData.is_movement_zone_compatible("Track", "Subterannean"),
            false,
            "Track + Subterannean rejected",
        )
    )
    TestHelper.assert_eq(
        EntityData.is_movement_zone_compatible("Foot", "Fly"), false, "Foot + Fly rejected"
    )
    (
        TestHelper
        . assert_true(
            EntityData.is_movement_zone_compatible("Wheel", "Crusher"),
            "Wheel + Crusher allowed (crushers may be wheeled)",
        )
    )
    TestHelper.assert_true(
        EntityData.is_movement_zone_compatible("Foot", ""), "empty zone always ok"
    )
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_entity_unknown_locomotor_validation():
    var rules := _make_rules()
    _inject_rules(rules)
    var data := EntityData.new()
    data.id = "JET"
    data.entity_type = EntityData.EntityType.VEHICLE
    data.strength = 100
    data.cost = 100
    data.owner = PackedStringArray(["GDI"])
    data.locomotor = "Jetpack"
    var errors := data.validate()
    var hit := false
    for e in errors:
        if e.contains("unknown locomotor"):
            hit = true
    _restore_rules()
    TestHelper.assert_true(hit, "unknown entity locomotor reported")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_entity_contradictory_zone_validation():
    var rules := _make_rules()
    var lm := Locomotor.new()
    lm.id = "Track"
    rules.locomotors["Track"] = lm
    _inject_rules(rules)
    var data := EntityData.new()
    data.id = "TNK"
    data.entity_type = EntityData.EntityType.VEHICLE
    data.strength = 100
    data.cost = 100
    data.owner = PackedStringArray(["GDI"])
    data.locomotor = "Track"
    data.movement_zone = "Subterannean"
    var errors := data.validate()
    var hit := false
    for e in errors:
        if e.contains("contradicts"):
            hit = true
    _restore_rules()
    TestHelper.assert_true(hit, "contradictory zone reported")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
