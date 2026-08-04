extends Node

# TerrainSystem sparse land-type overlay (uses injected _ts autoload)

var _ts: Node = null


func test_defaults_to_clear():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.set_land_type(Vector2i(10, 10), "clear")
    TestHelper.assert_eq(_ts.get_land_type(Vector2i(10, 10)), "clear", "unset cell -> clear")


func test_set_and_get():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    var cell := Vector2i(23, 17)
    _ts.set_land_type(cell, "water")
    TestHelper.assert_eq(_ts.get_land_type(cell), "water", "set land type read back")
    TestHelper.assert_eq(_ts.get_land_type(Vector2i(24, 17)), "clear", "neighbor stays clear")
    _ts.set_land_type(cell, "clear")


func test_setting_default_clears_override():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    var cell := Vector2i(5, 5)
    _ts.set_land_type(cell, "rough")
    _ts.set_land_type(cell, "clear")
    TestHelper.assert_eq(_ts.get_land_type(cell), "clear", "clear assignment resets to default")
