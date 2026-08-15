extends Node

# TerrainSystem.get_cell_grade_steps tests — per-cell corner-height span.

var _ts: Node = null


func _ready() -> void:
    _ts = get_node_or_null("/root/TerrainSystem")


func _stamp(cell: Vector2i, corners: Array[int]) -> void:
    var offsets: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
    for i in 4:
        var v := cell + offsets[i]
        _ts._set_vertex_no_cascade(v.x, v.y, corners[i])


func test_grade_steps_flat_cell_is_zero():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(32, 32)
    _stamp(Vector2i(5, 5), [0, 0, 0, 0])
    var steps: int = _ts.get_cell_grade_steps(Vector2i(5, 5))
    _ts.init_grid(32, 32)
    TestHelper.assert_eq(steps, 0, "flat cell grade steps should be 0")


func test_grade_steps_single_step_slope_is_one():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(32, 32)
    _stamp(Vector2i(5, 5), [0, 0, 1, 1])
    var steps: int = _ts.get_cell_grade_steps(Vector2i(5, 5))
    _ts.init_grid(32, 32)
    TestHelper.assert_eq(steps, 1, "single-step slope grade steps should be 1")


func test_grade_steps_two_step_cliff_is_two():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(32, 32)
    _stamp(Vector2i(5, 5), [0, 0, 2, 2])
    var steps: int = _ts.get_cell_grade_steps(Vector2i(5, 5))
    _ts.init_grid(32, 32)
    TestHelper.assert_eq(steps, 2, "two-step cliff grade steps should be 2")


func test_grade_steps_stair_span_two_edge_rise_one():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(32, 32)
    _stamp(Vector2i(5, 5), [0, 1, 1, 2])
    var steps: int = _ts.get_cell_grade_steps(Vector2i(5, 5))
    _ts.init_grid(32, 32)
    TestHelper.assert_eq(
        steps, 1, "stair [0,1,1,2] spans two levels but every edge rises one: grade 1"
    )


func test_grade_steps_three_step_face_is_three():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(32, 32)
    _stamp(Vector2i(5, 5), [0, 0, 3, 3])
    var steps: int = _ts.get_cell_grade_steps(Vector2i(5, 5))
    _ts.init_grid(32, 32)
    TestHelper.assert_eq(steps, 3, "three-step face grade steps should be 3")


func test_grade_steps_out_of_bounds_is_zero():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(32, 32)
    var steps: int = _ts.get_cell_grade_steps(Vector2i(200, 200))
    _ts.init_grid(32, 32)
    TestHelper.assert_eq(steps, 0, "out-of-bounds cell grade steps should be 0")
