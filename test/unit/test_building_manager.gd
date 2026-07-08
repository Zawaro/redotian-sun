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
