extends Node

# ArmorType resource tests — identity and display properties


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


func test_armor_type_defaults():
    var at := ArmorType.new()
    TestHelper.assert_eq(at.id, "", "default id is empty")
    TestHelper.assert_eq(at.display_name, "", "default display_name is empty")
    TestHelper.assert_eq(at.color, Color.WHITE, "default color is white")
