extends Node

# Building placement integration test — placement registers cells, pathfinder avoids them

var _bm: Node = null
var _test_passed := 0
var _test_failed := 0


func test_place_building_registers_cells():
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    SpatialHash.instance._building_cells.clear()
    TerrainSystem.init_grid(32)
    var building_type := EntityData.new()
    building_type.id = "test_building"
    building_type.foundation = Vector2i(2, 2)
    building_type.entity_type = EntityData.EntityType.BUILDING
    building_type.strength = 100
    building_type.owner = ["GDI"]
    var origin := Vector2i(5, 5)
    var offset := TerrainSystem.grid_cells >> 1
    for dx in 2:
        for dz in 2:
            var cell := origin + Vector2i(dx, dz)
            var key := "%d,%d" % [cell.x + offset, cell.y + offset]
            TerrainSystem._cells[key] = {
                "height": 0, "type": "clear", "variant": 1, "direction": "", "rotation": 0.0
            }
    var can_place: bool = _bm.can_place(building_type, origin)
    if can_place:
        var cells: Array[Vector2i] = []
        for dx in 2:
            for dz in 2:
                cells.append(origin + Vector2i(dx, dz))
        SpatialHash.instance.register_building_cells(cells)
    var blocked := SpatialHash.instance.get_blocked_cells()
    var sh := SpatialHash.instance
    var has_55 := blocked.has(sh._cell_key(Vector2i(5, 5)))
    var has_65 := blocked.has(sh._cell_key(Vector2i(6, 5)))
    var has_56 := blocked.has(sh._cell_key(Vector2i(5, 6)))
    var has_66 := blocked.has(sh._cell_key(Vector2i(6, 6)))
    SpatialHash.instance._building_cells.clear()
    if can_place and has_55 and has_65 and has_56 and has_66:
        _test_passed += 1
        print("    PASS: place_building registers cells in get_blocked_cells")
    else:
        _test_failed += 1
        print(
            "    FAIL: can_place=%s, cells=%s%s%s%s" % [can_place, has_55, has_65, has_56, has_66]
        )


func test_pathfinder_avoids_building_cells():
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    SpatialHash.instance._building_cells.clear()
    TerrainSystem.init_grid(32)
    var cells: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 5), Vector2i(5, 6), Vector2i(6, 6)]
    SpatialHash.instance.register_building_cells(cells)
    var blocked := SpatialHash.instance.get_blocked_cells()
    var start_world := Vector3(2.0, 0.0, 2.0)
    var end_world := Vector3(14.0, 0.0, 14.0)
    var path: PackedVector3Array = Pathfinder.find_path(start_world, end_world, blocked)
    var avoids_building := true
    for waypoint in path:
        var cell := Pathfinder.world_to_cell(waypoint)
        var key := Pathfinder._cell_key(cell)
        if blocked.has(key):
            avoids_building = false
            break
    SpatialHash.instance._building_cells.clear()
    if avoids_building:
        _test_passed += 1
        print("    PASS: pathfinder avoids building cells")
    else:
        _test_failed += 1
        print("    FAIL: path includes building cell")
