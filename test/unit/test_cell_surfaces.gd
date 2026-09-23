extends Node

# Level-keyed cell surfaces: CellUtil.cell_level_key identity, level-parameterized
# TerrainSystem land/surface/grade queries, and the level-keyed SpatialHash bridge
# registry (stacked decks, per-level removal). Fixtures are StubBridge nodes under
# the scene root so SpatialHash's "bridge" group scan finds them.


class StubBridge:
    extends Node3D
    var data: Dictionary = {}

    func get_bridge_cell_data() -> Dictionary:
        return data


var _ts: Node = null
var _sh: Node = null
var _root: Node = null
var _spawned: Array[Node3D] = []


func _ensure_root() -> void:
    if _root == null:
        _root = Engine.get_main_loop().root


## Registers a live deck at `level` with the given walkable height over `cell`.
func _register(cell: Vector2i, level: int, surface_height: float) -> StubBridge:
    _ensure_root()
    var bridge := StubBridge.new()
    bridge.data = {
        "surface_height": surface_height,
        "is_end": false,
        "piece_id": "piece_%d" % level,
        "level": level,
    }
    bridge.add_to_group("bridge")
    _root.add_child(bridge)
    bridge.global_position = CellUtil.cell_to_world(cell)
    _spawned.append(bridge)
    return bridge


func _remove(bridge: Node3D) -> void:
    _spawned.erase(bridge)
    if is_instance_valid(bridge):
        _root.remove_child(bridge)
        bridge.free()


func _clear() -> void:
    if _root == null:
        _spawned.clear()
        return
    for bridge in _spawned:
        if is_instance_valid(bridge):
            _root.remove_child(bridge)
            bridge.free()
    _spawned.clear()
    if _sh:
        _sh.rebuild()


## Flattens a cell's 4 corners to `raw_height` steps and invalidates the height
## snapshot so the direct `_vertex_grid` write is visible to height queries.
func _flatten(cell: Vector2i, raw_height: int) -> void:
    for vx in [cell.x, cell.x + 1]:
        for vz in [cell.y, cell.y + 1]:
            _ts._vertex_grid[vx][vz] = raw_height
    _ts.invalidate_height_snapshot()


func test_cell_level_key_identity_and_format():
    var cell := Vector2i(7, 9)
    TestHelper.assert_eq(
        CellUtil.cell_level_key(cell, 0), CellUtil.cell_key(cell), "level 0 == cell_key"
    )
    TestHelper.assert_true(
        CellUtil.cell_level_key(cell, 1) != CellUtil.cell_key(cell), "level 1 differs from ground"
    )
    TestHelper.assert_true(
        CellUtil.cell_level_key(cell, 1) != CellUtil.cell_level_key(cell, 2),
        "level 1 and level 2 are distinct"
    )
    TestHelper.assert_eq(CellUtil.cell_level_key_str(cell, 0), "7,9,0", "level 0 string")
    TestHelper.assert_eq(CellUtil.cell_level_key_str(cell, 2), "7,9,2", "level 2 string")


func test_land_type_parity_level_zero_plain_cell():
    if _ts == null or _sh == null:
        TestHelper.fail("TerrainSystem/SpatialHash not injected")
        return
    _clear()
    _ts.init_grid(50, 50)
    var cell := Vector2i(43, 43)
    TestHelper.assert_true(
        CellUtil.is_in_diamond(cell, Vector2i(50, 50)), "fixture cell is inside the map"
    )
    _flatten(cell, 2)
    var expected_height: float = 2.0 * _ts.HEIGHT_STEP
    _ts.set_land_type(cell, "rough")
    TestHelper.assert_eq(_ts.get_land_type(cell), "rough", "ground land type at level 0")
    TestHelper.assert_eq(_ts.get_land_type(cell, 0), "rough", "explicit level 0 land type")
    TestHelper.assert_true(
        is_equal_approx(_ts.get_cell_surface_height(cell), expected_height),
        "flat ground surface height at level 0"
    )
    TestHelper.assert_true(
        is_equal_approx(_ts.get_cell_surface_height(cell, 0), expected_height),
        "explicit level 0 surface height"
    )
    TestHelper.assert_eq(_ts.get_cell_grade_steps(cell), 0, "flat ground has no grade")
    TestHelper.assert_eq(_ts.get_cell_grade_steps(cell, 0), 0, "explicit level 0 grade")
    _ts.set_land_type(cell, "clear")
    _clear()


func test_bridge_over_water_level_queries():
    if _ts == null or _sh == null:
        TestHelper.fail("TerrainSystem/SpatialHash not injected")
        return
    _clear()
    _ts.init_grid(50, 50)
    var cell := Vector2i(40, 40)
    TestHelper.assert_true(
        CellUtil.is_in_diamond(cell, Vector2i(50, 50)), "fixture cell is inside the map"
    )
    _ts.set_land_type(cell, "water")
    TestHelper.assert_eq(_ts.get_painted_land_type(cell), "water", "fixture painted water")
    TestHelper.assert_eq(_ts.get_land_type(cell), "water", "no deck -> ground is water")
    var deck: float = 3.0
    _register(cell, 1, deck)
    _sh.rebuild()
    TestHelper.assert_true(_sh.has_bridge_on_cell(cell, 1), "level-1 deck registered")
    TestHelper.assert_eq(_sh.has_bridge_on_cell(cell, 0), false, "no deck at level 0")
    TestHelper.assert_true(_sh.has_bridge_on_cell(cell), "any-level probe sees the deck")
    TestHelper.assert_eq(_ts.get_land_type(cell, 1), "bridge", "level 1 resolves the deck")
    TestHelper.assert_eq(_ts.get_land_type(cell, 2), "", "level 2 reports no surface")
    TestHelper.assert_eq(
        _ts.get_land_type(cell, 0), "water", "level 0 keeps the ground land beneath the deck"
    )
    TestHelper.assert_eq(_ts.get_painted_land_type(cell), "water", "ground water preserved")
    TestHelper.assert_true(
        is_equal_approx(_ts.get_cell_surface_height(cell, 1), deck),
        "level 1 walkable height is the deck"
    )
    TestHelper.assert_true(
        not is_equal_approx(_ts.get_cell_surface_height(cell, 0), deck),
        "level 0 is the ground surface, not the deck"
    )
    _remove(_spawned[0])
    _sh.rebuild()
    TestHelper.assert_eq(_sh.has_bridge_on_cell(cell, 1), false, "removed level-1 deck")
    TestHelper.assert_eq(_ts.get_land_type(cell, 1), "", "removed level 1 reports no surface")
    TestHelper.assert_eq(_ts.get_land_type(cell, 0), "water", "ground reverts to water")
    TestHelper.assert_eq(_ts.get_painted_land_type(cell), "water", "painted water survives")
    _ts.set_land_type(cell, "clear")
    _clear()


func test_stacked_decks_coexist():
    if _ts == null or _sh == null:
        TestHelper.fail("TerrainSystem/SpatialHash not injected")
        return
    _clear()
    _ts.init_grid(50, 50)
    var cell := Vector2i(41, 41)
    TestHelper.assert_true(
        CellUtil.is_in_diamond(cell, Vector2i(50, 50)), "fixture cell is inside the map"
    )
    var lower := 3.0
    var upper := 6.0
    _register(cell, 1, lower)
    _register(cell, 2, upper)
    _sh.rebuild()
    var levels: Array[int] = _sh.get_bridge_levels(cell)
    TestHelper.assert_eq(levels.size(), 2, "two stacked decks")
    if levels.size() == 2:
        TestHelper.assert_eq(levels[0], 1, "lowest deck is level 1")
        TestHelper.assert_eq(levels[1], 2, "upper deck is level 2")
    TestHelper.assert_true(_sh.has_bridge_on_cell(cell, 1), "level 1 present")
    TestHelper.assert_true(_sh.has_bridge_on_cell(cell, 2), "level 2 present")
    TestHelper.assert_true(_sh.has_bridge_on_cell(cell), "any-level present")
    var lowest: Dictionary = _sh.get_bridge_cell(cell, -1)
    TestHelper.assert_eq(int(lowest.get("level", -1)), 1, "any-level returns the lowest deck")
    TestHelper.assert_true(
        is_equal_approx(float(lowest.get("surface_height", -1.0)), lower),
        "lowest deck carries its own height"
    )
    var surfaces: Array[Dictionary] = _sh.get_bridge_surfaces(cell)
    TestHelper.assert_eq(surfaces.size(), 2, "two deck surfaces exposed")
    if surfaces.size() == 2:
        TestHelper.assert_eq(int(surfaces[0]["level"]), 1, "surfaces lowest first (level 1)")
        TestHelper.assert_eq(int(surfaces[1]["level"]), 2, "surfaces lowest first (level 2)")
    TestHelper.assert_true(
        is_equal_approx(_ts.get_cell_surface_height(cell, 1), lower), "level 1 deck height"
    )
    TestHelper.assert_true(
        is_equal_approx(_ts.get_cell_surface_height(cell, 2), upper), "level 2 deck height"
    )
    var all_levels: Array[int] = _ts.get_cell_surface_levels(cell)
    TestHelper.assert_eq(all_levels.size(), 3, "ground plus two decks")
    if all_levels.size() == 3:
        TestHelper.assert_eq(all_levels[0], 0, "ground level included")
        TestHelper.assert_eq(all_levels[1], 1, "first deck included")
        TestHelper.assert_eq(all_levels[2], 2, "second deck included")
    _clear()


func test_remove_one_deck_level_keeps_other():
    if _ts == null or _sh == null:
        TestHelper.fail("TerrainSystem/SpatialHash not injected")
        return
    _clear()
    _ts.init_grid(50, 50)
    var cell := Vector2i(42, 42)
    TestHelper.assert_true(
        CellUtil.is_in_diamond(cell, Vector2i(50, 50)), "fixture cell is inside the map"
    )
    var level_one := _register(cell, 1, 3.0)
    _register(cell, 2, 6.0)
    _sh.rebuild()
    TestHelper.assert_eq(_sh.get_bridge_levels(cell).size(), 2, "both decks present")
    _remove(level_one)
    _sh.rebuild()
    var levels: Array[int] = _sh.get_bridge_levels(cell)
    TestHelper.assert_eq(levels.size(), 1, "one deck removed")
    if levels.size() == 1:
        TestHelper.assert_eq(levels[0], 2, "surviving deck is level 2")
    TestHelper.assert_eq(_sh.has_bridge_on_cell(cell, 1), false, "level 1 gone")
    TestHelper.assert_true(_sh.has_bridge_on_cell(cell, 2), "level 2 survives")
    TestHelper.assert_eq(_ts.get_land_type(cell, 1), "", "level 1 no surface")
    TestHelper.assert_eq(_ts.get_land_type(cell, 2), "bridge", "level 2 still a deck")
    _clear()


func test_level_above_without_deck_reports_terrain():
    if _ts == null or _sh == null:
        TestHelper.fail("TerrainSystem/SpatialHash not injected")
        return
    _clear()
    _ts.init_grid(50, 50)
    var cell := Vector2i(44, 44)
    TestHelper.assert_true(
        CellUtil.is_in_diamond(cell, Vector2i(50, 50)), "fixture cell is inside the map"
    )
    _flatten(cell, 3)
    var expected_height: float = 3.0 * _ts.HEIGHT_STEP
    TestHelper.assert_eq(_ts.get_land_type(cell, 1), "", "no deck -> no surface land")
    TestHelper.assert_true(
        is_equal_approx(_ts.get_cell_surface_height(cell, 1), expected_height),
        "no deck -> terrain smooth height fallback"
    )
    _clear()


func test_deck_grade_uses_flat_surface_steps():
    if _ts == null or _sh == null:
        TestHelper.fail("TerrainSystem/SpatialHash not injected")
        return
    _clear()
    _ts.init_grid(50, 50)
    var cell := Vector2i(45, 45)
    TestHelper.assert_true(
        CellUtil.is_in_diamond(cell, Vector2i(50, 50)), "fixture cell is inside the map"
    )
    _flatten(cell, 1)
    _register(cell, 1, 4.0 * _ts.HEIGHT_STEP)
    _sh.rebuild()
    TestHelper.assert_eq(_ts.get_cell_surface_height(cell, 1) > 0.0, true, "deck has height")
    TestHelper.assert_eq(_ts.get_cell_grade_steps(cell, 1), 4, "flat deck grade = surface steps")
    _clear()


func test_bridge_component_publishes_level():
    _ensure_root()
    var data := EntityData.new()
    data.bridge_kind = EntityData.BridgeKind.HIGH
    data.bridge_level = 2
    data.bridge_end = false
    data.bridge_rise = 3.0
    var root := Node3D.new()
    _root.add_child(root)
    var component := BridgeComponent.new()
    component.name = "BridgeComponent"
    root.add_child(component)
    component.configure(data)
    var cell_data: Dictionary = component.get_bridge_cell_data()
    TestHelper.assert_true(not cell_data.is_empty(), "component publishes metadata")
    TestHelper.assert_eq(int(cell_data.get("level", -1)), 2, "component publishes its deck level")
    TestHelper.assert_eq(bool(cell_data.get("is_end", true)), false, "component publishes is_end")
    root.free()
