extends Node

# Resource type hierarchy tests — get_resource_category, get_subtypes


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
    (
        TestHelper
        . assert_true(
            rt and rt.id == "tiberium_green" and rt.value == 1.0,
            "get_resource_type returns correct type: get_resource_type returned wrong type",
        )
    )


func test_get_resource_category():
    var rules := _make_global_rules()
    var category := rules.get_resource_category("tiberium_green")
    (
        TestHelper
        . assert_true(
            category == "tiberium",
            (
                "get_resource_category returns parent category: get_resource_category returned '%s'"
                % category
            ),
        )
    )


func test_get_resource_category_top_level():
    var rules := _make_global_rules()
    var category := rules.get_resource_category("tiberium")
    (
        TestHelper
        . assert_true(
            category == "tiberium",
            (
                (
                    "get_resource_category returns self for top-level: "
                    + "get_resource_category returned '%s'"
                )
                % category
            ),
        )
    )


func test_get_subtypes():
    var rules := _make_global_rules()
    var subtypes := rules.get_subtypes("tiberium")
    (
        TestHelper
        . assert_true(
            subtypes.has("tiberium_green") and subtypes.has("tiberium_blue"),
            "get_subtypes returns all sub-types: get_subtypes missing entries: %s" % subtypes,
        )
    )
