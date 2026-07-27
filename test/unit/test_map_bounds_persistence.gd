extends Node

# Map dimension persistence — JSON v4 map_size / visible_bounds_size round-trip

var _ts: Node = null
var _test_passed := 0
var _test_failed := 0


func _bounds() -> Node:
    if _ts == null:
        return null
    return _ts.get_node_or_null("/root/BoundsSystem")


func test_export_writes_v4_dimensions():
    var bounds := _bounds()
    if _ts == null or bounds == null:
        _test_failed += 1
        print("    FAIL: TerrainSystem/BoundsSystem not available")
        return

    _ts.init_grid(40, 40)  # emits grid_initialized -> syncs BoundsSystem.grid_cells
    bounds.visible_offset_x = 5
    bounds.visible_offset_z = 4

    var path := "user://test_bounds_persist.json"
    _ts.export_to_json(path)

    var file := FileAccess.open(path, FileAccess.READ)
    var data: Dictionary = {}
    if file:
        data = JSON.parse_string(file.get_as_text()) as Dictionary
        file.close()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

    var map_size: Array = data.get("map_size", [])
    var vbs: Array = data.get("visible_bounds_size", [])
    TestHelper.assert_eq(int(data.get("version", 0)), 4, "version is 4")
    TestHelper.assert_eq(map_size.size(), 2, "map_size has 2 entries")
    if map_size.size() == 2:
        TestHelper.assert_eq(int(map_size[0]), 40, "map_size.x == grid_cells.x")
        TestHelper.assert_eq(int(map_size[1]), 40, "map_size.y == grid_cells.y")
    TestHelper.assert_eq(vbs.size(), 2, "visible_bounds_size has 2 entries")
    if vbs.size() == 2:
        TestHelper.assert_eq(int(vbs[0]), 30, "visible width == 40 - 2*5")
        TestHelper.assert_eq(int(vbs[1]), 32, "visible height == 40 - 2*4")

    _ts.init_grid(64, 64)  # restore default
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_apply_saved_bounds_v4():
    var bounds := _bounds()
    if bounds == null:
        _test_failed += 1
        print("    FAIL: BoundsSystem not available")
        return

    bounds.grid_cells = Vector2i(40, 40)
    bounds.apply_saved_bounds({"visible_bounds_size": [30, 32]})

    TestHelper.assert_eq(bounds.visible_offset_x, 5, "offset_x recovered from size")
    TestHelper.assert_eq(bounds.visible_offset_z, 4, "offset_z recovered from size")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_apply_saved_bounds_v3_fallback():
    var bounds := _bounds()
    if bounds == null:
        _test_failed += 1
        print("    FAIL: BoundsSystem not available")
        return

    bounds.grid_cells = Vector2i(40, 40)
    bounds.visible_offset_x = 99
    bounds.visible_offset_z = 99
    bounds.apply_saved_bounds({"version": 3})  # no visible_bounds_size

    TestHelper.assert_eq(bounds.visible_offset_x, 10, "v3 fallback offset_x == 10")
    TestHelper.assert_eq(bounds.visible_offset_z, 8, "v3 fallback offset_z == 8")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_apply_saved_bounds_clamps_negative():
    var bounds := _bounds()
    if bounds == null:
        _test_failed += 1
        print("    FAIL: BoundsSystem not available")
        return

    bounds.grid_cells = Vector2i(40, 40)
    # visible size larger than the grid would imply a negative inset
    bounds.apply_saved_bounds({"visible_bounds_size": [80, 80]})

    TestHelper.assert_eq(bounds.visible_offset_x, 0, "inset clamped to 0")
    TestHelper.assert_eq(bounds.visible_offset_z, 0, "inset clamped to 0")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
