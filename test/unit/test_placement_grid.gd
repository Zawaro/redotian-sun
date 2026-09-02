extends Node

# PlacementGridOverlay + white-region rule tests (#352)

var _bm: Node = null


func _make_friendly_entry(cells: Array, foundation: Vector2i = Vector2i(1, 1)) -> Dictionary:
    var node := Node3D.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = PlayerManager.get_local_player_id()
    node.add_child(stats)
    var data := EntityData.new()
    data.foundation = foundation
    # Stored cells mirror place_building: non-bib occupied cells only.
    return {"node": node, "type": data, "origin": cells[0], "cells": cells}


func _with_buildings(entries: Array, check: Callable) -> void:
    var saved: Array = _bm._buildings.duplicate()
    _bm._buildings.clear()
    for entry in entries:
        _bm._buildings.append(entry)
    check.call()
    _bm._buildings.assign(saved)
    for entry in entries:
        (entry["node"] as Node3D).free()


func _make_ghost(foundation: Vector2i, adjacent: int) -> EntityData:
    var data := EntityData.new()
    data.foundation = foundation
    data.adjacent = adjacent
    return data


func test_white_region_known_example_dilation() -> void:
    if _bm == null:
        TestHelper.fail("BuildingManager not injected")
        return
    # Friendly 2x2 at (3,3)-(4,4); ghost 3x2, adjacent=1.
    # Radii: (1 + 3, 1 + 2) = (4, 3) around each friendly cell -> rect
    # x in [-1, 8], z in [0, 7], i.e. 80 cells.
    var ghost := _make_ghost(Vector2i(3, 2), 1)
    var entry := _make_friendly_entry(
        [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)], Vector2i(2, 2)
    )
    _with_buildings(
        [entry],
        func() -> void:
            var white: Dictionary = _bm._adjacent_reachable_cells(ghost)
            TestHelper.assert_eq(white.size(), 80, "white region is the dilated 10x8 rect")
            TestHelper.assert_true(white.has(Vector2i(-1, 3)), "left edge inside")
            TestHelper.assert_true(white.has(Vector2i(8, 4)), "right edge inside")
            TestHelper.assert_true(white.has(Vector2i(8, 7)), "far corner inside")
            TestHelper.assert_true(white.has(Vector2i(3, 3)), "building cell itself inside")
            TestHelper.assert_true(not white.has(Vector2i(-2, 3)), "one past left edge outside")
            TestHelper.assert_true(not white.has(Vector2i(9, 4)), "one past right edge outside")
            TestHelper.assert_true(not white.has(Vector2i(8, 8)), "one past far corner outside")
            TestHelper.assert_true(not white.has(Vector2i(-1, -1)), "one past near corner outside")
    )


func test_white_region_adjacent_zero_means_touching() -> void:
    if _bm == null:
        TestHelper.fail("BuildingManager not injected")
        return
    # Friendly 1x1 at (5,5); ghost 3x2, adjacent=0 -> radii (3, 2):
    # x in [2, 8], z in [3, 7]. A placement one gap further out (x=9) is outside.
    var ghost := _make_ghost(Vector2i(3, 2), 0)
    var entry := _make_friendly_entry([Vector2i(5, 5)])
    _with_buildings(
        [entry],
        func() -> void:
            var white: Dictionary = _bm._adjacent_reachable_cells(ghost)
            TestHelper.assert_eq(white.size(), 35, "white region is the 7x5 rect")
            TestHelper.assert_true(white.has(Vector2i(8, 5)), "touching far edge inside")
            TestHelper.assert_true(not white.has(Vector2i(9, 5)), "one gap further out outside")
            TestHelper.assert_true(not white.has(Vector2i(2, 2)), "one past z edge outside")
    )


func test_negative_adjacent_clamps_to_zero() -> void:
    if _bm == null:
        TestHelper.fail("BuildingManager not injected")
        return
    var clamped := _make_ghost(Vector2i(3, 2), -1)
    var zero := _make_ghost(Vector2i(3, 2), 0)
    var entry := _make_friendly_entry([Vector2i(5, 5)])
    _with_buildings(
        [entry],
        func() -> void:
            var from_negative: Dictionary = _bm._adjacent_reachable_cells(clamped)
            var from_zero: Dictionary = _bm._adjacent_reachable_cells(zero)
            TestHelper.assert_eq(from_negative, from_zero, "adjacent=-1 behaves exactly as 0")
    )


func test_ghost_adjacent_governs_not_friendly_buildings() -> void:
    if _bm == null:
        TestHelper.fail("BuildingManager not injected")
        return
    # Entry types carry adjacent=7 — must be ignored; the ghost's value rules.
    var ghost_1 := _make_ghost(Vector2i(2, 2), 1)
    var ghost_2 := _make_ghost(Vector2i(2, 2), 2)
    var entry := _make_friendly_entry([Vector2i(10, 10)])
    (entry["type"] as EntityData).adjacent = 7
    _with_buildings(
        [entry],
        func() -> void:
            var white_1: Dictionary = _bm._adjacent_reachable_cells(ghost_1)
            var white_2: Dictionary = _bm._adjacent_reachable_cells(ghost_2)
            TestHelper.assert_eq(white_1.size(), 49, "ghost adjacent=1 -> radii (3,3): 7x7 rect")
            TestHelper.assert_eq(white_2.size(), 81, "ghost adjacent=2 -> radii (4,4): 9x9 rect")
            TestHelper.assert_true(
                white_2.has(Vector2i(10 - 4, 10)), "adjacent=2 reaches one further"
            )
            TestHelper.assert_true(not white_1.has(Vector2i(10 - 4, 10)), "adjacent=1 does not")
    )


func test_validator_acceptance_implies_footprint_inside_white() -> void:
    if _bm == null:
        TestHelper.fail("BuildingManager not injected")
        return
    # For every sampled origin: if the validator accepts the placement, every
    # footprint cell must lie in the white region (#352 display/validator agree).
    var ghost := _make_ghost(Vector2i(2, 2), 1)
    var entry := _make_friendly_entry(
        [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)], Vector2i(2, 2)
    )
    _with_buildings(
        [entry],
        func() -> void:
            var white: Dictionary = _bm._adjacent_reachable_cells(ghost)
            var mismatches := 0
            for x in range(-4, 12):
                for z in range(-4, 12):
                    var origin := Vector2i(x, z)
                    var accepted: bool = _bm._is_adjacency_satisfied(ghost, origin)
                    if not accepted:
                        continue
                    for fc in FoundationComponent.footprint_cells(ghost.foundation, origin):
                        if not white.has(fc):
                            mismatches += 1
            TestHelper.assert_true(mismatches == 0, "accepted placements always inside white")
            var accepted_count := 0
            for x in range(-4, 12):
                for z in range(-4, 12):
                    if _bm._is_adjacency_satisfied(ghost, Vector2i(x, z)):
                        accepted_count += 1
            TestHelper.assert_true(
                accepted_count > 0, "sanity: sweep reaches at least one accepted origin"
            )
    )


func test_white_cells_filtered_to_map_bounds() -> void:
    if _bm == null:
        TestHelper.fail("BuildingManager not injected")
        return
    TerrainSystem.init_grid(64, 64)
    var ghost := _make_ghost(Vector2i(2, 2), 1)
    # Playable diamond for a 64x64 grid is centered near (63, 63); a building
    # near its edge produces white cells that fall outside the diamond.
    var entry := _make_friendly_entry(
        [Vector2i(63, 3), Vector2i(64, 3), Vector2i(63, 4), Vector2i(64, 4)], Vector2i(2, 2)
    )
    _with_buildings(
        [entry],
        func() -> void:
            var all_cells: Dictionary = _bm._adjacent_reachable_cells(ghost)
            var bounded: Array[Vector2i] = _bm._white_cells_in_bounds(ghost)
            TestHelper.assert_true(bounded.size() < all_cells.size(), "out-of-bounds cells dropped")
            var all_in_bounds := true
            for cell in bounded:
                if not BoundsSystem.is_in_map_bounds(cell):
                    all_in_bounds = false
            TestHelper.assert_true(all_in_bounds, "every returned cell is in map bounds")
            TestHelper.assert_true(
                bounded.has(Vector2i(63, 3)), "sanity: friendly building cell stays in white"
            )
    )


func test_bib_cells_extend_friendly_foundation_dilation() -> void:
    if _bm == null:
        TestHelper.fail("BuildingManager not injected")
        return
    # Refinery-style: 3x3 foundation at (5,5)-(7,7) with the bottom row as bib
    # cells. place_building stores only non-bib cells in the registry, but the
    # bib strip is part of the foundation: it must dilate the white region and
    # satisfy adjacency like any other foundation cell.
    var ghost := _make_ghost(Vector2i(1, 1), 1)
    var entry := _make_friendly_entry(
        [
            Vector2i(5, 5),
            Vector2i(6, 5),
            Vector2i(7, 5),
            Vector2i(5, 6),
            Vector2i(6, 6),
            Vector2i(7, 6)
        ],
        Vector2i(3, 3)
    )
    _with_buildings(
        [entry],
        func() -> void:
            var white: Dictionary = _bm._adjacent_reachable_cells(ghost)
            (
                TestHelper
                . assert_true(
                    white.has(Vector2i(6, 9)),
                    "cell past the bib strip is white (reachable only via bib dilation)",
                )
            )
            TestHelper.assert_true(
                white.has(Vector2i(6, 7)), "bib cell itself is part of the white foundation"
            )
            (
                TestHelper
                . assert_true(
                    _bm._is_adjacency_satisfied(ghost, Vector2i(6, 9)),
                    "ghost touching only the bib strip satisfies adjacency",
                )
            )
            TestHelper.assert_true(
                not white.has(Vector2i(6, 10)), "one past the bib dilation radius is outside"
            )
    )


func test_friendly_cells_exclude_stats_less_buildings() -> void:
    if _bm == null:
        TestHelper.fail("BuildingManager not injected")
        return
    var ghost := _make_ghost(Vector2i(2, 2), 1)
    var node := Node3D.new()  # no StatsComponent -> not friendly
    var saved: Array = _bm._buildings.duplicate()
    _bm._buildings.clear()
    _bm._buildings.append(
        {
            "node": node,
            "type": EntityData.new(),
            "origin": Vector2i(5, 5),
            "cells": [Vector2i(5, 5)]
        }
    )
    var cells: Array[Vector2i] = _bm._friendly_building_cells()
    var white: Dictionary = _bm._adjacent_reachable_cells(ghost)
    _bm._buildings.assign(saved)
    node.free()
    TestHelper.assert_true(cells.is_empty(), "stats-less building contributes no cells")
    TestHelper.assert_true(white.is_empty(), "white region empty without friendly buildings")


func test_octagon_mesh_geometry() -> void:
    var overlay := PlacementGridOverlay.new()
    var mesh := overlay._build_cell_mesh()
    TestHelper.assert_true(mesh != null, "cell mesh built")
    var arrays := mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    TestHelper.assert_eq(vertices.size(), 24, "8-gon triangle fan = 24 vertices")
    var half := CellUtil.CELL_SIZE * PlacementGridOverlay.CELL_COVERAGE * 0.5
    var cut := CellUtil.CELL_SIZE * PlacementGridOverlay.CORNER_CHAMFER
    var max_abs := 0.0
    var corners_cut := true
    var flat := true
    for v in vertices:
        max_abs = maxf(max_abs, absf(v.x))
        max_abs = maxf(max_abs, absf(v.z))
        if absf(v.y) > 0.0001:
            flat = false
        if absf(v.x) > half - 0.0001 and absf(v.z) > half - cut + 0.0001:
            corners_cut = false
        if absf(v.z) > half - 0.0001 and absf(v.x) > half - cut + 0.0001:
            corners_cut = false
    TestHelper.assert_true(flat, "shared mesh is flat at local y=0")
    TestHelper.assert_true(corners_cut, "no square corners: extremes are chamfered")
    TestHelper.assert_true(absf(max_abs - half) < 0.0001, "footprint spans 95% of cell size")


func test_plane_y_uses_max_corner_height_plus_offset() -> void:
    TerrainSystem.init_grid(8, 8)
    var overlay := PlacementGridOverlay.new()
    var flat_cell := Vector2i(4, 4)
    (
        TestHelper
        . assert_eq(
            overlay._cell_plane_y(flat_cell),
            PlacementGridOverlay.PLANE_Y_OFFSET,
            "flat terrain -> plane sits at the configured offset",
        )
    )
    # Cell (4,4) corners are vertices (4..5, 4..5); raise one via the public API.
    TerrainSystem.set_vertex(5, 5, 2)
    var expected: float = 2.0 * TerrainSystem.HEIGHT_STEP + PlacementGridOverlay.PLANE_Y_OFFSET
    (
        TestHelper
        . assert_eq(
            overlay._cell_plane_y(flat_cell),
            expected,
            "raised corner -> plane sits at max corner height + offset",
        )
    )


func test_rebuild_defers_rendering_until_cursor() -> void:
    # Regression: set_white_cells before the first set_cursor must not render
    # the full white set (avoided a one-frame red/white flash on build-mode
    # entry while the mouse ray hasn't resolved yet).
    var overlay := PlacementGridOverlay.new()
    _bm.add_child(overlay)
    overlay.set_white_cells([Vector2i(0, 0), Vector2i(1, 0)])
    TestHelper.assert_eq(
        overlay._multimesh.instance_count, 0, "no cursor yet -> multimesh stays empty"
    )
    overlay.set_cursor(Vector2i(0, 0), Vector2i(1, 1))
    TestHelper.assert_true(overlay._multimesh.instance_count > 0, "cursor arrival -> cells render")
    _bm.remove_child(overlay)
    overlay.free()


func test_compute_cell_colors_assignment() -> void:
    var overlay := PlacementGridOverlay.new()
    var states := {
        Vector2i(0, 0): PlacementGridOverlay.CellState.FREE,
        Vector2i(1, 0): PlacementGridOverlay.CellState.BLOCKED,
        Vector2i(2, 0): PlacementGridOverlay.CellState.HIDDEN,
        Vector2i(5, 5): PlacementGridOverlay.CellState.BLOCKED,
    }
    overlay.cell_state_resolver = func(cell: Vector2i) -> int:
        return states.get(cell, PlacementGridOverlay.CellState.FREE)
    overlay.set_white_cells([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(5, 5)])
    var colors: Dictionary = overlay.compute_cell_colors()
    TestHelper.assert_eq(
        colors.get(Vector2i(0, 0)), PlacementGridOverlay.WHITE_COLOR, "free white cell stays white"
    )
    TestHelper.assert_eq(
        colors.get(Vector2i(1, 0)), PlacementGridOverlay.RED_COLOR, "blocked white cell shows red"
    )
    TestHelper.assert_true(not colors.has(Vector2i(2, 0)), "hidden cells never render")

    overlay.set_cursor(Vector2i(0, 0), Vector2i(2, 2))
    colors = overlay.compute_cell_colors()
    TestHelper.assert_eq(
        colors.get(Vector2i(0, 0)), PlacementGridOverlay.GREEN_COLOR, "free cursor cell shows green"
    )
    (
        TestHelper
        . assert_eq(
            colors.get(Vector2i(1, 0)),
            PlacementGridOverlay.RED_COLOR,
            "blocked cursor cell shows red",
        )
    )
    TestHelper.assert_eq(
        colors.get(Vector2i(0, 1)), PlacementGridOverlay.GREEN_COLOR, "second footprint row green"
    )
    # (5,5) is a white cell but outside the cursor-anchored window.
    TestHelper.assert_true(
        not colors.has(Vector2i(5, 5)), "white cells beyond the window radius do not render"
    )

    # The window follows the cursor: near it, white cells appear (but cells
    # under the cursor still color green/red).
    overlay.set_white_cells(
        [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(5, 5), Vector2i(12, 10)]
    )
    overlay.set_cursor(Vector2i(9, 9), Vector2i(2, 2))
    colors = overlay.compute_cell_colors()
    (
        TestHelper
        . assert_eq(
            colors.get(Vector2i(12, 10)),
            PlacementGridOverlay.WHITE_COLOR,
            "white cell inside the moved window renders",
        )
    )
    TestHelper.assert_true(
        not colors.has(Vector2i(0, 0)), "white cell left behind the window disappears"
    )

    # Cursor wins over white on overlap.
    overlay.set_cursor(Vector2i(0, 0), Vector2i(1, 1))
    overlay.set_white_cells([Vector2i(0, 0)])
    colors = overlay.compute_cell_colors()
    TestHelper.assert_eq(
        colors.get(Vector2i(0, 0)), PlacementGridOverlay.GREEN_COLOR, "cursor overrides white"
    )

    overlay.clear()
    TestHelper.assert_true(overlay.compute_cell_colors().is_empty(), "clear empties the overlay")


func test_outside_white_cursor_cells_turn_red_for_adjacent_ghosts() -> void:
    var overlay := PlacementGridOverlay.new()
    overlay.cell_state_resolver = func(_cell: Vector2i) -> int:
        return PlacementGridOverlay.CellState.FREE
    overlay.set_white_cells([Vector2i(0, 0)])
    # Ghost with an adjacency constraint: free cells beyond the white region block.
    overlay.set_cursor(Vector2i(0, 0), Vector2i(2, 1), true)
    var colors: Dictionary = overlay.compute_cell_colors()
    TestHelper.assert_eq(
        colors.get(Vector2i(0, 0)), PlacementGridOverlay.GREEN_COLOR, "in-white ghost cell green"
    )
    TestHelper.assert_eq(
        colors.get(Vector2i(1, 0)), PlacementGridOverlay.RED_COLOR, "out-of-white ghost cell red"
    )
    # Unconstrained ghost keeps the plain free/blocked coloring.
    overlay.set_cursor(Vector2i(0, 0), Vector2i(2, 1), false)
    colors = overlay.compute_cell_colors()
    (
        TestHelper
        . assert_eq(
            colors.get(Vector2i(1, 0)),
            PlacementGridOverlay.GREEN_COLOR,
            "unconstrained ghost ignores white membership",
        )
    )
