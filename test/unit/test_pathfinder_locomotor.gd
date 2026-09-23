extends Node

# Pathfinder per-locomotor passability, cost, climb tolerance, and ice carve-out

var _ts: Node = null
var _sh: Node = null


func _reset_terrain() -> void:
    if _ts:
        _ts.init_grid(50, 50)
        _ts.clear()


func _wheel() -> Locomotor:
    var wheel := Locomotor.new()
    wheel.terrain_speeds = {"clear": 1.0, "rough": 0.5, "road": 1.25, "bridge": 1.25}
    wheel.climb_tolerance = 1
    return wheel


func _hover() -> Locomotor:
    var hover := Locomotor.new()
    hover.is_hover = true
    hover.climb_tolerance = 99
    return hover


func _fly() -> Locomotor:
    var fly := Locomotor.new()
    fly.is_fly = true
    return fly


func _foot() -> Locomotor:
    var foot := Locomotor.new()
    foot.terrain_speeds = {"clear": 1.0, "bridge": 1.0}
    foot.climb_tolerance = 1
    return foot


## Locomotor data that declares a Road row but no Bridge row: only the deck
## Road-row rule lets it use a deck over water.
func _road_only() -> Locomotor:
    var road := Locomotor.new()
    road.terrain_speeds = {"clear": 1.0, "road": 1.25}
    road.climb_tolerance = 1
    return road


## Locomotor data that declares neither a Road nor a Bridge row: a deck is refused.
func _no_deck_rows() -> Locomotor:
    var plain := Locomotor.new()
    plain.terrain_speeds = {"clear": 1.0}
    plain.climb_tolerance = 1
    return plain


## Injects a live level-1 bridge registry entry directly (the rebuild group scan
## is exercised by test_bridge_registry / test_bridge_component).
func _register_bridge(
    cell: Vector2i, surface_height: float, is_end: bool = false, piece_id: String = "piece_test"
) -> void:
    _sh._bridge_cells[CellUtil.cell_level_key(cell, 1)] = {
        "surface_height": surface_height,
        "is_end": is_end,
        "piece_id": piece_id,
        "level": 1,
    }


func _unregister_bridge(cell: Vector2i) -> void:
    _sh._bridge_cells.erase(CellUtil.cell_level_key(cell, 1))


func _path_cells(path: PackedVector3Array) -> Array:
    var cells: Array = []
    for wp in path:
        cells.append(CellUtil.world_to_cell(wp))
    return cells


## Directly raises a 2x2 vertex block (bypasses the cascade, simulating an
## imported map cliff) and populates the affected cell data.
func _raise_cliff() -> void:
    for v in [Vector2i(50, 50), Vector2i(51, 50), Vector2i(50, 51), Vector2i(51, 51)]:
        _ts._vertex_grid[v.x][v.y] = 3
    for cx in range(48, 54):
        for cz in range(48, 54):
            _ts.compute_and_emit_cell(Vector2i(cx, cz))


## Raises a 3-level wall spanning the whole grid height, so no flat route around
## exists and only fly/jumpjet can cross.
func _raise_wall() -> void:
    for z in range(0, 100):
        for vx in [50, 51]:
            for vz in [z, z + 1]:
                _ts._vertex_grid[vx][vz] = 3
    for cx in range(48, 54):
        for cz in range(48, 54):
            _ts.compute_and_emit_cell(Vector2i(cx, cz))


## Raises a full-width wall of the given vertex height spanning the whole grid.
func _raise_step(height: int) -> void:
    for z in range(0, 100):
        for vx in [50, 51]:
            for vz in [z, z + 1]:
                _ts._vertex_grid[vx][vz] = height
    for cx in range(48, 54):
        for cz in range(48, 54):
            _ts.compute_and_emit_cell(Vector2i(cx, cz))


func test_cost_multiplier_formula():
    var wheel := _wheel()
    (
        TestHelper
        . assert_true(
            is_equal_approx(Pathfinder._cost_multiplier(wheel, "rough", Vector2i.ZERO), 2.0),
            "rough 0.5 -> cost 2.0",
        )
    )
    (
        TestHelper
        . assert_true(
            is_equal_approx(Pathfinder._cost_multiplier(wheel, "road", Vector2i.ZERO), 0.8),
            "road 1.25 -> cost 0.8",
        )
    )
    (
        TestHelper
        . assert_true(
            is_equal_approx(Pathfinder._cost_multiplier(wheel, "clear", Vector2i.ZERO), 1.0),
            "clear 1.0 -> cost 1.0",
        )
    )


func test_passability_static():
    var wheel := _wheel()
    TestHelper.assert_true(
        Pathfinder._is_terrain_passable(wheel, "clear", Vector2i.ZERO), "clear passable"
    )
    (
        TestHelper
        . assert_eq(
            Pathfinder._is_terrain_passable(wheel, "water", Vector2i.ZERO),
            false,
            "water absent from table -> impassable",
        )
    )
    var hover := _hover()
    TestHelper.assert_true(
        Pathfinder._is_terrain_passable(hover, "water", Vector2i.ZERO), "hover passes water"
    )


func test_wheeled_blocked_by_water():
    if _ts == null or _sh == null:
        TestHelper.fail("autoloads not injected")
        return
    _reset_terrain()
    var water_cell := Vector2i(50, 50)
    _ts.set_land_type(water_cell, "water")
    var start := CellUtil.cell_to_world(Vector2i(49, 50))
    var end := CellUtil.cell_to_world(Vector2i(51, 50))
    var path := Pathfinder.find_path(start, end, {}, _wheel())
    var avoids_water := not _path_cells(path).has(water_cell)
    _reset_terrain()
    TestHelper.assert_true(avoids_water, "wheeled path avoids water cell")


func test_hover_crosses_water():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _reset_terrain()
    var water_cell := Vector2i(50, 50)
    _ts.set_land_type(water_cell, "water")
    var start := CellUtil.cell_to_world(Vector2i(49, 50))
    var end := CellUtil.cell_to_world(Vector2i(51, 50))
    var path := Pathfinder.find_path(start, end, {}, _hover())
    var crosses := _path_cells(path).has(water_cell)
    _reset_terrain()
    TestHelper.assert_true(crosses, "hover path crosses water cell")


func test_ice_provides_footing_on_water():
    if _ts == null or _sh == null:
        TestHelper.fail("autoloads not injected")
        return
    _reset_terrain()
    var water_cell := Vector2i(50, 50)
    _ts.set_land_type(water_cell, "water")
    var ice := Node3D.new()
    var ice_hc := HealthComponent.new()
    ice_hc.name = "HealthComponent"
    ice_hc.max_health = 50
    ice_hc.current_health = 50
    ice.add_child(ice_hc)
    _sh._ice_cells[CellUtil.cell_key(water_cell)] = [ice]
    var start := CellUtil.cell_to_world(Vector2i(49, 50))
    var end := CellUtil.cell_to_world(Vector2i(51, 50))
    var path := Pathfinder.find_path(start, end, {}, _wheel())
    var crosses := _path_cells(path).has(water_cell)
    _sh._ice_cells.erase(CellUtil.cell_key(water_cell))
    _reset_terrain()
    ice.free()
    TestHelper.assert_true(crosses, "intact ice lets wheeled cross water")


func test_cliff_blocks_foot():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _reset_terrain()
    _raise_wall()
    var start := CellUtil.cell_to_world(Vector2i(49, 50))
    var end := CellUtil.cell_to_world(Vector2i(52, 50))
    var path := Pathfinder.find_path(start, end, {}, _foot())
    var crossed := _path_cells(path).has(Vector2i(50, 50))
    _reset_terrain()
    TestHelper.assert_eq(crossed, false, "foot cannot cross the cliff wall")


func test_two_step_wall_blocks_foot():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _reset_terrain()
    _raise_step(2)
    var start := CellUtil.cell_to_world(Vector2i(49, 50))
    var end := CellUtil.cell_to_world(Vector2i(52, 50))
    var path := Pathfinder.find_path(start, end, {}, _foot())
    var crossed := _path_cells(path).has(Vector2i(50, 50))
    _reset_terrain()
    TestHelper.assert_eq(crossed, false, "foot cannot climb a 2-step wall")


func test_one_step_terrace_walkable():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _reset_terrain()
    _raise_step(1)
    var start := CellUtil.cell_to_world(Vector2i(49, 50))
    var end := CellUtil.cell_to_world(Vector2i(52, 50))
    var path := Pathfinder.find_path(start, end, {}, _foot())
    var crosses := _path_cells(path).has(Vector2i(50, 50))
    _reset_terrain()
    TestHelper.assert_true(crosses, "foot climbs a 1-step terrace")


func test_fly_ignores_cliffs():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _reset_terrain()
    _raise_wall()
    var start := CellUtil.cell_to_world(Vector2i(49, 50))
    var end := CellUtil.cell_to_world(Vector2i(52, 50))
    var path := Pathfinder.find_path(start, end, {}, _fly())
    var crosses := _path_cells(path).has(Vector2i(50, 50))
    _reset_terrain()
    TestHelper.assert_true(crosses, "fly crosses the cliff wall")


func test_no_locomotor_keeps_old_behavior():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _reset_terrain()
    var water_cell := Vector2i(50, 50)
    _ts.set_land_type(water_cell, "water")
    var start := CellUtil.cell_to_world(Vector2i(49, 50))
    var end := CellUtil.cell_to_world(Vector2i(51, 50))
    var path := Pathfinder.find_path(start, end)
    var crosses := _path_cells(path).has(water_cell)
    _reset_terrain()
    TestHelper.assert_true(crosses, "no locomotor -> terrain ignored, water crossed")


func test_cell_height_flat_matches_min_corner():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _reset_terrain()
    var cells: Array[Vector2i] = [Vector2i(10, 10), Vector2i(15, 12), Vector2i(20, 20)]
    for height: int in [0, 1, 3, 5]:
        for cell: Vector2i in cells:
            for vx in [cell.x, cell.x + 1]:
                for vz in [cell.y, cell.y + 1]:
                    _ts._vertex_grid[vx][vz] = height
            # Direct _vertex_grid writes bypass cell_changed; invalidate the
            # world-lifetime height snapshot so the read sees the new values.
            _ts.invalidate_height_snapshot()
            var got: float = Pathfinder._cell_height(_ts, cell)
            var expected: float = float(height) * _ts.HEIGHT_STEP
            (
                TestHelper
                . assert_true(
                    is_equal_approx(got, expected),
                    (
                        "flat cell %s at height %d: expected %s, got %s"
                        % [cell, height, expected, got]
                    ),
                )
            )
    _reset_terrain()


func test_cell_height_slope_matches_min_corner():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _reset_terrain()
    var cell := Vector2i(10, 10)
    var corners: Array[int] = [0, 3, 0, 3]
    _ts._vertex_grid[cell.x][cell.y] = corners[0]
    _ts._vertex_grid[cell.x + 1][cell.y] = corners[1]
    _ts._vertex_grid[cell.x][cell.y + 1] = corners[2]
    _ts._vertex_grid[cell.x + 1][cell.y + 1] = corners[3]
    var expected: float = float(corners.min()) * _ts.HEIGHT_STEP
    var got: float = Pathfinder._cell_height(_ts, cell)
    _reset_terrain()
    (
        TestHelper
        . assert_true(
            is_equal_approx(got, expected),
            "slope cell reads at its lowest corner: expected %s, got %s" % [expected, got],
        )
    )


func test_cell_height_parity_with_cell_height_read():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _reset_terrain()
    var patch: Dictionary = {
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
    var cells: Array[Vector2i] = [
        Vector2i(10, 10),
        Vector2i(12, 10),
        Vector2i(10, 12),
        Vector2i(12, 12),
        Vector2i(200, 200),
        Vector2i(-5, -5),
    ]
    for cell: Vector2i in cells:
        var expected: float
        if patch.has(cell):
            expected = float((patch[cell] as Array).min()) * _ts.HEIGHT_STEP
        else:
            expected = 0.0
        var got: float = Pathfinder._cell_height(_ts, cell)
        (
            TestHelper
            . assert_true(
                is_equal_approx(got, expected),
                (
                    "height parity with cell-height read for cell %s: expected %s, got %s"
                    % [cell, expected, got]
                ),
            )
        )
    _reset_terrain()


func test_foot_routes_around_raised_cell():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _reset_terrain()
    var bump := Vector2i(50, 50)
    for vx in [50, 51]:
        for vz in [50, 51]:
            _ts._vertex_grid[vx][vz] = 3
    var start := CellUtil.cell_to_world(Vector2i(49, 50))
    var end := CellUtil.cell_to_world(Vector2i(51, 50))
    var path := Pathfinder.find_path(start, end, {}, _foot())
    var avoids := not _path_cells(path).has(bump)
    _reset_terrain()
    TestHelper.assert_true(avoids, "foot path routes around a raised cell")


func test_wheeled_crosses_bridge_over_water():
    if _ts == null or _sh == null:
        TestHelper.fail("autoloads not injected")
        return
    _reset_terrain()
    var water_cell := Vector2i(50, 50)
    _ts.set_land_type(water_cell, "water")
    var start := CellUtil.cell_to_world(Vector2i(49, 50))
    var end := CellUtil.cell_to_world(Vector2i(51, 50))
    var uncovered := _path_cells(Pathfinder.find_path(start, end, {}, _wheel()))
    _register_bridge(water_cell, 0.0)
    var covered_path := Pathfinder.find_path(start, end, {}, _wheel())
    var covered := _path_cells(covered_path)
    _unregister_bridge(water_cell)
    var removed := _path_cells(Pathfinder.find_path(start, end, {}, _wheel()))
    _reset_terrain()
    TestHelper.assert_eq(uncovered.has(water_cell), false, "uncovered water cell is not crossed")
    TestHelper.assert_true(
        covered_path.size() > 0 and covered.has(water_cell),
        "wheeled path crosses the bridge deck cell"
    )
    TestHelper.assert_eq(
        removed.has(water_cell), false, "removed bridge reverts to water and is not crossed"
    )


func test_cell_height_reads_bridge_deck():
    if _ts == null or _sh == null:
        TestHelper.fail("autoloads not injected")
        return
    _reset_terrain()
    var cell := Vector2i(50, 50)
    var deck: float = 4.0 * _ts.HEIGHT_STEP
    _register_bridge(cell, deck)
    var deck_height: float = Pathfinder._cell_height(_ts, cell, 1)
    var ground_height: float = Pathfinder._cell_height(_ts, cell, 0)
    _unregister_bridge(cell)
    _reset_terrain()
    TestHelper.assert_true(
        is_equal_approx(deck_height, deck), "level 1 reads the bridge deck (got %s)" % deck_height
    )
    TestHelper.assert_true(
        is_equal_approx(ground_height, 0.0),
        "level 0 reads the ground beneath, not the deck (got %s)" % ground_height
    )


func test_high_bridge_climb_gated_by_grade():
    if _ts == null or _sh == null:
        TestHelper.fail("autoloads not injected")
        return
    _reset_terrain()
    var base_cell := Vector2i(50, 50)
    var deck_cell := Vector2i(50, 51)
    var deck_height: float = 4.0 * _ts.HEIGHT_STEP
    _register_bridge(deck_cell, deck_height)
    var foot := _foot()
    # Base-grade start adjacent to a +4 deck: the deck is not a valid step.
    var blocked_step := Pathfinder.try_greedy_step(
        base_cell, deck_cell, {}, foot, Pathfinder.GREEDY_STALL, null, _ts, 0, 1
    )
    # Matching-grade start (raised to the deck grade): the deck is a valid step.
    # This 4-step flat cell is the cliff bridge-end stand-in — a cell at the deck
    # grade entering the deck, per the cliff-end TerrainObject authored later by
    # the editor tooling (#228).
    for vx in [base_cell.x, base_cell.x + 1]:
        for vz in [base_cell.y, base_cell.y + 1]:
            _ts._vertex_grid[vx][vz] = 4
    _ts.invalidate_height_snapshot()
    var allowed_step := Pathfinder.try_greedy_step(
        base_cell, deck_cell, {}, foot, Pathfinder.GREEDY_STALL, null, _ts, 0, 1
    )
    _unregister_bridge(deck_cell)
    _reset_terrain()
    TestHelper.assert_eq(
        blocked_step, Pathfinder.GREEDY_STALL, "base grade cannot climb the +4 high deck"
    )
    TestHelper.assert_eq(allowed_step, deck_cell, "matching grade admits the high deck")


## GAP A: a deck destination skips its terrain figure and uses the Road row, so a
## locomotor declaring road but not bridge crosses a deck over water; one
## declaring neither road nor bridge is refused.
func test_deck_uses_road_row_for_locomotor_without_bridge():
    if _ts == null or _sh == null:
        TestHelper.fail("autoloads not injected")
        return
    _reset_terrain()
    var water_cell := Vector2i(50, 50)
    _ts.set_land_type(water_cell, "water")
    var start := CellUtil.cell_to_world(Vector2i(49, 50))
    var end := CellUtil.cell_to_world(Vector2i(51, 50))
    # Control: with no deck the water is impassable to a road-only mover.
    var uncovered := _path_cells(Pathfinder.find_path(start, end, {}, _road_only()))
    _register_bridge(water_cell, 0.0)
    var covered_path := Pathfinder.find_path(start, end, {}, _road_only())
    var covered := _path_cells(covered_path)
    var no_rows := _path_cells(Pathfinder.find_path(start, end, {}, _no_deck_rows()))
    _unregister_bridge(water_cell)
    _reset_terrain()
    TestHelper.assert_eq(
        uncovered.has(water_cell), false, "road-only mover cannot cross uncovered water"
    )
    (
        TestHelper
        . assert_true(
            covered_path.size() > 0 and covered.has(water_cell),
            "road-only mover crosses the deck via its Road row (no Bridge row declared)",
        )
    )
    TestHelper.assert_eq(
        no_rows.has(water_cell), false, "neither-road-nor-bridge mover is refused the deck"
    )


## GAP A: a same-level deck step costs from the Road row, not the deck land figure.
func test_same_level_deck_step_costs_from_road_row():
    if _ts == null or _sh == null:
        TestHelper.fail("autoloads not injected")
        return
    _reset_terrain()
    var cell := Vector2i(50, 50)
    var deck: float = 4.0 * _ts.HEIGHT_STEP
    _register_bridge(cell, deck)
    # Expected cost 1 / 1.25 derived from the spec's "costed from the Road row",
    # not from the production formula.
    var trans: Dictionary = Pathfinder._evaluate_transition(
        _ts, _road_only(), deck, cell, 1, cell, 1, 1.0 * _ts.HEIGHT_STEP, false, null
    )
    _unregister_bridge(cell)
    _reset_terrain()
    TestHelper.assert_true(
        trans.get("allowed", false), "same-level deck step is allowed via the Road row"
    )
    (
        TestHelper
        . assert_true(
            is_equal_approx(float(trans["cost_multiplier"]), 1.0 / 1.25),
            (
                "same-level deck cost is the inverse Road multiplier (got %s)"
                % trans["cost_multiplier"]
            ),
        )
    )
