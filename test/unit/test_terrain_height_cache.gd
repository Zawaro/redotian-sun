extends Node

# World-lifetime TerrainSystem height snapshot: cache served, bit-identical float
# output, invalidation on paint/grid re-init, land-type exclusion.

var _ts: Node = null


func test_height_snapshot_serves_repeat_query():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(50, 50)
    _ts.clear()
    _ts.set_vertex(10, 10, 3)
    _ts.set_vertex(11, 10, 3)
    _ts.set_vertex(10, 11, 3)
    _ts.set_vertex(11, 11, 3)
    var cell := Vector2i(10, 10)
    var first: float = _ts.get_cell_max_height(cell)
    var snapshot_size_before: int = _ts._height_snapshot.size()
    # Mutate the live grid behind the cache's back; the second read must still be
    # served from the snapshot (proving it did not re-index _vertex_grid).
    _ts._vertex_grid[10][10] = 7
    var second: float = _ts.get_cell_max_height(cell)
    _ts.clear()
    TestHelper.assert_eq(snapshot_size_before >= 1, true, "snapshot populated after first query")
    TestHelper.assert_eq(first, second, "repeat query served from snapshot, not live grid")
    TestHelper.assert_eq(first, 3.0 * _ts.HEIGHT_STEP, "max-corner height from snapshot")


func test_height_snapshot_float_parity_with_direct_reads():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(50, 50)
    _ts.clear()
    var patch := {
        Vector2i(10, 10): [0, 0, 0, 0],
        Vector2i(12, 10): [2, 2, 2, 2],
        Vector2i(10, 12): [0, 3, 0, 3],
        Vector2i(12, 12): [1, 3, 3, 1],
    }
    for cell: Vector2i in patch:
        var corners: Array = patch[cell]
        _ts._vertex_grid[cell.x][cell.y] = corners[0]
        _ts._vertex_grid[cell.x + 1][cell.y] = corners[1]
        _ts._vertex_grid[cell.x][cell.y + 1] = corners[2]
        _ts._vertex_grid[cell.x + 1][cell.y + 1] = corners[3]
    _ts.invalidate_height_snapshot()
    for cell: Vector2i in patch:
        var corners: Array = patch[cell]
        var direct_max: float = (
            float(maxi(maxi(corners[0], corners[1]), maxi(corners[2], corners[3])))
            * _ts.HEIGHT_STEP
        )
        var direct_min: float = (
            float(mini(mini(corners[0], corners[1]), mini(corners[2], corners[3])))
            * _ts.HEIGHT_STEP
        )
        _ts.invalidate_height_snapshot()
        var cached_max: float = _ts.get_cell_max_height(cell)
        _ts.invalidate_height_snapshot()
        var cached_min: float = _ts.get_cell_min_height(cell)
        TestHelper.assert_eq(cached_max, direct_max, "max-corner snapshot matches direct read")
        TestHelper.assert_eq(cached_min, direct_min, "min-corner snapshot matches direct read")
    _ts.clear()


func test_smooth_height_parity_with_snapshot():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(50, 50)
    _ts.clear()
    var patch := {
        Vector2i(10, 10): [0, 0, 0, 0],
        Vector2i(12, 10): [2, 2, 2, 2],
        Vector2i(10, 12): [0, 3, 0, 3],
        Vector2i(12, 12): [1, 3, 3, 1],
    }
    for cell: Vector2i in patch:
        var corners: Array = patch[cell]
        _ts._vertex_grid[cell.x][cell.y] = corners[0]
        _ts._vertex_grid[cell.x + 1][cell.y] = corners[1]
        _ts._vertex_grid[cell.x][cell.y + 1] = corners[2]
        _ts._vertex_grid[cell.x + 1][cell.y + 1] = corners[3]
    _ts.invalidate_height_snapshot()
    for cell: Vector2i in patch:
        for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
            var pos: Vector3 = (
                CellUtil.cell_to_world(cell)
                + Vector3(float(offset.x) * 0.5, 0.0, float(offset.y) * 0.5)
            )
            var expect: float = (
                (
                    _ts
                    . _sample_heightfield_at(
                        (
                            pos.x / CellUtil.CELL_SIZE
                            + float(_ts.grid_cells.x + _ts.grid_cells.y) * 0.5
                        ),
                        (
                            pos.z / CellUtil.CELL_SIZE
                            + float(_ts.grid_cells.x + _ts.grid_cells.y) * 0.5
                        ),
                    )
                )
                * _ts.HEIGHT_STEP
            )
            var got: float = _ts.get_height_at_world_smooth(pos)
            TestHelper.assert_eq(
                got, expect, "smooth height served from snapshot matches direct sample"
            )
    _ts.clear()


func test_snapshot_invalidated_on_single_cell_paint():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(50, 50)
    _ts.clear()
    var cell := Vector2i(20, 20)
    var before: float = _ts.get_cell_max_height(cell)
    # Paint through set_vertex (emits cell_changed) -> snapshot must be invalidated.
    # Height 1: within one step of the surrounding 0s, so the cascade does not
    # normalize it away and the raised cell keeps a deterministic value.
    _ts.set_vertex(20, 20, 1)
    _ts.set_vertex(21, 20, 1)
    _ts.set_vertex(20, 21, 1)
    _ts.set_vertex(21, 21, 1)
    var after: float = _ts.get_cell_max_height(cell)
    _ts.clear()
    TestHelper.assert_eq(before, 0.0, "pre-paint max height is 0")
    TestHelper.assert_eq(after, 1.0 * _ts.HEIGHT_STEP, "post-paint max height re-read live grid")
    TestHelper.assert_true(after > before, "paint raised the cell (cache did not serve stale 0)")


func test_snapshot_cleared_on_grid_reinit():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(50, 50)
    _ts.clear()
    var cell := Vector2i(20, 20)
    _ts.set_vertex(20, 20, 4)
    _ts.set_vertex(21, 20, 4)
    _ts.set_vertex(20, 21, 4)
    _ts.set_vertex(21, 21, 4)
    _ts.get_cell_max_height(cell)
    var gen_before: int = _ts.height_snapshot_generation
    _ts.init_grid(50, 50)
    var gen_after: int = _ts.height_snapshot_generation
    var after: float = _ts.get_cell_max_height(cell)
    _ts.clear()
    TestHelper.assert_true(gen_after > gen_before, "grid re-init bumps snapshot generation")
    TestHelper.assert_eq(after, 0.0, "grid re-init clears snapshot (cell reads 0)")


func test_unaffected_cells_keep_cached_values():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(50, 50)
    _ts.clear()
    var far_cell := Vector2i(30, 30)
    _ts.set_vertex(30, 30, 2)
    _ts.set_vertex(31, 30, 2)
    _ts.set_vertex(30, 31, 2)
    _ts.set_vertex(31, 31, 2)
    var far_before: float = _ts.get_cell_max_height(far_cell)
    # Paint an unrelated cell.
    _ts.set_vertex(20, 20, 5)
    var far_after: float = _ts.get_cell_max_height(far_cell)
    _ts.clear()
    TestHelper.assert_eq(
        far_before, far_after, "distant cell keeps cached value after unrelated paint"
    )


func test_land_type_not_cached_world_lifetime():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(50, 50)
    _ts.clear()
    var cell := Vector2i(20, 20)
    # Height IS cached world-lifetime...
    _ts.set_vertex(20, 20, 2)
    _ts.set_vertex(21, 20, 2)
    _ts.set_vertex(20, 21, 2)
    _ts.set_vertex(21, 21, 2)
    _ts.get_cell_max_height(cell)
    # ...but land type resolves through the live registry: harvest/growth mutate
    # the SpatialHash resource registry with no cell_changed signal, so a probe
    # after the registry changes must see the fresh land type.
    _ts.set_land_type(cell, "rough")
    _ts.invalidate_height_snapshot()
    var land: String = _ts.get_land_type(cell)
    _ts.clear()
    TestHelper.assert_eq(land, "rough", "land type resolved live, not from a world-lifetime cache")


func test_resource_registry_change_reflects_fresh_land():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(50, 50)
    _ts.clear()
    var cell := Vector2i(20, 20)
    var before: String = _ts.get_land_type(cell)
    SpatialHash.instance.register_resource_cell(cell)
    var after: String = _ts.get_land_type(cell)
    SpatialHash.instance.unregister_resource_cell(cell)
    _ts.clear()
    TestHelper.assert_eq(before, "clear", "no resource -> clear land")
    TestHelper.assert_eq(after, "resource", "resource registry change reflected immediately")
