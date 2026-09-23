extends Node

# BridgeComponent attach via EntityFactory, "bridge" registration, deck surface
# heights (LOW/HIGH), shared piece_id, and the destruction-revert hook.

var _ts: Node = null
var _sh: Node = null
var _ef: Node = null
var _root: Node = null
var _spawned: Array[Node3D] = []


func _ensure_root() -> void:
    if _root == null:
        _root = Engine.get_main_loop().root


func _spawn(entity_id: String, cell: Vector2i) -> Node3D:
    _ensure_root()
    var entity: Node3D = _ef.create_entity(entity_id)
    if entity == null:
        return null
    _root.add_child(entity)
    entity.global_position = CellUtil.cell_to_world(cell)
    _spawned.append(entity)
    return entity


func _clear() -> void:
    for entity in _spawned:
        if is_instance_valid(entity):
            if entity.get_parent():
                entity.get_parent().remove_child(entity)
            entity.free()
    _spawned.clear()
    if _sh:
        _sh.rebuild()


## Flattens a cell's 4 corners to `height` (raw steps) and invalidates the
## height snapshot so direct `_vertex_grid` writes are visible.
func _flatten(cell: Vector2i, height: int) -> void:
    for vx in [cell.x, cell.x + 1]:
        for vz in [cell.y, cell.y + 1]:
            _ts._vertex_grid[vx][vz] = height
    _ts.invalidate_height_snapshot()


func test_factory_attaches_bridge_component_and_group():
    if _ts == null or _sh == null or _ef == null:
        TestHelper.fail("autoloads not injected")
        return
    _clear()
    _ts.init_grid(50, 50)
    var cell := Vector2i(20, 20)
    _flatten(cell, 2)
    var bridge := _spawn("BRIDGE", cell)
    TestHelper.assert_true(bridge != null, "bridge entity created")
    if bridge == null:
        return
    var bridge_component: Node = bridge.get_node_or_null("BridgeComponent")
    (
        TestHelper
        . assert_true(
            bridge_component != null and bridge_component.has_method("get_bridge_cell_data"),
            "bridge entity has a BridgeComponent",
        )
    )
    TestHelper.assert_true(bridge.is_in_group("bridge"), 'bridge entity joined the "bridge" group')
    TestHelper.assert_true(
        not bridge.is_in_group("entities"), 'bridge overlay stays out of "entities"'
    )
    _sh.rebuild()
    TestHelper.assert_true(_sh.has_bridge_on_cell(cell, 1), "bridge cell registers on rebuild")
    _clear()
    TestHelper.assert_eq(
        _sh.has_bridge_on_cell(cell, 1), false, "removed bridge cell leaves the registry"
    )


func test_non_bridge_entity_unaffected():
    if _ts == null or _ef == null:
        TestHelper.fail("autoloads not injected")
        return
    _clear()
    _ts.init_grid(50, 50)
    var unit := _spawn("GDI_LIGHT_INFANTRY", Vector2i(21, 21))
    TestHelper.assert_true(unit != null, "non-bridge entity created")
    if unit == null:
        return
    TestHelper.assert_true(
        unit.get_node_or_null("BridgeComponent") == null, "non-bridge entity has no BridgeComponent"
    )
    TestHelper.assert_true(not unit.is_in_group("bridge"), 'non-bridge entity not in "bridge"')
    _clear()


func test_low_bridge_surface_half_step_above_terrain():
    if _ts == null or _sh == null or _ef == null:
        TestHelper.fail("autoloads not injected")
        return
    _clear()
    _ts.init_grid(50, 50)
    var cell := Vector2i(24, 24)
    _flatten(cell, 3)
    var base: float = 3.0 * _ts.HEIGHT_STEP
    var rise: float = _ef.get_entity_data("BRIDGE").bridge_rise
    _spawn("BRIDGE", cell)
    _sh.rebuild()
    var data: Dictionary = _sh.get_bridge_cell(cell, 1)
    TestHelper.assert_true(not data.is_empty(), "low bridge registered")
    if not data.is_empty():
        (
            TestHelper
            . assert_true(
                is_equal_approx(rise, 0.5 * _ts.HEIGHT_STEP),
                "LOW bridge_rise is half a height step",
            )
        )
        (
            TestHelper
            . assert_true(
                is_equal_approx(float(data["surface_height"]), base + rise),
                "LOW deck sits bridge_rise above the terrain",
            )
        )
        (
            TestHelper
            . assert_true(
                is_equal_approx(_ts.get_cell_surface_height(cell, 1), base + rise),
                "get_cell_surface_height(cell, 1) reads the LOW deck",
            )
        )
        TestHelper.assert_true(
            is_equal_approx(_ts.get_cell_surface_height(cell), base),
            "ground under the LOW deck keeps its own height at level 0"
        )
    _clear()


func test_high_bridge_surface_elevated_by_rise():
    if _ts == null or _sh == null or _ef == null:
        TestHelper.fail("autoloads not injected")
        return
    _clear()
    _ts.init_grid(50, 50)
    var cell := Vector2i(22, 22)
    _flatten(cell, 2)
    var base: float = 2.0 * _ts.HEIGHT_STEP
    _spawn("BRIDGE_HIGH", cell)
    _sh.rebuild()
    var data: Dictionary = _sh.get_bridge_cell(cell, 1)
    TestHelper.assert_true(not data.is_empty(), "high bridge registered")
    if not data.is_empty():
        var rise: float = _ef.get_entity_data("BRIDGE_HIGH").bridge_rise
        TestHelper.assert_true(rise > 0.0, "high bridge has a positive rise")
        (
            TestHelper
            . assert_true(
                is_equal_approx(float(data["surface_height"]), base + rise),
                "HIGH deck sits bridge_rise above the terrain",
            )
        )
        (
            TestHelper
            . assert_true(
                is_equal_approx(_ts.get_cell_surface_height(cell, 1), base + rise),
                "get_cell_surface_height(cell, 1) reads the HIGH deck",
            )
        )
        TestHelper.assert_true(
            is_equal_approx(_ts.get_cell_surface_height(cell), base),
            "ground under the HIGH deck keeps its own height at level 0"
        )
        TestHelper.assert_eq(String(data["piece_id"]), "", "default piece_id is empty")
    _clear()


func test_piece_id_shared_across_three_cells():
    if _ts == null or _sh == null or _ef == null:
        TestHelper.fail("autoloads not injected")
        return
    _clear()
    _ts.init_grid(50, 50)
    var cells: Array[Vector2i] = [Vector2i(30, 30), Vector2i(31, 30), Vector2i(32, 30)]
    for cell in cells:
        _flatten(cell, 0)
    var piece := "piece_%d" % Time.get_ticks_usec()
    for cell in cells:
        var entity := _spawn("BRIDGE", cell)
        var component: Node = entity.get_node_or_null("BridgeComponent")
        if component == null:
            TestHelper.fail("missing BridgeComponent on %s" % cell)
            _clear()
            return
        component.call("assign_piece_id", piece)
    _sh.rebuild()
    for cell in cells:
        var data: Dictionary = _sh.get_bridge_cell(cell, 1)
        TestHelper.assert_eq(
            String(data.get("piece_id", "")), piece, "cell %s carries the shared piece_id" % cell
        )
    _clear()


func test_destroyed_bridge_drops_from_registry():
    if _ts == null or _sh == null or _ef == null:
        TestHelper.fail("autoloads not injected")
        return
    _clear()
    _ts.init_grid(50, 50)
    var cell := Vector2i(26, 26)
    _flatten(cell, 0)
    var bridge := _spawn("BRIDGE", cell)
    _sh.rebuild()
    TestHelper.assert_true(_sh.has_bridge_on_cell(cell, 1), "bridge registered before destruction")
    var health := bridge.get_node_or_null("HealthComponent") as HealthComponent
    TestHelper.assert_true(health != null, "bridge has a HealthComponent")
    if health:
        health.kill()
    _sh.rebuild()
    TestHelper.assert_eq(
        _sh.has_bridge_on_cell(cell, 1), false, "destroyed non-end piece leaves the registry"
    )
    _clear()
