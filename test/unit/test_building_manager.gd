extends Node

# BuildingManager tests — placement validation

var _bm: Node = null
var _test_passed := 0
var _test_failed := 0


func test_can_place_returns_true_on_valid_cells():
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    var building_type := EntityData.new()
    building_type.foundation = Vector2i(2, 2)
    var origin := Vector2i(5, 5)
    TerrainSystem.init_grid(32)
    var offset := TerrainSystem.grid_cells >> 1
    for dx in 2:
        for dz in 2:
            var cell := origin + Vector2i(dx, dz)
            var key := "%d,%d" % [cell.x + offset, cell.y + offset]
            TerrainSystem._cells[key] = {
                "height": 0, "type": "clear", "variant": 1, "direction": "", "rotation": 0.0
            }
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
    var building_type := EntityData.new()
    building_type.foundation = Vector2i(2, 2)
    var origin := Vector2i(5, 5)
    TerrainSystem.init_grid(32)
    var offset := TerrainSystem.grid_cells >> 1
    for dx in 2:
        for dz in 2:
            var cell := origin + Vector2i(dx, dz)
            var key := "%d,%d" % [cell.x + offset, cell.y + offset]
            TerrainSystem._cells[key] = {
                "height": 0, "type": "clear", "variant": 1, "direction": "", "rotation": 0.0
            }
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
    var building_type := EntityData.new()
    building_type.foundation = Vector2i(2, 2)
    var origin := Vector2i(5, 5)
    TerrainSystem.init_grid(32)
    var offset := TerrainSystem.grid_cells >> 1
    for dx in 2:
        for dz in 2:
            var cell := origin + Vector2i(dx, dz)
            var key := "%d,%d" % [cell.x + offset, cell.y + offset]
            TerrainSystem._cells[key] = {
                "height": 0, "type": "clear", "variant": 1, "direction": "", "rotation": 0.0
            }
    var tib_cell := Vector2i(6, 6)
    var tib_node := Node3D.new()
    tib_node.global_position = Vector3(tib_cell.x * 2 + 1, 0.0, tib_cell.y * 2 + 1)
    var tib_comp := Node.new()
    tib_comp.name = "ResourceComponent"
    tib_node.add_child(tib_comp)
    tib_node.add_to_group("resources")
    _bm.add_child(tib_node)
    var result: bool = _bm.can_place(building_type, origin)
    _bm.remove_child(tib_node)
    tib_node.queue_free()
    if result == false:
        _test_passed += 1
        print("    PASS: can_place rejects tiberium cell")
    else:
        _test_failed += 1
        print("    FAIL: expected false, got true")
