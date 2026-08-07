extends Node

# Map dimension persistence — JSON v4 map_size / visible_bounds round-trip

var _ts: Node = null


func _bounds() -> Node:
    if _ts == null:
        return null
    return _ts.get_node_or_null("/root/BoundsSystem")


func test_export_writes_v4_dimensions() -> void:
    var bounds := _bounds()
    if _ts == null or bounds == null:
        TestHelper.fail("TerrainSystem/BoundsSystem not available")
        return

    _ts.init_grid(40, 40)  # emits grid_initialized -> syncs BoundsSystem.grid_cells
    bounds.left_inset = 5
    bounds.right_inset = 5
    bounds.top_inset = 4
    bounds.bottom_inset = 4

    var path := "user://test_bounds_persist.json"
    _ts.export_to_json(path)

    var file := FileAccess.open(path, FileAccess.READ)
    var data: Dictionary = {}
    if file:
        data = JSON.parse_string(file.get_as_text()) as Dictionary
        file.close()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

    var map_size: Array = data.get("map_size", [])
    var vb: Array = data.get("visible_bounds", [])
    TestHelper.assert_eq(int(data.get("version", 0)), 4, "version is 4")
    TestHelper.assert_eq(map_size.size(), 2, "map_size has 2 entries")
    if map_size.size() == 2:
        TestHelper.assert_eq(int(map_size[0]), 40, "map_size.x == grid_cells.x")
        TestHelper.assert_eq(int(map_size[1]), 40, "map_size.y == grid_cells.y")
    TestHelper.assert_eq(vb.size(), 4, "visible_bounds has 4 entries")
    if vb.size() == 4:
        TestHelper.assert_eq(int(vb[0]), 5, "visible_bounds[0] == left_inset")
        TestHelper.assert_eq(int(vb[1]), 5, "visible_bounds[1] == right_inset")
        TestHelper.assert_eq(int(vb[2]), 4, "visible_bounds[2] == top_inset")
        TestHelper.assert_eq(int(vb[3]), 4, "visible_bounds[3] == bottom_inset")

    _ts.init_grid(64, 64)  # restore default


func test_apply_saved_bounds_v4() -> void:
    var bounds := _bounds()
    if bounds == null:
        TestHelper.fail("BoundsSystem not available")
        return

    bounds.grid_cells = Vector2i(40, 40)
    bounds.apply_saved_bounds({"visible_bounds": [5, 5, 4, 4]})

    TestHelper.assert_eq(bounds.left_inset, 5, "left_inset recovered")
    TestHelper.assert_eq(bounds.right_inset, 5, "right_inset recovered")
    TestHelper.assert_eq(bounds.top_inset, 4, "top_inset recovered")
    TestHelper.assert_eq(bounds.bottom_inset, 4, "bottom_inset recovered")


func test_apply_saved_bounds_v3_fallback() -> void:
    var bounds := _bounds()
    if bounds == null:
        TestHelper.fail("BoundsSystem not available")
        return

    bounds.grid_cells = Vector2i(40, 40)
    bounds.left_inset = 99
    bounds.right_inset = 99
    bounds.top_inset = 99
    bounds.bottom_inset = 99
    bounds.apply_saved_bounds({"version": 3})  # no visible_bounds

    TestHelper.assert_eq(bounds.left_inset, 5, "v3 fallback left_inset == 5")
    TestHelper.assert_eq(bounds.right_inset, 5, "v3 fallback right_inset == 5")
    TestHelper.assert_eq(bounds.top_inset, 4, "v3 fallback top_inset == 4")
    TestHelper.assert_eq(bounds.bottom_inset, 4, "v3 fallback bottom_inset == 4")


func test_apply_saved_bounds_clamps_negative() -> void:
    var bounds := _bounds()
    if bounds == null:
        TestHelper.fail("BoundsSystem not available")
        return

    bounds.grid_cells = Vector2i(40, 40)
    # negative insets are clamped to 0
    bounds.apply_saved_bounds({"visible_bounds": [-5, -5, -3, -3]})

    TestHelper.assert_eq(bounds.left_inset, 0, "inset clamped to 0")
    TestHelper.assert_eq(bounds.right_inset, 0, "inset clamped to 0")
    TestHelper.assert_eq(bounds.top_inset, 0, "inset clamped to 0")
    TestHelper.assert_eq(bounds.bottom_inset, 0, "inset clamped to 0")


func test_apply_saved_bounds_clamps_oversized() -> void:
    var bounds := _bounds()
    if bounds == null:
        TestHelper.fail("BoundsSystem not available")
        return

    bounds.grid_cells = Vector2i(40, 40)
    # insets larger than the grid would invert the sum/diff range — clamp so the
    # play area stays non-empty (at most grid_cells - 1 per axis)
    bounds.apply_saved_bounds({"visible_bounds": [100, 100, 100, 100]})

    TestHelper.assert_eq(bounds.left_inset, 39, "left inset clamped to grid width - 1")
    TestHelper.assert_eq(bounds.right_inset, 39, "right inset clamped to grid width - 1")
    TestHelper.assert_eq(bounds.top_inset, 39, "top inset clamped to grid height - 1")
    TestHelper.assert_eq(bounds.bottom_inset, 39, "bottom inset clamped to grid height - 1")
