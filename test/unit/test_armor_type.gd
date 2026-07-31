extends Node

# ArmorType resource tests — identity and display properties

var _test_passed := 0
var _test_failed := 0


func _make_armor_type(id: String, display_name: String) -> ArmorType:
    var at := ArmorType.new()
    at.id = id
    at.display_name = display_name
    at.color = Color(1, 0, 0, 1)
    return at


func test_armor_type_fields():
    var at := _make_armor_type("heavy", "Heavy")
    TestHelper.assert_eq(at.id, "heavy", "armor type stores id")
    TestHelper.assert_eq(at.display_name, "Heavy", "armor type stores display_name")
    TestHelper.assert_eq(at.color, Color(1, 0, 0, 1), "armor type stores color")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_armor_type_defaults():
    var at := ArmorType.new()
    TestHelper.assert_eq(at.id, "", "default id is empty")
    TestHelper.assert_eq(at.display_name, "", "default display_name is empty")
    TestHelper.assert_eq(at.color, Color.WHITE, "default color is white")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
