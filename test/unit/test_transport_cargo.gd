extends Node

# TransportComponent multi-type cargo tests — add_cargo, remove_cargo, get_cargo_total, get_cargo_value

var _test_passed := 0
var _test_failed := 0


func _make_transport(capacity: int = 700) -> TransportComponent:
    var transport := TransportComponent.new()
    transport.name = "TransportComponent"
    transport.resource_capacity = capacity
    return transport


func _make_rules() -> GlobalRules:
    var rules := GlobalRules.new()
    rules.resource_types = {}
    var tib_green := ResourceType.new()
    tib_green.id = "tiberium_green"
    tib_green.value_per_unit = 1.0
    rules.resource_types["tiberium_green"] = tib_green
    var tib_blue := ResourceType.new()
    tib_blue.id = "tiberium_blue"
    tib_blue.value_per_unit = 2.0
    rules.resource_types["tiberium_blue"] = tib_blue
    return rules


func test_add_cargo():
    var transport := _make_transport(700)
    var actual := transport.add_cargo("tiberium_green", 100)
    if actual == 100 and transport.cargo.get("tiberium_green") == 100:
        _test_passed += 1
        print("    PASS: add_cargo adds correctly")
    else:
        _test_failed += 1
        print("    FAIL: add_cargo mismatch")


func test_add_cargo_respects_capacity():
    var transport := _make_transport(50)
    var actual := transport.add_cargo("tiberium_green", 100)
    if actual == 50 and transport.get_cargo_total() == 50:
        _test_passed += 1
        print("    PASS: add_cargo respects capacity")
    else:
        _test_failed += 1
        print("    FAIL: add_cargo did not respect capacity")


func test_remove_cargo():
    var transport := _make_transport(700)
    transport.add_cargo("tiberium_green", 100)
    var actual := transport.remove_cargo("tiberium_green", 30)
    if actual == 30 and transport.cargo.get("tiberium_green") == 70:
        _test_passed += 1
        print("    PASS: remove_cargo removes correctly")
    else:
        _test_failed += 1
        print("    FAIL: remove_cargo mismatch")


func test_remove_cargo_erases_at_zero():
    var transport := _make_transport(700)
    transport.add_cargo("tiberium_green", 100)
    transport.remove_cargo("tiberium_green", 100)
    if transport.cargo.is_empty():
        _test_passed += 1
        print("    PASS: remove_cargo erases at zero")
    else:
        _test_failed += 1
        print("    FAIL: remove_cargo did not erase at zero")


func test_get_cargo_total():
    var transport := _make_transport(700)
    transport.add_cargo("tiberium_green", 300)
    transport.add_cargo("tiberium_blue", 100)
    if transport.get_cargo_total() == 400:
        _test_passed += 1
        print("    PASS: get_cargo_total sums correctly")
    else:
        _test_failed += 1
        print("    FAIL: get_cargo_total returned %d" % transport.get_cargo_total())


func test_get_cargo_value():
    var transport := _make_transport(700)
    transport.add_cargo("tiberium_green", 300)
    transport.add_cargo("tiberium_blue", 100)
    var rules := _make_rules()
    var value := transport.get_cargo_value(rules)
    if value == 500:
        _test_passed += 1
        print("    PASS: get_cargo_value calculates correctly")
    else:
        _test_failed += 1
        print("    FAIL: get_cargo_value returned %d" % value)
