extends Node

# Building placement integration test — placement registers cells, pathfinder avoids them

var _bm: Node = null
var _test_passed := 0
var _test_failed := 0


func test_centered_building_foundation_can_be_placed_and_registered() -> void:
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    SpatialHash.instance._building_cells.clear()
    TerrainSystem.init_grid(64, 64)
    var building_type := EntityData.new()
    building_type.id = "test_building"
    building_type.foundation = Vector2i(2, 2)
    building_type.entity_type = EntityData.EntityType.BUILDING
    building_type.strength = 100
    building_type.owner = ["GDI"]
    # A 64x64 map is centered around cell coordinate (64,64), not (32,32).
    var origin := Vector2i(64, 64)
    for dx in 2:
        for dz in 2:
            var cell := origin + Vector2i(dx, dz)
            var key := "%d,%d" % [cell.x, cell.y]
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
    var has_origin: bool = blocked.has(CellUtil.cell_key(Vector2i(64, 64)))
    var has_east: bool = blocked.has(CellUtil.cell_key(Vector2i(65, 64)))
    var has_south: bool = blocked.has(CellUtil.cell_key(Vector2i(64, 65)))
    var has_south_east: bool = blocked.has(CellUtil.cell_key(Vector2i(65, 65)))
    SpatialHash.instance._building_cells.clear()
    if can_place and has_origin and has_east and has_south and has_south_east:
        _test_passed += 1
        print("    PASS: centered foundation placement registers its four real cells")
    else:
        _test_failed += 1
        print(
            (
                "    FAIL: can_place=%s, cells=%s%s%s%s"
                % [can_place, has_origin, has_east, has_south, has_south_east]
            )
        )


func test_pathfinder_routes_around_centered_building_cell() -> void:
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    SpatialHash.instance._building_cells.clear()
    TerrainSystem.init_grid(64, 64)
    var cells: Array[Vector2i] = [Vector2i(64, 64)]
    SpatialHash.instance.register_building_cells(cells)
    var blocked: Dictionary = SpatialHash.instance.get_blocked_cells()
    var start_cell: Vector2i = Vector2i(60, 64)
    var end_cell: Vector2i = Vector2i(68, 64)
    var start_world: Vector3 = CellUtil.cell_to_world(start_cell)
    var end_world: Vector3 = CellUtil.cell_to_world(end_cell)
    var path: PackedVector3Array = Pathfinder.find_path(start_world, end_world, blocked)
    var avoids_building: bool = not path.is_empty()
    var reaches_destination: bool = false
    var bad_cell: Vector2i = Vector2i.ZERO
    var gc: Vector2i = TerrainSystem.grid_cells
    for waypoint: Vector3 in path:
        var cell: Vector2i = CellUtil.world_to_cell(waypoint, gc)
        var key: int = CellUtil.cell_key(cell)
        if blocked.has(key):
            avoids_building = false
            bad_cell = cell
            break
        if cell == end_cell:
            reaches_destination = true
    SpatialHash.instance._building_cells.clear()
    if avoids_building and reaches_destination:
        _test_passed += 1
        print("    PASS: pathfinder reaches destination around centered building cell")
    else:
        _test_failed += 1
        print(
            "    FAIL: reaches=%s, blocked cell=%s, path=%s" % [reaches_destination, bad_cell, path]
        )


func test_foundation_component_does_not_register_cells_on_ready():
    SpatialHash.instance._building_cells.clear()
    TerrainSystem.init_grid(64, 64)
    var entity := Node3D.new()
    entity.name = "TestBuilding"
    var fc := FoundationComponent.new()
    fc.foundation = Vector2i(3, 3)
    entity.add_child(fc)
    entity.position = Vector3(11.0, 0.0, 11.0)
    SpatialHash.instance.add_child(entity)
    var sh := SpatialHash.instance
    var building_cell_count := sh.get_building_cells().size()
    SpatialHash.instance.remove_child(entity)
    entity.free()
    SpatialHash.instance._building_cells.clear()
    if building_cell_count == 0:
        _test_passed += 1
        print("    PASS: FoundationComponent does not register cells on _ready")
    else:
        _test_failed += 1
        print("    FAIL: FC registered %d cells on _ready (should be 0)" % building_cell_count)
