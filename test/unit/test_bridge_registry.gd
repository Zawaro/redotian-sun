extends Node

# Bridge cell registry (SpatialHash) and bridge land-type / surface resolution
# (TerrainSystem). Fixture nodes live under the scene root so the registry's
# group scan can find them, then are freed per test.


class StubBridge:
    extends Node3D
    var data: Dictionary = {}

    func get_bridge_cell_data() -> Dictionary:
        return data


var _sh: Node = null
var _ts: Node = null
var _root: Node = null
var _spawned: Array[Node3D] = []


func _ensure_fixture(cell: Vector2i, data: Dictionary) -> StubBridge:
    if _root == null:
        _root = Engine.get_main_loop().root
    var bridge := StubBridge.new()
    bridge.data = data
    bridge.add_to_group("bridge")
    _root.add_child(bridge)
    bridge.global_position = CellUtil.cell_to_world(cell)
    _spawned.append(bridge)
    return bridge


func _clear_fixture() -> void:
    if _root == null:
        return
    for node in _spawned:
        if is_instance_valid(node):
            _root.remove_child(node)
            node.free()
    _spawned.clear()


func test_bridge_registry_register_and_metadata():
    if _sh == null or _ts == null:
        TestHelper.fail("SpatialHash/TerrainSystem not injected")
        return
    _clear_fixture()
    _ts.init_grid(50, 50)
    var cell := Vector2i(20, 20)
    _ensure_fixture(
        cell, {"surface_height": 3.26, "is_end": false, "piece_id": "piece_a", "level": 1}
    )
    _sh.rebuild()
    TestHelper.assert_true(_sh.has_bridge_on_cell(cell, 1), "level-1 bridge cell registered")
    TestHelper.assert_true(_sh.has_bridge_on_cell(cell), "any-level probe sees the deck")
    TestHelper.assert_true(
        not _sh.has_bridge_on_cell(cell + Vector2i(1, 0), 1), "neighbor cell not registered"
    )
    var data: Dictionary = _sh.get_bridge_cell(cell, 1)
    TestHelper.assert_true(not data.is_empty(), "bridge metadata present")
    if not data.is_empty():
        TestHelper.assert_true(
            is_equal_approx(float(data["surface_height"]), 3.26), "surface_height stored"
        )
        TestHelper.assert_eq(bool(data["is_end"]), false, "is_end stored")
        TestHelper.assert_eq(String(data["piece_id"]), "piece_a", "piece_id stored")
    _clear_fixture()
    _sh.rebuild()
    TestHelper.assert_eq(_sh.has_bridge_on_cell(cell, 1), false, "removed bridge leaves registry")


func test_bridge_registry_empty_and_malformed():
    if _sh == null or _ts == null:
        TestHelper.fail("SpatialHash/TerrainSystem not injected")
        return
    _clear_fixture()
    _ts.init_grid(50, 50)
    _sh.rebuild()
    TestHelper.assert_eq(
        _sh.get_bridge_cell(Vector2i(20, 20), 1).is_empty(), true, "empty registry -> no metadata"
    )
    var cell := Vector2i(23, 23)
    _ensure_fixture(cell, {})
    _sh.rebuild()
    TestHelper.assert_eq(
        _sh.has_bridge_on_cell(cell, 1), false, "bridge without required metadata is skipped"
    )
    _clear_fixture()
    _sh.rebuild()


func test_get_land_type_bridge_over_water_reverts():
    if _sh == null or _ts == null:
        TestHelper.fail("SpatialHash/TerrainSystem not injected")
        return
    _clear_fixture()
    _ts.init_grid(50, 50)
    var cell := Vector2i(24, 24)
    _ts.set_land_type(cell, "water")
    TestHelper.assert_eq(_ts.get_land_type(cell), "water", "fixture starts as water")
    _ensure_fixture(cell, {"surface_height": 0.0, "is_end": false, "piece_id": "p", "level": 1})
    _sh.rebuild()
    TestHelper.assert_eq(_ts.get_land_type(cell, 1), "bridge", "level 1 resolves the deck")
    TestHelper.assert_eq(
        _ts.get_land_type(cell), "water", "level 0 keeps the ground land beneath the deck"
    )
    _clear_fixture()
    _sh.rebuild()
    TestHelper.assert_eq(_ts.get_land_type(cell, 1), "", "no deck -> no level-1 surface")
    TestHelper.assert_eq(_ts.get_land_type(cell), "water", "ground stays water after removal")
    TestHelper.assert_eq(_ts.get_painted_land_type(cell), "water", "painted override preserved")
    _ts.set_land_type(cell, "clear")


func test_get_cell_surface_height_bridge_then_terrain():
    if _sh == null or _ts == null:
        TestHelper.fail("SpatialHash/TerrainSystem not injected")
        return
    _clear_fixture()
    _ts.init_grid(50, 50)
    var cell := Vector2i(25, 25)
    _ts._set_vertex_no_cascade(cell.x, cell.y, 3)
    _ts._set_vertex_no_cascade(cell.x + 1, cell.y, 3)
    _ts._set_vertex_no_cascade(cell.x, cell.y + 1, 3)
    _ts._set_vertex_no_cascade(cell.x + 1, cell.y + 1, 3)
    _ts.invalidate_height_snapshot()
    var terrain_height: float = 3.0 * _ts.HEIGHT_STEP
    TestHelper.assert_true(is_equal_approx(terrain_height, 2.445), "fixture terrain height is real")
    TestHelper.assert_true(
        is_equal_approx(_ts.get_cell_surface_height(cell), terrain_height),
        "no bridge -> ground surface height"
    )
    _ensure_fixture(cell, {"surface_height": 8.0, "is_end": true, "piece_id": "p2", "level": 1})
    _sh.rebuild()
    TestHelper.assert_true(
        is_equal_approx(_ts.get_cell_surface_height(cell, 1), 8.0), "level 1 -> deck surface height"
    )
    TestHelper.assert_true(
        is_equal_approx(_ts.get_cell_surface_height(cell), terrain_height),
        "level 0 stays the ground beneath the deck"
    )
    _clear_fixture()
    _sh.rebuild()
    TestHelper.assert_true(
        is_equal_approx(_ts.get_cell_surface_height(cell), terrain_height),
        "removed bridge -> ground surface height"
    )
