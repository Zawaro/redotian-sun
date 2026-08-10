extends Node

# MovementController terrain speed factor, hover float, hybrids, and slope probe

var _ts: Node = null


func _reset_terrain() -> void:
    if _ts:
        _ts.init_grid(50, 50)
        _ts.clear()


func _wheel() -> Locomotor:
    var wheel := Locomotor.new()
    wheel.terrain_speeds = {"clear": 1.0, "rough": 0.5, "road": 1.25}
    return wheel


func _subterranean() -> Locomotor:
    var sub := Locomotor.new()
    sub.terrain_speeds = {"clear": 1.0}
    sub.is_subterranean = true
    sub.subterranean_dig_distance = 0.0
    return sub


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


func test_terrain_speed_factor():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _reset_terrain()
    var pair: Array = _make_mc(EntityData.EntityType.VEHICLE)
    var mc: MovementController = pair[1]
    mc._locomotor_data = _wheel()
    _ts.set_land_type(Vector2i(50, 50), "rough")
    var factor: float = mc._terrain_speed_factor()
    _reset_terrain()
    pair[0].queue_free()
    TestHelper.assert_true(is_equal_approx(factor, 0.5), "wheel on rough -> 0.5 speed")


func test_amphibious_water_factor():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _reset_terrain()
    var pair: Array = _make_mc(EntityData.EntityType.VEHICLE)
    var mc: MovementController = pair[1]
    var amphibious := Locomotor.new()
    amphibious.terrain_speeds = {"clear": 1.0, "water": 0.6}
    mc._locomotor_data = amphibious
    _ts.set_land_type(Vector2i(50, 50), "water")
    var factor: float = mc._terrain_speed_factor()
    _reset_terrain()
    pair[0].queue_free()
    TestHelper.assert_true(is_equal_approx(factor, 0.6), "amphibious on water -> 0.6 speed")


func test_resource_cell_slows_movement():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _reset_terrain()
    var pair: Array = _make_mc(EntityData.EntityType.VEHICLE)
    var mc: MovementController = pair[1]
    var wheel := Locomotor.new()
    wheel.terrain_speeds = {"clear": 1.0, "resource": 0.5}
    mc._locomotor_data = wheel
    var cell := CellUtil.world_to_cell(Vector3.ZERO, _ts.grid_cells)
    SpatialHash.instance.register_resource_cell(cell)
    var factor: float = mc._terrain_speed_factor()
    SpatialHash.instance.unregister_resource_cell(cell)
    _reset_terrain()
    pair[0].queue_free()
    TestHelper.assert_true(is_equal_approx(factor, 0.5), "wheel on resource cell -> 0.5 speed")


func test_hover_floats_above_terrain():
    _reset_terrain()
    var root: Node = Engine.get_main_loop().root
    var pair: Array = _make_mc(EntityData.EntityType.VEHICLE)
    var entity: Node3D = pair[0]
    var mc: MovementController = pair[1]
    root.add_child(entity)
    entity.global_position = Vector3.ZERO
    mc._is_hover = true
    mc._hover_height = 2.0
    mc._snap_to_terrain()
    var y: float = entity.global_position.y
    root.remove_child(entity)
    entity.free()
    TestHelper.assert_true(y > 1.5, "hover unit floats ~2 units above terrain")


func test_ground_unit_snaps_to_terrain():
    _reset_terrain()
    var root: Node = Engine.get_main_loop().root
    var pair: Array = _make_mc(EntityData.EntityType.VEHICLE)
    var entity: Node3D = pair[0]
    var mc: MovementController = pair[1]
    root.add_child(entity)
    entity.global_position = Vector3(0.0, 5.0, 0.0)
    mc._snap_to_terrain()
    var y: float = entity.global_position.y
    root.remove_child(entity)
    entity.free()
    TestHelper.assert_true(y < 0.5, "ground unit snaps down to terrain")


func test_subterranean_distant_digs():
    _reset_terrain()
    var pair: Array = _make_mc(EntityData.EntityType.VEHICLE)
    var mc: MovementController = pair[1]
    var sub := _subterranean()
    sub.subterranean_dig_distance = 1.0
    mc._locomotor_data = sub
    mc._is_subterranean = true
    var target := CellUtil.cell_to_world(Vector2i(54, 50))
    mc.set_target_position(target)
    var hybrid: bool = mc._hybrid_active
    var waypoints: int = mc._waypoints.size()
    _reset_terrain()
    pair[0].queue_free()
    TestHelper.assert_eq(hybrid, true, "distant target triggers digging")
    TestHelper.assert_eq(waypoints, 2, "dig is a single straight segment")


func test_subterranean_nearby_stays_surface():
    _reset_terrain()
    var pair: Array = _make_mc(EntityData.EntityType.VEHICLE)
    var mc: MovementController = pair[1]
    mc._locomotor_data = _subterranean()
    mc._is_subterranean = true
    var target := CellUtil.cell_to_world(Vector2i(52, 50))
    mc.set_target_position(target)
    var hybrid: bool = mc._hybrid_active
    var waypoints: int = mc._waypoints.size()
    _reset_terrain()
    pair[0].queue_free()
    TestHelper.assert_eq(hybrid, false, "nearby reachable target stays on surface")
    TestHelper.assert_true(waypoints > 2, "surface path has intermediate waypoints")


func test_hybrid_reset_on_arrival():
    _reset_terrain()
    var pair: Array = _make_mc(EntityData.EntityType.VEHICLE)
    var mc: MovementController = pair[1]
    mc._hybrid_active = true
    mc._waypoints = [Vector3.ZERO, Vector3(0.0005, 0.0, 0.0)]
    mc._spline_t = 1.0
    mc._handle_moving_movement(0.016)
    var hybrid: bool = mc._hybrid_active
    var idle: bool = mc._state == MovementController.State.IDLE
    _reset_terrain()
    pair[0].queue_free()
    TestHelper.assert_eq(hybrid, false, "arrival resets hybrid flag")
    TestHelper.assert_true(idle, "arrival reaches IDLE")


func test_slope_probe_uphill():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _reset_terrain()
    var rules := GlobalRules.new()
    rules.tracked_uphill = 0.5
    rules.tracked_downhill = 1.1
    var pair: Array = _make_mc(EntityData.EntityType.VEHICLE)
    var mc: MovementController = pair[1]
    mc._rules = rules
    mc.locomotor = "Track"
    for v in [Vector2i(51, 50), Vector2i(52, 50), Vector2i(51, 51), Vector2i(52, 51)]:
        _ts._vertex_grid[v.x][v.y] = 3
    mc._waypoints = [Vector3.ZERO, CellUtil.cell_to_world(Vector2i(51, 50))]
    mc._spline_t = 0.0
    var coeff: float = mc._slope_coefficient()
    _reset_terrain()
    pair[0].queue_free()
    TestHelper.assert_true(is_equal_approx(coeff, 0.5), "tracked uphill -> 0.5")


func test_slope_probe_downhill():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _reset_terrain()
    var rules := GlobalRules.new()
    rules.tracked_uphill = 0.5
    rules.tracked_downhill = 1.1
    var pair: Array = _make_mc(EntityData.EntityType.VEHICLE)
    var mc: MovementController = pair[1]
    mc._rules = rules
    mc.locomotor = "Track"
    for v in [Vector2i(50, 50), Vector2i(50, 51)]:
        _ts._vertex_grid[v.x][v.y] = 3
    mc._waypoints = [Vector3.ZERO, CellUtil.cell_to_world(Vector2i(51, 50))]
    mc._spline_t = 0.0
    var coeff: float = mc._slope_coefficient()
    _reset_terrain()
    pair[0].queue_free()
    TestHelper.assert_true(is_equal_approx(coeff, 1.1), "tracked downhill -> 1.1")


func test_slope_probe_flat():
    _reset_terrain()
    var rules := GlobalRules.new()
    rules.tracked_uphill = 0.5
    rules.tracked_downhill = 1.1
    var pair: Array = _make_mc(EntityData.EntityType.VEHICLE)
    var mc: MovementController = pair[1]
    mc._rules = rules
    mc.locomotor = "Track"
    mc._waypoints = [Vector3.ZERO, CellUtil.cell_to_world(Vector2i(51, 50))]
    mc._spline_t = 0.0
    var coeff: float = mc._slope_coefficient()
    _reset_terrain()
    pair[0].queue_free()
    TestHelper.assert_true(is_equal_approx(coeff, 1.0), "flat segment -> no coefficient")


func test_frame_height_memo_matches_direct_read_on_slope():
    _reset_terrain()
    var pair: Array = _make_mc(EntityData.EntityType.VEHICLE)
    var mc: MovementController = pair[1]
    # Two unit positions in the same half-cell bucket on a sloped cell.
    var pos_a := Vector3(0.2, 0.0, 0.2)
    var pos_b := Vector3(0.7, 0.0, 0.6)
    _ts._vertex_grid[50][50] = 3
    _ts._vertex_grid[51][50] = 0
    _ts._vertex_grid[50][51] = 0
    _ts._vertex_grid[51][51] = 3
    _ts.invalidate_height_snapshot()
    var direct_a: float = _ts.get_height_at_world_smooth(pos_a)
    _ts.invalidate_height_snapshot()
    var memo_b: float = mc._memoized_smooth_height(pos_b)
    _ts.invalidate_height_snapshot()
    var direct_b: float = _ts.get_height_at_world_smooth(pos_b)
    _reset_terrain()
    pair[0].queue_free()
    var delta: float = absf(memo_b - direct_b)
    # Half-cell quantization: memo returns the bucket-center height, so it may
    # differ from the exact position read on a slope — but the error stays well
    # under a foot unit's climb tolerance (1 * HEIGHT_STEP).
    (
        TestHelper
        . assert_true(
            delta < _ts.HEIGHT_STEP,
            "frame memo bucket error stays under climb tolerance (delta %s)" % [delta],
        )
    )
    (
        TestHelper
        . assert_true(
            delta > 0.0,
            "slope cell produces a nonzero bucket delta (memo is not trivially identical)",
        )
    )


func test_frame_height_memo_caches_per_bucket():
    _reset_terrain()
    var pair: Array = _make_mc(EntityData.EntityType.VEHICLE)
    var mc: MovementController = pair[1]
    _ts._vertex_grid[50][50] = 3
    _ts._vertex_grid[51][50] = 3
    _ts._vertex_grid[50][51] = 3
    _ts._vertex_grid[51][51] = 3
    _ts.invalidate_height_snapshot()
    var h_a: float = mc._memoized_smooth_height(Vector3(0.2, 0.0, 0.2))
    _ts.invalidate_height_snapshot()
    var h_b: float = mc._memoized_smooth_height(Vector3(0.7, 0.0, 0.6))
    _reset_terrain()
    pair[0].queue_free()
    TestHelper.assert_eq(
        h_a, h_b, "same bucket returns the same memoized height (one terrain read per bucket)"
    )


func test_baked_spline_matches_spline_util():
    _reset_terrain()
    var pair: Array = _make_mc(EntityData.EntityType.VEHICLE)
    var mc: MovementController = pair[1]
    var waypoints := PackedVector3Array(
        [
            Vector3(0, 0, 0),
            Vector3(4, 0, 2),
            Vector3(8, 0, 5),
            Vector3(12, 0, 3),
        ]
    )
    mc._waypoints = waypoints
    mc._bake_spline()
    for t: float in [0.0, 0.25, 0.5, 1.0, 1.5, 2.0, 3.0]:
        var baked_pos: Vector3 = mc._get_spline_pos(t)
        var direct_pos: Vector3 = SplineUtil.evaluate(waypoints, t)
        TestHelper.assert_eq(
            baked_pos, direct_pos, "baked position matches SplineUtil at t=%s" % [t]
        )
        var baked_tangent: Vector3 = mc._get_spline_tangent(t)
        var direct_tangent: Vector3 = SplineUtil.tangent(waypoints, t)
        TestHelper.assert_eq(
            baked_tangent, direct_tangent, "baked tangent matches SplineUtil at t=%s" % [t]
        )
    var seg_len_0: float = mc._segment_length(0)
    TestHelper.assert_eq(
        seg_len_0, waypoints[0].distance_to(waypoints[1]), "baked seg length matches"
    )
    _reset_terrain()
    pair[0].queue_free()
