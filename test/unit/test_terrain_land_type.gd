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


func test_resource_cell_resolves_to_resource():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    var cell := Vector2i(10, 10)
    SpatialHash.instance.register_resource_cell(cell)
    TestHelper.assert_eq(_ts.get_land_type(cell), "resource", "resource cell -> resource land type")
    SpatialHash.instance.unregister_resource_cell(cell)
    TestHelper.assert_eq(_ts.get_land_type(cell), "clear", "depleted cell reverts to clear")


func test_resource_overrides_painted_land_type():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    var cell := Vector2i(11, 11)
    _ts.set_land_type(cell, "rough")
    SpatialHash.instance.register_resource_cell(cell)
    TestHelper.assert_eq(_ts.get_land_type(cell), "resource", "crystal overrides painted land type")
    SpatialHash.instance.unregister_resource_cell(cell)
    _ts.set_land_type(cell, "clear")
