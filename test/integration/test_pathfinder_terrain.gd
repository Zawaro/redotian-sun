extends Node

# Pathfinder + TerrainSystem integration tests

var _ts: Node = null
var _sh: Node = null
var _test_passed := 0
var _test_failed := 0


func test_find_path_returns_array():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(32, 32)
    var start := Vector3(1.0, 0.0, 1.0)
    var end := Vector3(5.0, 0.0, 5.0)
    var path: PackedVector3Array = Pathfinder.find_path(start, end)
    _ts.clear()
    (
        TestHelper
        . assert_true(
            path.size() > 0,
            "find_path returns %d waypoints: expected waypoints, got empty array" % path.size(),
        )
    )


func test_wheeled_detours_around_resource_cell():
    if _ts == null:
        _test_failed += 1
        print("    FAIL: TerrainSystem not injected")
        return
    _ts.init_grid(32, 32)
    var wheel := Locomotor.new()
    wheel.terrain_speeds = {"clear": 1.0, "resource": 0.5, "road": 1.25, "rough": 0.5}
    var start := Vector3(2.0, 0.0, 2.0)
    var end := Vector3(10.0, 0.0, 10.0)
    var mid_cell := CellUtil.world_to_cell(Vector3(6.0, 0.0, 6.0), _ts.grid_cells)
    SpatialHash.instance.register_resource_cell(mid_cell)
    var path: PackedVector3Array = Pathfinder.find_path(start, end, {}, wheel)
    SpatialHash.instance.unregister_resource_cell(mid_cell)
    var crossed_resource := false
    for wp in path:
        if CellUtil.world_to_cell(wp, _ts.grid_cells) == mid_cell:
            crossed_resource = true
            break
    _ts.clear()
    # Crossing costs 2.0×; a one-cell detour is cheaper, so wheeled routes around.
    if path.size() > 0 and not crossed_resource:
        _test_passed += 1
        print("    PASS: wheeled unit detours around resource cell (%d waypoints)" % path.size())
    else:
        _test_failed += 1
        print("    FAIL: crossed_resource=%s, size=%d" % [crossed_resource, path.size()])


func test_hover_crosses_resource_cell():
    if _ts == null:
        _test_failed += 1
        print("    FAIL: TerrainSystem not injected")
        return
    _ts.init_grid(32, 32)
    var hover := Locomotor.new()
    hover.terrain_speeds = {"clear": 1.0, "resource": 1.0}
    var start := Vector3(2.0, 0.0, 2.0)
    var end := Vector3(10.0, 0.0, 10.0)
    var mid_cell := CellUtil.world_to_cell(Vector3(6.0, 0.0, 6.0), _ts.grid_cells)
    SpatialHash.instance.register_resource_cell(mid_cell)
    var path: PackedVector3Array = Pathfinder.find_path(start, end, {}, hover)
    SpatialHash.instance.unregister_resource_cell(mid_cell)
    var crossed_resource := false
    for wp in path:
        if CellUtil.world_to_cell(wp, _ts.grid_cells) == mid_cell:
            crossed_resource = true
            break
    _ts.clear()
    # Hover takes no resource penalty (1.0), so the straight line crosses the cell.
    if path.size() > 0 and crossed_resource:
        _test_passed += 1
        print(
            "    PASS: hover unit crosses resource cell at no penalty (%d waypoints)" % path.size()
        )
    else:
        _test_failed += 1
        print("    FAIL: crossed_resource=%s, size=%d" % [crossed_resource, path.size()])


func test_foot_blocked_by_water():
    if _ts == null:
        _test_failed += 1
        print("    FAIL: TerrainSystem not injected")
        return
    _ts.init_grid(32, 32)
    # Water wall at grid-index x=19, z in 14..21 (gap at z>=22 so a route exists).
    for z in range(14, 22):
        _ts.set_land_type(Vector2i(19, z), "water")
    var foot := Locomotor.new()
    foot.terrain_speeds = {"clear": 1.0, "road": 1.11, "rough": 0.89}
    var start := Vector3(2.0, 0.0, 2.0)
    var end := Vector3(12.0, 0.0, 12.0)
    var path: PackedVector3Array = Pathfinder.find_path(start, end, {}, foot)
    var crossed_water := false
    for wp in path:
        var c := CellUtil.world_to_cell(wp, _ts.grid_cells)
        if _ts.get_land_type(c) == "water":
            crossed_water = true
            break
    for z in range(14, 22):
        _ts.set_land_type(Vector2i(19, z), "clear")
    _ts.clear()
    # Foot has no water speed -> water is impassable, the path routes around it.
    if path.size() > 0 and not crossed_water:
        _test_passed += 1
        print("    PASS: foot unit routes around impassable water (%d waypoints)" % path.size())
    else:
        _test_failed += 1
        print("    FAIL: crossed_water=%s, size=%d" % [crossed_water, path.size()])


func test_bib_cell_does_not_block_path():
    if _ts == null:
        _test_failed += 1
        print("    FAIL: TerrainSystem not injected")
        return
    _ts.init_grid(32, 32)
    var start := Vector3(2.0, 0.0, 2.0)
    var end := Vector3(10.0, 0.0, 10.0)
    var end_cell := CellUtil.world_to_cell(end, _ts.grid_cells)
    # Register a bib on a cell along the route; bibs must never block movement.
    var mid_cell := CellUtil.world_to_cell(Vector3(6.0, 0.0, 6.0), _ts.grid_cells)
    SpatialHash.instance.register_bib_cells([mid_cell])
    var with_bib: PackedVector3Array = Pathfinder.find_path(start, end)
    SpatialHash.instance._bib_cells.clear()
    var reached: bool = (
        with_bib.size() > 0
        and CellUtil.world_to_cell(with_bib[with_bib.size() - 1], _ts.grid_cells) == end_cell
    )
    _ts.clear()
    if reached:
        _test_passed += 1
        print("    PASS: bib cell does not block movement")
    else:
        _test_failed += 1
        print("    FAIL: reached=%s, size=%d" % [reached, with_bib.size()])


func test_find_path_empty_for_same_cell():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(32, 32)
    var pos := Vector3(3.0, 0.0, 3.0)
    var path: PackedVector3Array = Pathfinder.find_path(pos, pos)
    _ts.clear()
    (
        TestHelper
        . assert_true(
            path.size() == 0,
            "find_path returns empty for same cell: expected empty, got %d waypoints" % path.size(),
        )
    )


func test_bib_penalty_routes_around_when_detour_is_cheap():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _ts.init_grid(32, 32)
    # Two bib cells forming a 2-wide wall straight ahead of the direct line.
    # A one-cell detour around them is cheaper than crossing both at penalty 6.
    var bib_cells: Array[Vector2i] = [Vector2i(16, 15), Vector2i(16, 16)]
    _sh.register_bib_cells(bib_cells)
    var start_world := CellUtil.cell_to_world(Vector2i(14, 16))
    var end_world := CellUtil.cell_to_world(Vector2i(18, 16))
    var path: PackedVector3Array = Pathfinder.find_path(start_world, end_world)
    var crossed_bib: bool = false
    for waypoint: Vector3 in path:
        var cell := CellUtil.world_to_cell(waypoint)
        if _sh.is_bib_cell(cell):
            crossed_bib = true
            break
    _sh.unregister_bib_cells(bib_cells)
    _ts.clear()
    (
        TestHelper
        . assert_true(
            path.size() > 0 and not crossed_bib,
            (
                "path avoids bib cells when a cheaper detour exists: "
                + "crossed_bib=%s path=%s (should route around)" % [crossed_bib, path]
            ),
        )
    )


func test_bib_cell_still_reachable_as_destination():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _ts.init_grid(32, 32)
    var dock_cell := Vector2i(16, 16)
    _sh.register_bib_cells([dock_cell] as Array[Vector2i])
    var start_world := CellUtil.cell_to_world(Vector2i(13, 16))
    var end_world := CellUtil.cell_to_world(dock_cell)
    var path: PackedVector3Array = Pathfinder.find_path(start_world, end_world)
    var reached: bool = path.size() > 0
    var last_cell: Vector2i = (
        CellUtil.world_to_cell(path[path.size() - 1]) if reached else Vector2i.ZERO
    )
    _sh.unregister_bib_cells([dock_cell] as Array[Vector2i])
    _ts.clear()
    (
        TestHelper
        . assert_true(
            reached and last_cell == dock_cell,
            (
                "bib destination (dock pad) is reachable: "
                + "reached=%s last_cell=%s (should reach bib destination)" % [reached, last_cell]
            ),
        )
    )


func test_bib_no_penalty_without_rules():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    var ef: Node = Engine.get_main_loop().root.get_node_or_null("EntityFactory")
    if ef == null or not ef.has_method("get_global_rules"):
        TestHelper.fail("EntityFactory not available to exercise null-rules path")
        return
    var original: GlobalRules = ef.get_global_rules()
    ef.set_global_rules(null)
    _ts.init_grid(32, 32)
    var bib_cells: Array[Vector2i] = [Vector2i(16, 15), Vector2i(16, 16)]
    _sh.register_bib_cells(bib_cells)
    var start_world := CellUtil.cell_to_world(Vector2i(14, 16))
    var end_world := CellUtil.cell_to_world(Vector2i(18, 16))
    var path: PackedVector3Array = Pathfinder.find_path(start_world, end_world)
    # With no penalty, the straight line across the bib cells is cheapest.
    var straight_used: bool = false
    for waypoint: Vector3 in path:
        if _sh.is_bib_cell(CellUtil.world_to_cell(waypoint)):
            straight_used = true
            break
    _sh.unregister_bib_cells(bib_cells)
    _ts.clear()
    ef.set_global_rules(original)
    (
        TestHelper
        . assert_true(
            path.size() > 0 and straight_used,
            (
                "no rules → bib cells are not penalized (direct crossing used): "
                + "straight_used=%s path=%s (no-penalty should cross bib)" % [straight_used, path]
            ),
        )
    )


func test_bib_penalty_ignored_for_building_associated_move():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _ts.init_grid(32, 32)
    var bib_cells: Array[Vector2i] = [Vector2i(16, 15), Vector2i(16, 16)]
    _sh.register_bib_cells(bib_cells)
    var start_world := CellUtil.cell_to_world(Vector2i(14, 16))
    var end_world := CellUtil.cell_to_world(Vector2i(18, 16))
    # ignore_bib_penalty=true (exiting a factory / building-associated move) must
    # cross the bib pad directly, like the no-penalty case.
    var path: PackedVector3Array = Pathfinder.find_path(start_world, end_world, {}, null, true)
    var crossed_bib: bool = false
    for waypoint: Vector3 in path:
        if _sh.is_bib_cell(CellUtil.world_to_cell(waypoint)):
            crossed_bib = true
            break
    _sh.unregister_bib_cells(bib_cells)
    _ts.clear()
    (
        TestHelper
        . assert_true(
            path.size() > 0 and crossed_bib,
            (
                "ignore_bib_penalty → bib crossing allowed (exit move): "
                + "crossed_bib=%s path=%s (ignore_bib_penalty should cross)" % [crossed_bib, path]
            ),
        )
    )
