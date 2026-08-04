extends Node

# TerrainSystem tests — autoload singleton state management

var _ts: Node = null


func test_init_grid_sets_grid_cells():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(16, 16)
    var got: Vector2i = _ts.grid_cells
    _ts.init_grid(32, 32)  # restore
    (
        TestHelper
        . assert_true(
            got == Vector2i(16, 16),
            (
                "init_grid sets grid_cells to (16, 16): expected grid_cells=(16, 16), got %s"
                % str(got)
            ),
        )
    )


func test_asymmetric_diamond_uses_full_extent():
    var map_cells: Vector2i = Vector2i(32, 24)
    var extent: Vector2i = CellUtil.get_diamond_extent(map_cells)
    # Diamond uses |a| ≤ H, |b| ≤ W (swapped from visual axes)
    var tip_cells: Array[Vector2i] = [
        Vector2i(28, 28),  # a=1, b=0
        Vector2i(20, 20),  # a=-15, b=0
    ]
    var all_tips_in_bounds: bool = true
    for cell in tip_cells:
        all_tips_in_bounds = all_tips_in_bounds and CellUtil.is_in_diamond(cell, map_cells)
    var outside: bool = not CellUtil.is_in_diamond(Vector2i(0, 0), map_cells)
    (
        TestHelper
        . assert_true(
            extent == Vector2i(56, 56) and all_tips_in_bounds and outside,
            (
                "asymmetric diamond covers all four requested tips: "
                + "asymmetric diamond extent or tip bounds are incorrect"
            ),
        )
    )


func test_init_grid_resets_vertex_data():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(32, 32)
    _ts.set_vertex(5, 5, 7)
    var before: int = _ts.get_vertex(5, 5)
    _ts.init_grid(32, 32)
    var after: int = _ts.get_vertex(5, 5)
    (
        TestHelper
        . assert_true(
            before == 7 and after == 0,
            "init_grid resets vertex data: before=%d, after=%d" % [before, after],
        )
    )


func test_set_cell_stores_data():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(32, 32)
    var cell := Vector2i(2, 3)
    _ts.compute_and_emit_cell(cell)
    _ts.raise_cell(cell)
    var data: Dictionary = _ts.get_cell(cell)
    _ts.clear()
    (
        TestHelper
        . assert_true(
            not data.is_empty() and data.has("height"),
            "raise_cell stores data with height: expected non-empty data, got %s" % data,
        )
    )


func test_get_cell_empty_for_unset():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(32, 32)
    var data: Dictionary = _ts.get_cell(Vector2i(99, 99))
    TestHelper.assert_true(
        data.is_empty(), "get_cell returns empty for unset cell: expected empty, got %s" % data
    )


func test_raise_edge_does_not_create_phantom_cells():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(8, 8)
    _ts.clear()
    var corner := Vector2i(7, 7)
    _ts.compute_and_emit_cell(corner)
    var before_dict: Dictionary = _ts.get_all_cells()
    var emitted_keys: Array[String] = []
    var on_cell_changed := func(key: String, _data: Dictionary) -> void: emitted_keys.append(key)
    _ts.cell_changed.connect(on_cell_changed)
    _ts.raise_cell(corner)
    _ts.cell_changed.disconnect(on_cell_changed)
    var new_emits := 0
    for k in emitted_keys:
        if not before_dict.has(k):
            new_emits += 1
    _ts.clear()
    (
        TestHelper
        . assert_true(
            new_emits == 0,
            (
                "raise at edge does not emit phantom cells: %d phantom cells emitted at edge"
                % new_emits
            ),
        )
    )


func test_clear_empties_cells():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(32, 32)
    var cell := Vector2i(5, 5)
    _ts.compute_and_emit_cell(cell)
    _ts.raise_cell(cell)
    var before: Dictionary = _ts.get_cell(cell)
    _ts.clear()
    var after: Dictionary = _ts.get_cell(cell)
    (
        TestHelper
        . assert_true(
            not before.is_empty() and after.is_empty(),
            (
                "clear empties cells: before_empty=%s, after_empty=%s"
                % [before.is_empty(), after.is_empty()]
            ),
        )
    )
