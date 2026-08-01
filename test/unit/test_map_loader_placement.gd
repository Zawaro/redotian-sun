extends Node

# MapLoader placement math — buildings anchor at footprint center so derived
# dock/foundation cells match the visual building (regression for pre-placed
# refinery dock offset).

var _test_passed := 0
var _test_failed := 0


func _make_building_data(foundation: Vector2i) -> EntityData:
    var data := EntityData.new()
    data.foundation = foundation
    data.entity_type = EntityData.EntityType.BUILDING
    return data


func test_building_placed_at_footprint_center():
    TerrainSystem.init_grid(50, 50)
    var data := _make_building_data(Vector2i(4, 3))
    var pos: Vector3 = MapLoader.placement_position(Vector2i(66, 58), data)
    var origin: Vector2i = CellUtil.world_to_cell_origin(pos, data.foundation)
    TerrainSystem.clear()
    if origin == Vector2i(66, 58):
        _test_passed += 1
        print("    PASS: building placed at footprint center, origin round-trips")
    else:
        _test_failed += 1
        print("    FAIL: origin=%s (expected (66,58))" % origin)


func test_building_dock_cell_alignment():
    TerrainSystem.init_grid(50, 50)
    var data := _make_building_data(Vector2i(4, 3))
    var pos: Vector3 = MapLoader.placement_position(Vector2i(66, 58), data)
    var origin: Vector2i = CellUtil.world_to_cell_origin(pos, data.foundation)
    # dock_position (6,0,2) = 3 cells x, 1 cell z from the origin.
    var dock_world := CellUtil.cell_to_world(origin) + Vector3(6.0, 0.0, 2.0)
    var dock_cell := CellUtil.world_to_cell(dock_world)
    var expected := origin + Vector2i(3, 1)
    TerrainSystem.clear()
    if dock_cell == expected:
        _test_passed += 1
        print("    PASS: dock cell lands at origin+(3,1), no offset")
    else:
        _test_failed += 1
        print("    FAIL: dock_cell=%s expected=%s" % [dock_cell, expected])


func test_unit_placed_at_cell_center():
    TerrainSystem.init_grid(50, 50)
    var data := EntityData.new()
    data.entity_type = EntityData.EntityType.VEHICLE
    var pos: Vector3 = MapLoader.placement_position(Vector2i(66, 58), data)
    var expected: Vector3 = CellUtil.cell_to_world(Vector2i(66, 58))
    TerrainSystem.clear()
    if pos == expected:
        _test_passed += 1
        print("    PASS: non-building placed at cell center")
    else:
        _test_failed += 1
        print("    FAIL: pos=%s expected=%s" % [pos, expected])


func test_building_placement_without_data_defaults_cell_center():
    TerrainSystem.init_grid(50, 50)
    var pos: Vector3 = MapLoader.placement_position(Vector2i(66, 58), null)
    var expected: Vector3 = CellUtil.cell_to_world(Vector2i(66, 58))
    TerrainSystem.clear()
    if pos == expected:
        _test_passed += 1
        print("    PASS: missing data falls back to cell center")
    else:
        _test_failed += 1
        print("    FAIL: pos=%s expected=%s" % [pos, expected])
