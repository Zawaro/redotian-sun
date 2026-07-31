extends Node

# Pathfinder per-locomotor passability, cost, climb tolerance, and ice carve-out

var _ts: Node = null
var _sh: Node = null
var _test_passed := 0
var _test_failed := 0


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
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


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
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_wheeled_blocked_by_water():
    if _ts == null or _sh == null:
        _test_failed += 1
        print("    FAIL: autoloads not injected")
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
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_hover_crosses_water():
    if _ts == null:
        _test_failed += 1
        print("    FAIL: TerrainSystem not injected")
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
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_ice_provides_footing_on_water():
    if _ts == null or _sh == null:
        _test_failed += 1
        print("    FAIL: autoloads not injected")
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
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_cliff_blocks_foot():
    if _ts == null:
        _test_failed += 1
        print("    FAIL: TerrainSystem not injected")
        return
    _reset_terrain()
    _raise_wall()
    var start := CellUtil.cell_to_world(Vector2i(49, 50))
    var end := CellUtil.cell_to_world(Vector2i(52, 50))
    var path := Pathfinder.find_path(start, end, {}, _foot())
    var crossed := _path_cells(path).has(Vector2i(50, 50))
    _reset_terrain()
    TestHelper.assert_eq(crossed, false, "foot cannot cross the cliff wall")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_fly_ignores_cliffs():
    if _ts == null:
        _test_failed += 1
        print("    FAIL: TerrainSystem not injected")
        return
    _reset_terrain()
    _raise_wall()
    var start := CellUtil.cell_to_world(Vector2i(49, 50))
    var end := CellUtil.cell_to_world(Vector2i(52, 50))
    var path := Pathfinder.find_path(start, end, {}, _fly())
    var crosses := _path_cells(path).has(Vector2i(50, 50))
    _reset_terrain()
    TestHelper.assert_true(crosses, "fly crosses the cliff wall")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_no_locomotor_keeps_old_behavior():
    if _ts == null:
        _test_failed += 1
        print("    FAIL: TerrainSystem not injected")
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
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
