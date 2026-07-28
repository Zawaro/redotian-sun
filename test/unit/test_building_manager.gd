extends Node

# BuildingManager tests — placement validation

var _bm: Node = null
var _test_passed := 0
var _test_failed := 0


func _setup_2x2_terrain(origin: Vector2i) -> void:
    TerrainSystem.init_grid(64, 64)
    for dx in 2:
        for dz in 2:
            var cell := origin + Vector2i(dx, dz)
            var key := "%d,%d" % [cell.x, cell.y]
            TerrainSystem._cells[key] = {
                "height": 0, "type": "clear", "variant": 1, "direction": "", "rotation": 0.0
            }


func _make_2x2_building() -> EntityData:
    var building_type := EntityData.new()
    building_type.foundation = Vector2i(2, 2)
    return building_type


func test_can_place_returns_true_on_valid_centered_cells() -> void:
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    var building_type := _make_2x2_building()
    var origin := Vector2i(64, 64)
    _setup_2x2_terrain(origin)
    var result: bool = _bm.can_place(building_type, origin)
    if result == true:
        _test_passed += 1
        print("    PASS: can_place returns true on valid cells")
    else:
        _test_failed += 1
        print("    FAIL: expected true, got false")


func test_can_place_rejects_building_overlap() -> void:
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    SpatialHash.instance._building_cells.clear()
    var building_type := _make_2x2_building()
    var origin := Vector2i(64, 64)
    _setup_2x2_terrain(origin)
    var valid_before_overlap: bool = _bm.can_place(building_type, origin)
    var cells: Array[Vector2i] = [Vector2i(64, 64), Vector2i(65, 64)]
    SpatialHash.instance.register_building_cells(cells)
    var result: bool = _bm.can_place(building_type, origin)
    SpatialHash.instance._building_cells.clear()
    if valid_before_overlap and result == false:
        _test_passed += 1
        print("    PASS: can_place rejects building overlap")
    else:
        _test_failed += 1
        print("    FAIL: expected false, got true")


func test_can_place_rejects_tiberium_cell() -> void:
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    SpatialHash.instance._building_cells.clear()
    var building_type := _make_2x2_building()
    var origin := Vector2i(64, 64)
    _setup_2x2_terrain(origin)
    var valid_before_resource: bool = _bm.can_place(building_type, origin)
    var tib_cell := Vector2i(64, 64)
    var tib_node := Node3D.new()
    var tib_comp := Node.new()
    tib_comp.name = "ResourceComponent"
    tib_node.add_child(tib_comp)
    tib_node.add_to_group("resources")
    _bm.add_child(tib_node)
    tib_node.global_position = CellUtil.cell_to_world(tib_cell)
    var world_cell: Vector2i = CellUtil.world_to_cell(tib_node.global_position)
    SpatialHash.instance.register_resource_cell(world_cell)
    var result: bool = _bm.can_place(building_type, origin)
    SpatialHash.instance.unregister_resource_cell(world_cell)
    _bm.remove_child(tib_node)
    tib_node.queue_free()
    if valid_before_resource and result == false:
        _test_passed += 1
        print("    PASS: can_place rejects tiberium cell")
    else:
        _test_failed += 1
        print("    FAIL: expected false, got true")


func test_can_place_rejects_moving_unit() -> void:
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    SpatialHash.instance._building_cells.clear()
    SpatialHash.instance._blocked_cells.clear()
    SpatialHash.instance._grid.clear()
    var building_type := _make_2x2_building()
    var origin := Vector2i(64, 64)
    _setup_2x2_terrain(origin)
    var valid_before_unit: bool = _bm.can_place(building_type, origin)
    var unit_cell := Vector2i(64, 64)
    var unit_key: int = CellUtil.cell_key(unit_cell)
    var fake_mc := MovementController.new()
    fake_mc._state = MovementController.State.MOVING
    SpatialHash.instance._grid[unit_key] = [{"node": Node3D.new(), "mc": fake_mc}]
    var result: bool = _bm.can_place(building_type, origin)
    SpatialHash.instance._grid.erase(unit_key)
    SpatialHash.instance._building_cells.clear()
    fake_mc.queue_free()
    if valid_before_unit and result == false:
        _test_passed += 1
        print("    PASS: can_place rejects moving unit")
    else:
        _test_failed += 1
        print("    FAIL: expected false, got true")
