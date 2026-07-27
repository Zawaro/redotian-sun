extends Node

# FoundationComponent tests — canonical footprint queries

var _test_passed := 0
var _test_failed := 0


func _ok(cond: bool, name: String) -> void:
    if cond:
        _test_passed += 1
        print("    PASS: " + name)
    else:
        _test_failed += 1
        print("    FAIL: " + name)


func _setup_clear(origin: Vector2i, size: Vector2i) -> void:
    TerrainSystem.init_grid(64, 64)
    var offset_x := TerrainSystem.grid_cells.x >> 1
    var offset_z := TerrainSystem.grid_cells.y >> 1
    for dx in size.x:
        for dz in size.y:
            var cell := origin + Vector2i(dx, dz)
            var key := "%d,%d" % [cell.x + offset_x, cell.y + offset_z]
            TerrainSystem._cells[key] = {
                "height": 0, "type": "clear", "variant": 1, "direction": "", "rotation": 0.0
            }


func test_occupied_cells_excludes_bib():
    var fc := FoundationComponent.new()
    fc.foundation = Vector2i(2, 2)
    fc.bib_cells = [Vector2i(0, 1)]
    var origin := Vector2i(3, 3)
    var occ := fc.get_occupied_cells(origin)
    fc.free()
    _ok(occ.size() == 3 and not occ.has(Vector2i(3, 4)), "get_occupied_cells excludes bib cell")


func test_occupied_cells_equals_foundation_without_bib():
    var fc := FoundationComponent.new()
    fc.foundation = Vector2i(2, 2)
    var occ := fc.get_occupied_cells(Vector2i(0, 0))
    var found := fc.get_foundation_cells(Vector2i(0, 0))
    fc.free()
    _ok(occ.size() == 4 and found.size() == 4, "occupied == foundation when no bib")


func test_is_cell_buildable_free_clear():
    SpatialHash.instance._building_cells.clear()
    SpatialHash.instance._blocked_cells.clear()
    _setup_clear(Vector2i(5, 5), Vector2i(1, 1))
    _ok(
        FoundationComponent.is_cell_buildable(Vector2i(5, 5)),
        "is_cell_buildable true on free clear"
    )


func test_is_cell_buildable_building_cell():
    SpatialHash.instance._building_cells.clear()
    _setup_clear(Vector2i(5, 5), Vector2i(1, 1))
    SpatialHash.instance.register_building_cells([Vector2i(5, 5)])
    var result := FoundationComponent.is_cell_buildable(Vector2i(5, 5))
    SpatialHash.instance._building_cells.clear()
    _ok(not result, "is_cell_buildable false on building cell")


func test_is_buildable_true_on_flat_free():
    SpatialHash.instance._building_cells.clear()
    SpatialHash.instance._blocked_cells.clear()
    _setup_clear(Vector2i(10, 10), Vector2i(2, 2))
    var fc := FoundationComponent.new()
    fc.foundation = Vector2i(2, 2)
    var result := fc.is_buildable(Vector2i(10, 10))
    fc.free()
    _ok(result, "is_buildable true on flat free footprint")


func test_is_buildable_false_when_occupied():
    SpatialHash.instance._building_cells.clear()
    _setup_clear(Vector2i(10, 10), Vector2i(2, 2))
    SpatialHash.instance.register_building_cells([Vector2i(11, 11)])
    var fc := FoundationComponent.new()
    fc.foundation = Vector2i(2, 2)
    var result := fc.is_buildable(Vector2i(10, 10))
    SpatialHash.instance._building_cells.clear()
    fc.free()
    _ok(not result, "is_buildable false when a footprint cell is occupied")


func test_is_buildable_false_on_steep_height():
    SpatialHash.instance._building_cells.clear()
    SpatialHash.instance._blocked_cells.clear()
    _setup_clear(Vector2i(20, 20), Vector2i(2, 2))
    var offset_x := TerrainSystem.grid_cells.x >> 1
    var offset_z := TerrainSystem.grid_cells.y >> 1
    TerrainSystem.set_vertex(20 + offset_x, 20 + offset_z, 3)
    var fc := FoundationComponent.new()
    fc.foundation = Vector2i(2, 2)
    var result := fc.is_buildable(Vector2i(20, 20))
    TerrainSystem.init_grid(64, 64)
    fc.free()
    _ok(not result, "is_buildable false when height delta too steep")
