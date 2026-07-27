extends Node

# Component-level validation tests — each component's validate(data) method.
# Covers valid and invalid EntityData for every component that validates.

var _test_passed := 0
var _test_failed := 0


func _data(overrides: Dictionary = {}) -> EntityData:
    var data := EntityData.new()
    data.id = "E1"
    for key in overrides:
        data.set(key, overrides[key])
    return data


func _check(cond: bool, msg: String) -> void:
    if cond:
        _test_passed += 1
        print("    PASS: " + msg)
    else:
        _test_failed += 1
        print("    FAIL: " + msg)


func _contains(errors: PackedStringArray, substr: String) -> bool:
    for e in errors:
        if e.contains(substr):
            return true
    return false


# --- MovementController ---


func test_movement_zero_speed_warns():
    var mc := MovementController.new()
    var errors := mc.validate(_data({"speed": 0.0}))
    _check(_contains(errors, "speed"), "MovementController warns on speed <= 0")
    mc.free()


func test_movement_valid_speed_ok():
    var mc := MovementController.new()
    var errors := mc.validate(_data({"speed": 5.0}))
    _check(errors.is_empty(), "MovementController silent on valid speed")
    mc.free()


# --- FoundationComponent ---


func test_foundation_zero_warns():
    var fc := FoundationComponent.new()
    var errors := fc.validate(_data({"foundation": Vector2i(0, 0)}))
    _check(_contains(errors, "foundation"), "FoundationComponent warns on zero foundation")
    fc.free()


func test_foundation_valid_ok():
    var fc := FoundationComponent.new()
    var errors := fc.validate(_data({"foundation": Vector2i(2, 2)}))
    _check(errors.is_empty(), "FoundationComponent silent on valid foundation")
    fc.free()


# --- FactoryComponent ---


func test_factory_unknown_type_warns():
    var f := FactoryComponent.new()
    var errors := f.validate(_data({"factory": "BogusType"}))
    _check(_contains(errors, "BogusType"), "FactoryComponent warns on unknown factory type")
    f.free()


func test_factory_known_type_ok():
    var f := FactoryComponent.new()
    var errors := f.validate(_data({"factory": "InfantryType"}))
    _check(errors.is_empty(), "FactoryComponent silent on known factory type")
    f.free()


func test_factory_empty_type_ok():
    var f := FactoryComponent.new()
    var errors := f.validate(_data({"factory": ""}))
    _check(errors.is_empty(), "FactoryComponent silent on empty factory type")
    f.free()


# --- TransportComponent ---


func test_transport_harvester_without_dock_warns():
    var t := TransportComponent.new()
    var errors := t.validate(_data({"harvester": true, "dock": ""}))
    _check(_contains(errors, "dock"), "TransportComponent warns on harvester without dock")
    t.free()


func test_transport_harvester_with_dock_ok():
    var t := TransportComponent.new()
    var errors := t.validate(_data({"harvester": true, "dock": "PROC"}))
    _check(errors.is_empty(), "TransportComponent silent on harvester with dock")
    t.free()


# --- SpecialAbilityComponent ---


func test_special_ability_todo_per_flag():
    var s := SpecialAbilityComponent.new()
    var errors := s.validate(_data({"cloakable": true}))
    _check(
        _contains(errors, "TODO: cloakable not implemented for 'E1'"),
        "SpecialAbilityComponent logs TODO for enabled ability"
    )
    s.free()


func test_special_ability_none_ok():
    var s := SpecialAbilityComponent.new()
    var errors := s.validate(_data())
    _check(errors.is_empty(), "SpecialAbilityComponent silent when no abilities enabled")
    s.free()


# --- CombatComponent (existing validate, now exercised) ---


func test_combat_empty_weapons_warns():
    var c := CombatComponent.new()
    var errors := c.validate(_data({"weapons": []}))
    _check(_contains(errors, "no weapons"), "CombatComponent warns on empty weapons")
    c.free()
