extends Node

# TerrainSystem.mouse_ray_to_terrain tests (sidebar-ui-thinning, mouse-ground-picking spec).
# Expected values are derived from the camera geometry and the terrain fixture,
# never from the routine under test: a straight-down camera's center ray hits
# the ground exactly under the camera; the surface height at that point is
# queried from the pre-built fixture BEFORE the ray is cast.

var _ts: Node = null
var _sh: Node = null


func _make_camera(eye: Vector3, look_at_point: Vector3) -> Camera3D:
    var cam := Camera3D.new()
    (Engine.get_main_loop() as SceneTree).root.add_child(cam)
    # Straight-down orientations are degenerate with the default UP vector;
    # pick a perpendicular up so look_at produces a well-defined basis.
    var dir: Vector3 = (look_at_point - eye).normalized()
    var up: Vector3 = Vector3(0.0, 0.0, -1.0) if absf(dir.dot(Vector3.UP)) > 0.999 else Vector3.UP
    cam.look_at_from_position(eye, look_at_point, up)
    return cam


func _drop_camera(cam: Camera3D) -> void:
    if cam and is_instance_valid(cam):
        cam.free()


func _screen_center(cam: Camera3D) -> Vector2:
    return (cam.get_viewport().get_visible_rect().size as Vector2) * 0.5


func test_flat_terrain_returns_ground_hit_under_camera() -> void:
    if not _ts:
        TestHelper.fail("TerrainSystem not injected")
        return
    var eye := Vector3(5.0, 20.0, 5.0)
    var cam := _make_camera(eye, Vector3(5.0, 0.0, 5.0))
    # Known example: a straight-down camera's center ray crosses the ground
    # exactly below the eye; refinement moves only along Y (adjusted planes
    # are parallel), so the hit xz stays under the eye at whatever height the
    # shared grid holds at that point. Expected height comes from the fixture
    # oracle, queried before the ray is cast.
    var expected_y: float = _ts.get_height_at_world_smooth(Vector3(eye.x, 0.0, eye.z))
    var got: Variant = _ts.mouse_ray_to_terrain(cam, _screen_center(cam))
    TestHelper.assert_true(got != null, "downward ray over terrain hits the ground")
    if got == null:
        _drop_camera(cam)
        return
    var hit := got as Vector3
    TestHelper.assert_true(absf(hit.x - eye.x) < 0.01, "hit x sits under the eye")
    TestHelper.assert_true(absf(hit.z - eye.z) < 0.01, "hit z sits under the eye")
    TestHelper.assert_true(
        absf(hit.y - expected_y) < 0.01,
        "hit rests on the surface (expected %.3f, got %.3f)" % [expected_y, hit.y]
    )
    _drop_camera(cam)


func test_ray_missing_ground_returns_null() -> void:
    if not _ts:
        TestHelper.fail("TerrainSystem not injected")
        return
    var cam := _make_camera(Vector3(5.0, 2.0, 5.0), Vector3(5.0, 30.0, 5.0))
    var got: Variant = _ts.mouse_ray_to_terrain(cam, _screen_center(cam))
    TestHelper.assert_true(got == null, "upward-pointing ray misses the ground plane")
    _drop_camera(cam)


func test_refinement_rises_to_raised_terrain() -> void:
    if not _ts:
        TestHelper.fail("TerrainSystem not injected")
        return
    var aim := Vector3(2.0, 0.0, 2.0)
    var cell := CellUtil.world_to_cell(aim)
    _ts.raise_cell(cell)
    # Fixture-derived expectation: the smoothed surface height at the aim
    # point AFTER raising, computed before any ray is cast.
    var expected_y: float = _ts.get_height_at_world_smooth(aim)
    TestHelper.assert_true(
        expected_y > 0.1, "fixture sanity: raised cell lifts the surface at the aim point"
    )
    var cam := _make_camera(Vector3(aim.x, 20.0, aim.z), aim)
    var got: Variant = _ts.mouse_ray_to_terrain(cam, _screen_center(cam))
    TestHelper.assert_true(got != null, "downward ray over raised terrain hits the surface")
    if got == null:
        _ts.lower_cell(cell)
        _drop_camera(cam)
        return
    var hit := got as Vector3
    TestHelper.assert_true(
        absf(hit.y - expected_y) < 0.05,
        "hit lands on the raised surface (expected %.3f, got %.3f)" % [expected_y, hit.y]
    )
    TestHelper.assert_true(
        absf(hit.x - aim.x) < 0.01 and absf(hit.z - aim.z) < 0.01,
        "hit xz stays under the straight-down eye"
    )
    _ts.lower_cell(cell)
    _drop_camera(cam)


func test_oblique_ray_stays_on_surface() -> void:
    if not _ts:
        TestHelper.fail("TerrainSystem not injected")
        return
    # Property test on shared (possibly non-flat) grid state: the center ray of
    # a camera looking at a ground point stays collinear with that ray after
    # refinement, and the returned hit sits on the sampled surface (fixed
    # point of the refinement) — regardless of the terrain shape beneath.
    var target := Vector3(3.0, 0.0, 7.0)
    var eye := Vector3(3.0, 15.0, 3.0)
    var cam := _make_camera(eye, target)
    var expected_dir: Vector3 = (target - eye).normalized()
    var got: Variant = _ts.mouse_ray_to_terrain(cam, _screen_center(cam))
    TestHelper.assert_true(got != null, "oblique ray over terrain hits the ground")
    if got == null:
        _drop_camera(cam)
        return
    var hit := got as Vector3
    var hit_dir: Vector3 = (hit - eye).normalized()
    TestHelper.assert_true(
        hit_dir.dot(expected_dir) > 0.9999, "refined hit stays on the original camera ray"
    )
    TestHelper.assert_true(
        absf(hit.y - _ts.get_height_at_world_smooth(hit)) < 0.05,
        "hit rests on the sampled surface (fixed point of refinement)"
    )
    _drop_camera(cam)


func test_deck_pick_resolves_level_and_ground() -> void:
    if not _ts or not _sh:
        TestHelper.fail("TerrainSystem/SpatialHash not injected")
        return
    var cell := CellUtil.world_to_cell(Vector3(5.0, 0.0, 5.0))
    for vx in [cell.x, cell.x + 1]:
        for vz in [cell.y, cell.y + 1]:
            _ts._vertex_grid[vx][vz] = 0
    _ts.invalidate_height_snapshot()
    var ground_y: float = _ts.get_height_at_world_smooth(Vector3(5.0, 0.0, 5.0))
    var deck_y: float = ground_y + 4.0 * _ts.HEIGHT_STEP
    _sh._bridge_cells[CellUtil.cell_level_key(cell, 1)] = {
        "surface_height": deck_y,
        "is_end": false,
        "piece_id": "piece_pick",
        "level": 1,
    }
    var eye := Vector3(5.0, 20.0, 5.0)
    var cam := _make_camera(eye, Vector3(5.0, 0.0, 5.0))
    var candidates: Array[Dictionary] = _ts.mouse_ray_to_terrain_candidates(
        cam, _screen_center(cam)
    )

    TestHelper.assert_true(candidates.size() >= 2, "deck pick reports both surfaces")
    if candidates.size() >= 2:
        TestHelper.assert_eq(int(candidates[0]["level"]), 1, "nearest surface is the deck")
        TestHelper.assert_true(
            absf((candidates[0]["position"] as Vector3).y - deck_y) < 0.05,
            "deck candidate sits at the deck height"
        )
        TestHelper.assert_eq(int(candidates[1]["level"]), 0, "ground beneath is offered too")
        TestHelper.assert_true(
            absf((candidates[1]["position"] as Vector3).y - ground_y) < 0.05,
            "ground candidate sits at the ground height"
        )
    # The single-return API keeps returning the nearest surface (the deck).
    var nearest: Variant = _ts.mouse_ray_to_terrain(cam, _screen_center(cam))
    _sh._bridge_cells.erase(CellUtil.cell_level_key(cell, 1))
    TestHelper.assert_true(nearest != null, "single-return pick hits the deck")
    if nearest != null:
        TestHelper.assert_true(
            absf((nearest as Vector3).y - deck_y) < 0.05,
            "single-return pick defaults to the nearest surface (the deck)"
        )
    _drop_camera(cam)
