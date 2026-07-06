extends Node

# Pathfinder + TerrainSystem integration tests

var _ts: Node = null
var _test_passed := 0
var _test_failed := 0


func test_get_terrain_height_returns_float():
    if _ts == null:
        _test_failed += 1
        print("    FAIL: TerrainSystem not injected")
        return
    _ts.init_grid(32)
    _ts.raise_cell(Vector2i(5, 5))
    var height: float = Pathfinder.get_terrain_height(Vector2i(5, 5))
    _ts.clear()
    # height is always float from get_terrain_height, just verify it's a valid number
    if not is_nan(height) and not is_inf(height):
        _test_passed += 1
        print("    PASS: get_terrain_height returns valid float: %f" % height)
    else:
        _test_failed += 1
        print("    FAIL: got NaN or Inf: %f" % height)


func test_find_path_returns_array():
    if _ts == null:
        _test_failed += 1
        print("    FAIL: TerrainSystem not injected")
        return
    _ts.init_grid(32)
    var start := Vector3(1.0, 0.0, 1.0)
    var end := Vector3(5.0, 0.0, 5.0)
    var path: PackedVector3Array = Pathfinder.find_path(start, end)
    _ts.clear()
    if path.size() > 0:
        _test_passed += 1
        print("    PASS: find_path returns %d waypoints" % path.size())
    else:
        _test_failed += 1
        print("    FAIL: expected waypoints, got empty array")


func test_find_path_empty_for_same_cell():
    if _ts == null:
        _test_failed += 1
        print("    FAIL: TerrainSystem not injected")
        return
    _ts.init_grid(32)
    var pos := Vector3(3.0, 0.0, 3.0)
    var path: PackedVector3Array = Pathfinder.find_path(pos, pos)
    _ts.clear()
    if path.size() == 0:
        _test_passed += 1
        print("    PASS: find_path returns empty for same cell")
    else:
        _test_failed += 1
        print("    FAIL: expected empty, got %d waypoints" % path.size())
