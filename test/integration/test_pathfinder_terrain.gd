extends Node

# Pathfinder + TerrainSystem integration tests

var _ts: Node = null
var _sh: Node = null


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
