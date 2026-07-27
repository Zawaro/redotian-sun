extends Node

# BuildingManager tests — placement validation

var _bm: Node = null
var _test_passed := 0
var _test_failed := 0


func _setup_2x2_terrain(origin: Vector2i) -> void:
    TerrainSystem.init_grid(64, 64)
    var offset_x := TerrainSystem.grid_cells.x >> 1
    var offset_z := TerrainSystem.grid_cells.y >> 1
    for dx in 2:
        for dz in 2:
            var cell := origin + Vector2i(dx, dz)
            var key := "%d,%d" % [cell.x + offset_x, cell.y + offset_z]
            TerrainSystem._cells[key] = {
                "height": 0, "type": "clear", "variant": 1, "direction": "", "rotation": 0.0
            }


func _make_2x2_building() -> EntityData:
    var building_type := EntityData.new()
    building_type.foundation = Vector2i(2, 2)
    return building_type


func test_can_place_returns_true_on_valid_cells():
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    var building_type := _make_2x2_building()
    var origin := Vector2i(5, 5)
    _setup_2x2_terrain(origin)
    var result: bool = _bm.can_place(building_type, origin)
    if result == true:
        _test_passed += 1
        print("    PASS: can_place returns true on valid cells")
    else:
        _test_failed += 1
        print("    FAIL: expected true, got false")


func test_can_place_rejects_building_overlap():
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    SpatialHash.instance._building_cells.clear()
    var cells: Array[Vector2i] = [Vector2i(6, 6), Vector2i(7, 6)]
    SpatialHash.instance.register_building_cells(cells)
    var building_type := _make_2x2_building()
    var origin := Vector2i(5, 5)
    _setup_2x2_terrain(origin)
    var result: bool = _bm.can_place(building_type, origin)
    SpatialHash.instance._building_cells.clear()
    if result == false:
        _test_passed += 1
        print("    PASS: can_place rejects building overlap")
    else:
        _test_failed += 1
        print("    FAIL: expected false, got true")


func test_can_place_rejects_tiberium_cell():
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    SpatialHash.instance._building_cells.clear()
    var building_type := _make_2x2_building()
    var origin := Vector2i(5, 5)
    _setup_2x2_terrain(origin)
    var tib_cell := Vector2i(6, 6)
    var tib_node := Node3D.new()
    tib_node.global_position = Vector3(tib_cell.x * 2 + 1, 0.0, tib_cell.y * 2 + 1)
    var tib_comp := Node.new()
    tib_comp.name = "ResourceComponent"
    tib_node.add_child(tib_comp)
    tib_node.add_to_group("resources")
    _bm.add_child(tib_node)
    var world_cell := CellUtil.world_to_cell(tib_node.global_position)
    SpatialHash.instance.register_resource_cell(world_cell)
    var result: bool = _bm.can_place(building_type, origin)
    SpatialHash.instance.unregister_resource_cell(world_cell)
    _bm.remove_child(tib_node)
    tib_node.queue_free()
    if result == false:
        _test_passed += 1
        print("    PASS: can_place rejects tiberium cell")
    else:
        _test_failed += 1
        print("    FAIL: expected false, got true")


func test_can_place_rejects_moving_unit():
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    SpatialHash.instance._building_cells.clear()
    SpatialHash.instance._blocked_cells.clear()
    SpatialHash.instance._grid.clear()
    var building_type := _make_2x2_building()
    var origin := Vector2i(5, 5)
    _setup_2x2_terrain(origin)
    var unit_cell := Vector2i(6, 6)
    var unit_key: int = CellUtil.cell_key(unit_cell)
    var fake_mc := MovementController.new()
    fake_mc._state = MovementController.State.MOVING
    SpatialHash.instance._grid[unit_key] = [{"node": Node3D.new(), "mc": fake_mc}]
    var result: bool = _bm.can_place(building_type, origin)
    SpatialHash.instance._grid.erase(unit_key)
    SpatialHash.instance._building_cells.clear()
    fake_mc.queue_free()
    if result == false:
        _test_passed += 1
        print("    PASS: can_place rejects moving unit")
    else:
        _test_failed += 1
        print("    FAIL: expected false, got true")


func test_adjacency_no_requirement_passes():
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    var building_type := _make_2x2_building()
    building_type.adjacent = 0
    var result: bool = _bm._is_adjacency_satisfied(building_type, Vector2i(5, 5))
    if result == true:
        _test_passed += 1
        print("    PASS: adjacency no-op when adjacent <= 0")
    else:
        _test_failed += 1
        print("    FAIL: expected true, got false")


func test_adjacency_rejected_without_neighbor():
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    var building_type := _make_2x2_building()
    building_type.adjacent = 1
    var saved: Array = _bm._buildings.duplicate()
    _bm._buildings.clear()
    var result: bool = _bm._is_adjacency_satisfied(building_type, Vector2i(5, 5))
    _bm._buildings.assign(saved)
    if result == false:
        _test_passed += 1
        print("    PASS: adjacency rejected with no friendly building")
    else:
        _test_failed += 1
        print("    FAIL: expected false, got true")


func test_adjacency_accepted_near_friendly():
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    var building_type := _make_2x2_building()
    building_type.adjacent = 1
    var pid: int = PlayerManager.get_local_player_id()
    var node := Node3D.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = pid
    node.add_child(stats)
    var saved: Array = _bm._buildings.duplicate()
    _bm._buildings.clear()
    _bm._buildings.append(
        {"node": node, "type": building_type, "origin": Vector2i(3, 3), "cells": [Vector2i(3, 3)]}
    )
    # Footprint at (4,3) includes cell (4,3), Chebyshev distance 1 from (3,3)
    var result: bool = _bm._is_adjacency_satisfied(building_type, Vector2i(4, 3))
    _bm._buildings.assign(saved)
    node.free()
    if result == true:
        _test_passed += 1
        print("    PASS: adjacency accepted near a friendly building")
    else:
        _test_failed += 1
        print("    FAIL: expected true, got false")


func test_adjacency_ignores_building_without_stats():
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    var building_type := _make_2x2_building()
    building_type.adjacent = 1
    # Building has no StatsComponent → must NOT count as a friendly neighbor
    var node := Node3D.new()
    var saved: Array = _bm._buildings.duplicate()
    _bm._buildings.clear()
    _bm._buildings.append(
        {"node": node, "type": building_type, "origin": Vector2i(3, 3), "cells": [Vector2i(3, 3)]}
    )
    var result: bool = _bm._is_adjacency_satisfied(building_type, Vector2i(4, 3))
    _bm._buildings.assign(saved)
    node.free()
    if result == false:
        _test_passed += 1
        print("    PASS: adjacency ignores stats-less building")
    else:
        _test_failed += 1
        print("    FAIL: expected false, got true")
