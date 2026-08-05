extends Node

# TerrainSystem heightfield collision tests: bilinear sampler, segment
# intersection, and HeightMapShape3D builder. Uses _set_vertex_no_cascade to
# stamp exact vertex heights (the public set_vertex cascades smoothing).

const CELL_SIZE: float = 2.0
const HEIGHT_STEP: float = 0.815

var _ts: Node = null


func _center(grid: Vector2i) -> float:
    return float(grid.x + grid.y) * 0.5


func _world_from_vertex(grid: Vector2i, vx: float, vz: float) -> Vector3:
    var c := _center(grid)
    return Vector3((vx - c) * CELL_SIZE, 0.0, (vz - c) * CELL_SIZE)


func _stamp_cell(x0: int, z0: int, heights: Array) -> void:
    var corners: Array[Vector2i] = [
        Vector2i(x0, z0), Vector2i(x0 + 1, z0), Vector2i(x0, z0 + 1), Vector2i(x0 + 1, z0 + 1)
    ]
    for i in 4:
        _ts._set_vertex_no_cascade(corners[i].x, corners[i].y, heights[i])


func test_sampler_flat_cell():
    var grid := Vector2i(4, 4)
    _ts.init_grid(grid.x, grid.y)
    _stamp_cell(3, 3, [2, 2, 2, 2])
    var world := _world_from_vertex(grid, 3.5, 3.5)
    var h: float = _ts.get_height_at_world_smooth(world)
    (
        TestHelper
        . assert_true(
            absf(h - 2.0 * HEIGHT_STEP) < 1e-4,
            "flat cell height 2 samples 2*HEIGHT_STEP: got %s" % h,
        )
    )


func test_sampler_single_corner_raised():
    var grid := Vector2i(4, 4)
    _ts.init_grid(grid.x, grid.y)
    _stamp_cell(3, 3, [0, 0, 0, 4])
    var world := _world_from_vertex(grid, 3.5, 3.5)
    var h: float = _ts.get_height_at_world_smooth(world)
    (
        TestHelper
        . assert_true(
            absf(h - 1.0 * HEIGHT_STEP) < 1e-4,
            "single-corner-raised bilinear center = 1.0 raw: got %s" % h,
        )
    )


func test_sampler_flat_invariance_across_grid_shapes():
    for grid in [Vector2i(4, 4), Vector2i(4, 8), Vector2i(5, 7), Vector2i(6, 6)]:
        _ts.init_grid(grid.x, grid.y)
        _stamp_cell(3, 3, [2, 2, 2, 2])
        var world := _world_from_vertex(grid, 3.5, 3.5)
        var h: float = _ts.get_height_at_world_smooth(world)
        (
            TestHelper
            . assert_true(
                absf(h - 2.0 * HEIGHT_STEP) < 1e-4,
                "flat cell invariant across %s: got %s" % [str(grid), h],
            )
        )
    _ts.init_grid(4, 4)


func test_sampler_slope_invariance_across_grid_shapes():
    for grid in [Vector2i(4, 4), Vector2i(4, 8), Vector2i(5, 7), Vector2i(6, 6)]:
        _ts.init_grid(grid.x, grid.y)
        _stamp_cell(3, 3, [0, 0, 0, 4])
        var world := _world_from_vertex(grid, 3.5, 3.5)
        var h: float = _ts.get_height_at_world_smooth(world)
        (
            TestHelper
            . assert_true(
                absf(h - 1.0 * HEIGHT_STEP) < 1e-4,
                "slope invariant across %s: got %s" % [str(grid), h],
            )
        )
    _ts.init_grid(4, 4)


func test_intersect_vertical_hits_flat_terrain():
    var grid := Vector2i(4, 4)
    _ts.init_grid(grid.x, grid.y)
    _stamp_cell(3, 3, [2, 2, 2, 2])
    var top := _world_from_vertex(grid, 3.5, 3.5)
    var bottom := _world_from_vertex(grid, 3.5, 3.5)
    top.y = 10.0
    bottom.y = 0.0
    var hit: Dictionary = _ts.intersect_heightfield_segment(top, bottom)
    TestHelper.assert_true(not hit.is_empty(), "vertical segment hits flat terrain")
    if hit.is_empty():
        return
    var point: Vector3 = hit["point"]
    var cell: Vector2i = hit["cell"]
    (
        TestHelper
        . assert_true(
            absf(point.y - 2.0 * HEIGHT_STEP) < 1e-4,
            "hit at h*HEIGHT_STEP: got %s" % point.y,
        )
    )
    TestHelper.assert_eq(cell, Vector2i(3, 3), "hit cell is (3,3)")


func test_intersect_fully_above_misses():
    var grid := Vector2i(4, 4)
    _ts.init_grid(grid.x, grid.y)
    _stamp_cell(3, 3, [2, 2, 2, 2])
    var a := _world_from_vertex(grid, 3.5, 3.5)
    var b := _world_from_vertex(grid, 3.5, 3.5)
    a.y = 5.0
    b.y = 4.0
    var hit: Dictionary = _ts.intersect_heightfield_segment(a, b)
    (
        TestHelper
        . assert_true(
            hit.is_empty(),
            "segment fully above terrain returns no hit: got %s" % hit,
        )
    )


func test_intersect_crosses_sloped_cell():
    var grid := Vector2i(4, 4)
    _ts.init_grid(grid.x, grid.y)
    _stamp_cell(3, 3, [0, 0, 0, 4])
    var top := _world_from_vertex(grid, 3.5, 3.5)
    var bottom := _world_from_vertex(grid, 3.5, 3.5)
    top.y = 10.0
    bottom.y = 0.0
    var hit: Dictionary = _ts.intersect_heightfield_segment(top, bottom)
    TestHelper.assert_true(not hit.is_empty(), "segment crosses sloped cell")
    if hit.is_empty():
        return
    var point: Vector3 = hit["point"]
    (
        TestHelper
        . assert_true(
            absf(point.y - 1.0 * HEIGHT_STEP) < 1e-4,
            "sloped-cell hit at bilinear surface: got %s" % point.y,
        )
    )


func test_intersect_starting_below_terrain_returns_no_hit():
    var grid := Vector2i(4, 4)
    _ts.init_grid(grid.x, grid.y)
    _stamp_cell(3, 3, [2, 2, 2, 2])
    var a := _world_from_vertex(grid, 3.5, 3.5)
    var b := _world_from_vertex(grid, 3.5, 3.5)
    a.y = 0.0
    b.y = 3.0
    var hit: Dictionary = _ts.intersect_heightfield_segment(a, b)
    (
        TestHelper
        . assert_true(
            hit.is_empty(),
            "up-crossing from below terrain is not reported: got %s" % hit,
        )
    )


func test_intersect_out_of_diamond_corner_no_hit():
    var grid := Vector2i(4, 4)
    _ts.init_grid(grid.x, grid.y)
    _stamp_cell(0, 0, [5, 5, 5, 5])
    var top := _world_from_vertex(grid, 0.5, 0.5)
    var bottom := _world_from_vertex(grid, 0.5, 0.5)
    top.y = 10.0
    bottom.y = 0.0
    var hit: Dictionary = _ts.intersect_heightfield_segment(top, bottom)
    (
        TestHelper
        . assert_true(
            hit.is_empty(),
            "segment over out-of-diamond corner returns no hit: got %s" % hit,
        )
    )


func test_shape_flat_map_and_diamond_holes():
    var grid := Vector2i(4, 4)
    _ts.init_grid(grid.x, grid.y)
    var children_before: int = _ts.get_child_count()
    var shape: HeightMapShape3D = _ts.build_heightfield_shape()
    var children_after: int = _ts.get_child_count()
    TestHelper.assert_true(shape != null, "build_heightfield_shape returns a shape")
    TestHelper.assert_true(shape is HeightMapShape3D, "shape is HeightMapShape3D")
    var v_count := grid.x + grid.y + 1
    TestHelper.assert_eq(shape.map_width, v_count, "map_width is square extent + 1")
    TestHelper.assert_eq(shape.map_depth, v_count, "map_depth is square extent + 1")
    TestHelper.assert_eq(shape.map_data.size(), v_count * v_count, "map_data size")
    TestHelper.assert_eq(children_after, children_before, "builder adds no nodes")
    var center := v_count / 2
    var corner_data := shape.map_data[0]
    TestHelper.assert_true(is_nan(corner_data), "map corner (0,0) is NAN hole")
    var center_data := shape.map_data[center * v_count + center]
    TestHelper.assert_true(absf(center_data - 0.0) < 1e-6, "center vertex height 0")
    _ts.init_grid(4, 4)


func test_shape_heights_scaled_into_map_data():
    var grid := Vector2i(4, 4)
    _ts.init_grid(grid.x, grid.y)
    _ts._set_vertex_no_cascade(4, 4, 3)
    var shape: HeightMapShape3D = _ts.build_heightfield_shape()
    var v_count := grid.x + grid.y + 1
    var idx := 4 * v_count + 4
    var data := shape.map_data[idx]
    (
        TestHelper
        . assert_true(
            absf(data - 3.0 * HEIGHT_STEP) < 1e-4,
            "vertex height 3 scaled into shape: got %s" % data,
        )
    )
    _ts.init_grid(4, 4)


func test_shape_diamond_corner_vertices_are_holes():
    var grid := Vector2i(4, 4)
    _ts.init_grid(grid.x, grid.y)
    var shape: HeightMapShape3D = _ts.build_heightfield_shape()
    var v_count := grid.x + grid.y + 1
    TestHelper.assert_true(is_nan(shape.map_data[0]), "corner (0,0) NAN")
    TestHelper.assert_true(is_nan(shape.map_data[v_count - 1]), "corner (0,max) NAN")
    TestHelper.assert_true(is_nan(shape.map_data[(v_count - 1) * v_count]), "corner (max,0) NAN")
    (
        TestHelper
        . assert_true(
            is_nan(shape.map_data[(v_count - 1) * v_count + (v_count - 1)]),
            "corner (max,max) NAN",
        )
    )


func test_shape_creates_no_physics_nodes():
    var grid := Vector2i(4, 4)
    _ts.init_grid(grid.x, grid.y)
    var root_before: int = _ts.get_tree().root.get_child_count()
    _ts.build_heightfield_shape()
    var root_after: int = _ts.get_tree().root.get_child_count()
    TestHelper.assert_eq(root_after, root_before, "no nodes added to the scene tree")


func test_consistency_height_intersect_shape_agree_on_slope():
    var grid := Vector2i(4, 4)
    _ts.init_grid(grid.x, grid.y)
    _stamp_cell(3, 3, [0, 0, 0, 4])
    var world := _world_from_vertex(grid, 3.5, 3.5)
    var smooth: float = _ts.get_height_at_world_smooth(world)
    var top := world
    var bottom := world
    top.y = 10.0
    bottom.y = 0.0
    var hit: Dictionary = _ts.intersect_heightfield_segment(top, bottom)
    var shape: HeightMapShape3D = _ts.build_heightfield_shape()
    var v_count := grid.x + grid.y + 1
    var h00 := shape.map_data[3 * v_count + 3]
    var h10 := shape.map_data[3 * v_count + 4]
    var h01 := shape.map_data[4 * v_count + 3]
    var h11 := shape.map_data[4 * v_count + 4]
    var shape_center := 0.25 * h00 + 0.25 * h10 + 0.25 * h01 + 0.25 * h11
    TestHelper.assert_true(not hit.is_empty(), "segment hits slope")
    if hit.is_empty():
        return
    var point: Vector3 = hit["point"]
    (
        TestHelper
        . assert_true(
            absf(smooth - shape_center) < 1e-4,
            "smooth query and shape bilinear agree: %s vs %s" % [smooth, shape_center],
        )
    )
    (
        TestHelper
        . assert_true(
            absf(point.y - smooth) < 1e-4,
            "intersection and smooth query agree: %s vs %s" % [point.y, smooth],
        )
    )
    _ts.init_grid(4, 4)
