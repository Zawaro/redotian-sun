extends Node

# MovementController frame-scoped per-cell cache (#284): land type resolved once
# per cell per frame, the 3×3 avoidance hood fetched once per unique cell per
# frame, and the facing normal routed through the corner snapshot with bit-parity
# against TerrainSystem.get_normal_at_world.

var _ts: Node = null
var _sh: Node = null


func _reset_terrain() -> void:
    if _ts:
        _ts.init_grid(50, 50)
        _ts.clear()


func _make_mc(entity_type: int) -> Array:
    var entity := Node3D.new()
    var stats := StatsComponent.new()
    stats.entity_type = entity_type
    stats.player_id = 0
    stats.weight = 3.0
    entity.add_child(stats)
    var mc := MovementController.new()
    entity.add_child(mc)
    mc._parent = entity
    return [entity, mc]


func _reset_frame_cache() -> void:
    MovementController._frame_cells.clear()
    MovementController._frame_cells_frame = -1
    MovementController._frame_cells_gen = -1
    MovementController._frame_cells_grid_gen = -1


func test_land_type_resolved_once_per_cell_per_frame():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _reset_terrain()
    var pair: Array = _make_mc(EntityData.EntityType.VEHICLE)
    var mc: MovementController = pair[1]
    var cell := CellUtil.world_to_cell(Vector3(0.2, 0.0, 0.2))
    _ts.set_land_type(cell, "rough")
    _reset_frame_cache()
    _ts.land_type_query_count = 0
    # Two units on the same cell resolve the land type once; the second read must
    # be served from the cache (not a fresh get_land_type call).
    var land_a: String = mc._frame_cell_land(cell)
    var land_b: String = mc._frame_cell_land(cell)
    var queries_after_two: int = _ts.land_type_query_count
    _reset_terrain()
    pair[0].queue_free()
    TestHelper.assert_eq(land_a, "rough", "land type resolved for the cell")
    TestHelper.assert_eq(land_b, "rough", "second read returns the cached land type")
    TestHelper.assert_eq(
        queries_after_two, 1, "land type queried once per cell per frame, not once per unit"
    )


func test_frame_advance_clears_land_cache():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _reset_terrain()
    var pair: Array = _make_mc(EntityData.EntityType.VEHICLE)
    var mc: MovementController = pair[1]
    var cell := CellUtil.world_to_cell(Vector3(0.2, 0.0, 0.2))
    _ts.set_land_type(cell, "rough")
    _reset_frame_cache()
    mc._frame_cell_land(cell)
    # A frame advance (simulated by bumping the height-snapshot generation, the
    # same guard the cache keys on) clears the cache; the next read re-queries.
    _ts.land_type_query_count = 0
    _ts.invalidate_height_snapshot()
    _ts.set_land_type(cell, "clear")
    var land_after: String = mc._frame_cell_land(cell)
    var queries_after: int = _ts.land_type_query_count
    _reset_terrain()
    pair[0].queue_free()
    TestHelper.assert_eq(land_after, "clear", "land type re-resolved after frame advance")
    TestHelper.assert_eq(queries_after, 1, "cache cleared -> one fresh get_land_type call")


func test_avoidance_hood_fetched_once_per_unique_cell():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh.set_process(false)
    _sh.set_physics_process(false)
    _reset_terrain()
    var pair_a: Array = _make_mc(EntityData.EntityType.INFANTRY)
    var mc_a: MovementController = pair_a[1]
    var pair_b: Array = _make_mc(EntityData.EntityType.INFANTRY)
    var mc_b: MovementController = pair_b[1]
    var cell := CellUtil.world_to_cell(Vector3(0.5, 0.0, 0.5))
    var other_cell := cell + Vector2i(3, 0)
    # A cluster of units sharing the same cell fetches one 3×3 burst per unique
    # cell per frame — two units on `cell` cost 9 get_entries calls, not 18.
    _reset_frame_cache()
    _sh.perf_get_entries_calls = 0
    var hood_a: Array = mc_a._frame_hood(cell)
    var calls_after_first: int = _sh.perf_get_entries_calls
    var hood_b: Array = mc_b._frame_hood(cell)
    var calls_after_shared: int = _sh.perf_get_entries_calls
    # A distinct cell is a separate unique cell -> its own 3×3 burst.
    var hood_c: Array = mc_a._frame_hood(other_cell)
    var calls_after_other: int = _sh.perf_get_entries_calls
    pair_a[0].queue_free()
    pair_b[0].queue_free()
    _reset_terrain()
    TestHelper.assert_eq(hood_a.size(), 9, "hood holds 9 entry lists (the 3×3 neighborhood)")
    TestHelper.assert_eq(hood_b.size(), 9, "cached hood still holds 9 lists")
    TestHelper.assert_eq(hood_c.size(), 9, "second unique cell builds its own 9-list hood")
    TestHelper.assert_eq(
        calls_after_first, 9, "first unit fetches the cell's hood with one 3×3 burst"
    )
    (
        TestHelper
        . assert_eq(
            calls_after_shared,
            9,
            "second unit sharing the cell adds no get_entries calls (hood shared per cell)",
        )
    )
    (
        TestHelper
        . assert_eq(
            calls_after_other,
            18,
            "a distinct cell costs one more 3×3 burst (9 + 9 = 18 total)",
        )
    )


func test_memoized_normal_parity_with_get_normal_at_world():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _reset_terrain()
    var pair: Array = _make_mc(EntityData.EntityType.VEHICLE)
    var mc: MovementController = pair[1]
    # A sloped cell: four distinct corners.
    _ts._vertex_grid[50][50] = 3
    _ts._vertex_grid[51][50] = 0
    _ts._vertex_grid[50][51] = 0
    _ts._vertex_grid[51][51] = 3
    _ts.invalidate_height_snapshot()
    _reset_frame_cache()
    for pos: Vector3 in [
        Vector3(0.2, 0.0, 0.2),
        Vector3(0.7, 0.0, 0.6),
        Vector3(0.9, 0.0, 0.1),
    ]:
        var expected: Vector3 = _ts.get_normal_at_world(pos).normalized()
        _ts.invalidate_height_snapshot()
        var got: Vector3 = mc._memoized_normal(pos)
        TestHelper.assert_eq(
            got, expected, "memoized normal matches get_normal_at_world on a slope cell"
        )
    _reset_terrain()
    pair[0].queue_free()


## Regression (#284): the 3×3 hood caches live `SpatialHash._grid` arrays. When a
## crushed unit is freed, `SpatialHash.rebuild()` replaces those arrays; a cached
## hood left untouched would hold an entry whose node is freed, crashing the
## avoidance scan's `entry.node as Node3D` cast ("Trying to cast a freed object").
## The hood cache must invalidate on grid generation change and refetch.
func test_hood_invalidated_on_spatial_rebuild():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh.set_process(false)
    _sh.set_physics_process(false)
    _reset_terrain()
    var pair: Array = _make_mc(EntityData.EntityType.INFANTRY)
    var mc: MovementController = pair[1]
    var survivor_pair: Array = _make_mc(EntityData.EntityType.INFANTRY)
    var survivor_mc: MovementController = survivor_pair[1]
    var cell := CellUtil.world_to_cell(Vector3(0.5, 0.0, 0.5))
    var key: int = CellUtil.cell_key(cell)
    _sh._grid[key] = [{"node": pair[0], "mc": mc}]
    _reset_frame_cache()
    # The surviving controller's hood fetch is the probe: it must invalidate the
    # shared frame cache when the grid rebuilds.
    var hood_before: Array = survivor_mc._frame_hood(cell)
    var cached_center: Array = hood_before[4]
    # Simulate the crush death: the unit is freed, then SpatialHash rebuilds the
    # grid next physics step, replacing the arrays the hood cached.
    pair[0].free()
    _sh.rebuild()
    var hood_after: Array = survivor_mc._frame_hood(cell)
    var center_after: Array = hood_after[4]
    _sh._grid.clear()
    survivor_pair[0].queue_free()
    _reset_terrain()
    TestHelper.assert_eq(cached_center.size(), 1, "hood caches the seeded entry before rebuild")
    (
        TestHelper
        . assert_true(
            center_after.is_empty(),
            (
                "hood refetches after grid rebuild and drops the freed entry, "
                + "not a stale array referencing the freed node"
            ),
        )
    )
