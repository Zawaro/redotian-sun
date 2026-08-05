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
    wheel.terrain_speeds = {"clear": 1.0, "rough": 0.5, "road": 1.25}
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
    foot.terrain_speeds = {"clear": 1.0}
    foot.climb_tolerance = 1
    return foot


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
            var got: float = Pathfinder._cell_height(_ts, cell, _ts.grid_cells)
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


func test_cell_height_slope_matches_corner_average():
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
    var expected: float = (
        float(corners[0] + corners[1] + corners[2] + corners[3]) / 4.0 * _ts.HEIGHT_STEP
    )
    var got: float = Pathfinder._cell_height(_ts, cell, _ts.grid_cells)
    _reset_terrain()
    (
        TestHelper
        . assert_true(
            is_equal_approx(got, expected),
            "slope cell center = corner average: expected %s, got %s" % [expected, got],
        )
    )


func test_cell_height_parity_with_smooth_read():
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
        var expected: float = _ts.get_height_at_world_smooth(
            CellUtil.cell_to_world(cell, _ts.grid_cells)
        )
        var got: float = Pathfinder._cell_height(_ts, cell, _ts.grid_cells)
        (
            TestHelper
            . assert_true(
                is_equal_approx(got, expected),
                "height parity for cell %s: expected %s, got %s" % [cell, expected, got],
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
