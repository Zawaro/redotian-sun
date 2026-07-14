extends Node

# Resource type hierarchy tests — get_resource_category, get_subtypes

var _test_passed := 0
var _test_failed := 0


func _make_global_rules() -> GlobalRules:
    var rules := GlobalRules.new()
    rules.resource_types = {}
    var tib := ResourceType.new()
    tib.id = "tiberium"
    tib.category = ""
    tib.value = 1.0
    rules.resource_types["tiberium"] = tib

    var tib_green := ResourceType.new()
    tib_green.id = "tiberium_green"
    tib_green.category = "tiberium"
    tib_green.parent_type = "tiberium"
    tib_green.value = 1.0
    rules.resource_types["tiberium_green"] = tib_green

    var tib_blue := ResourceType.new()
    tib_blue.id = "tiberium_blue"
    tib_blue.category = "tiberium"
    tib_blue.parent_type = "tiberium"
    tib_blue.value = 2.0
    rules.resource_types["tiberium_blue"] = tib_blue

    var vein := ResourceType.new()
    vein.id = "vein"
    vein.category = "weed"
    vein.value = 0.5
    rules.resource_types["vein"] = vein

    return rules


func test_get_resource_type():
    var rules := _make_global_rules()
    var rt := rules.get_resource_type("tiberium_green")
    if rt and rt.id == "tiberium_green" and rt.value == 1.0:
        _test_passed += 1
        print("    PASS: get_resource_type returns correct type")
    else:
        _test_failed += 1
        print("    FAIL: get_resource_type returned wrong type")


func test_get_resource_category():
    var rules := _make_global_rules()
    var category := rules.get_resource_category("tiberium_green")
    if category == "tiberium":
        _test_passed += 1
        print("    PASS: get_resource_category returns parent category")
    else:
        _test_failed += 1
        print("    FAIL: get_resource_category returned '%s'" % category)


func test_get_resource_category_top_level():
    var rules := _make_global_rules()
    var category := rules.get_resource_category("tiberium")
    if category == "tiberium":
        _test_passed += 1
        print("    PASS: get_resource_category returns self for top-level")
    else:
        _test_failed += 1
        print("    FAIL: get_resource_category returned '%s'" % category)


func test_get_subtypes():
    var rules := _make_global_rules()
    var subtypes := rules.get_subtypes("tiberium")
    if subtypes.has("tiberium_green") and subtypes.has("tiberium_blue"):
        _test_passed += 1
        print("    PASS: get_subtypes returns all sub-types")
    else:
        _test_failed += 1
        print("    FAIL: get_subtypes missing entries: %s" % subtypes)
