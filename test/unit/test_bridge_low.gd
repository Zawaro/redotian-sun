extends Node

# LOW bridge rework (Phase 4). A LOW deck sits `bridge_rise` (half a height step)
# above its cell's terrain with thickness rendered upward; the underlying ground
# keeps its own land; ground traffic enters and leaves across the slope end
# pieces within climb tolerance; only LOW normal span pieces are destructible —
# LOW end pieces are indestructible. Fixtures are real EntityFactory overlays so
# the whole registry/data/land/path path is exercised.

const HEIGHT_STEP: float = 0.815
## 0.5 * HEIGHT_STEP — the authored LOW deck rise.
const LOW_RISE: float = 0.4075
const GRADE: int = 2
const WHEEL_LOCOMOTOR_PATH: String = "res://games/ts/locomotors/Wheel.tres"

const SHORE_A: Vector2i = Vector2i(24, 25)
const DECK_CELLS: Array[Vector2i] = [Vector2i(25, 25), Vector2i(26, 25), Vector2i(27, 25)]
const END_CELL: Vector2i = Vector2i(25, 25)
const NORMAL_CELL: Vector2i = Vector2i(26, 25)
const SHORE_B: Vector2i = Vector2i(28, 25)

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


## Flattens a vertex rectangle to `grade` (raw steps) and invalidates the height
## snapshot so the direct `_vertex_grid` writes are visible.
func _flatten_rect(min_v: Vector2i, max_v: Vector2i, grade: int) -> void:
    for vx in range(min_v.x, max_v.x + 1):
        for vz in range(min_v.y, max_v.y + 1):
            _ts._vertex_grid[vx][vz] = grade
    _ts.invalidate_height_snapshot()


## Flat ground corridor with the middle three cells painted water (the deck's
## ground level). Bridge entities are spawned by each test.
func _reset_corridor() -> void:
    _clear()
    _ts.init_grid(50, 50)
    _ts.clear()
    _sh._bridge_cells.clear()
    _flatten_rect(Vector2i(23, 23), Vector2i(29, 27), GRADE)
    for cell in DECK_CELLS:
        _ts.set_land_type(cell, "water")


func _spawn_span() -> void:
    _spawn("BRIDGE_END", DECK_CELLS[0])
    _spawn("BRIDGE", DECK_CELLS[1])
    _spawn("BRIDGE_END", DECK_CELLS[2])
    _sh.rebuild()


func _path_has_cell(path: PackedVector3Array, cell: Vector2i) -> bool:
    for wp in path:
        if CellUtil.world_to_cell(wp) == cell:
            return true
    return false


func _path_has_level(detailed: Dictionary, level: int) -> bool:
    for lvl in detailed["levels"]:
        if int(lvl) == level:
            return true
    return false


func test_low_overlay_resources_author_half_step_rise():
    var bridge := load("res://games/ts/entities/overlay/bridge.tres") as EntityData
    var end := load("res://games/ts/entities/overlay/bridge_end.tres") as EntityData
    TestHelper.assert_true(bridge != null and end != null, "LOW overlays load")
    if bridge == null or end == null:
        return
    for data: EntityData in [bridge, end]:
        TestHelper.assert_eq(data.bridge_kind, EntityData.BridgeKind.LOW, "LOW kind")
        TestHelper.assert_eq(data.bridge_level, 1, "deck level 1")
        TestHelper.assert_true(
            is_equal_approx(data.bridge_rise, LOW_RISE), "half-step rise authored (0.4075)"
        )
    TestHelper.assert_eq(end.bridge_end, true, "end piece is flagged")
    TestHelper.assert_eq(bridge.bridge_end, false, "normal span piece is not an end")
    TestHelper.assert_true(
        is_equal_approx(LOW_RISE, 0.5 * HEIGHT_STEP), "0.4075 is exactly half a height step"
    )


func test_low_deck_sits_half_step_above_cell_terrain():
    if _ts == null or _sh == null or _ef == null:
        TestHelper.fail("autoloads not injected")
        return
    _reset_corridor()
    _spawn_span()
    var base: float = float(GRADE) * HEIGHT_STEP
    var expected: float = base + LOW_RISE
    TestHelper.assert_true(is_equal_approx(expected, 2.0375), "expected LOW deck height is 2.0375")
    for cell: Vector2i in [END_CELL, NORMAL_CELL]:
        TestHelper.assert_true(
            CellUtil.is_in_diamond(cell, _ts.grid_cells), "fixture cell %s is in the map" % cell
        )
        var data: Dictionary = _sh.get_bridge_cell(cell, 1)
        TestHelper.assert_true(not data.is_empty(), "LOW deck registered at %s" % cell)
        if data.is_empty():
            continue
        TestHelper.assert_true(
            is_equal_approx(float(data["surface_height"]), expected),
            "deck is base + half step at %s" % cell
        )
        TestHelper.assert_true(
            is_equal_approx(_ts.get_cell_surface_height(cell, 1), expected),
            "surface query reads the LOW deck at %s" % cell
        )
        TestHelper.assert_true(
            is_equal_approx(_ts.get_cell_surface_height(cell), base),
            "ground under the LOW deck keeps its own height at %s" % cell
        )
    _clear()


func test_low_deck_keeps_underlying_ground_land():
    if _ts == null or _sh == null or _ef == null:
        TestHelper.fail("autoloads not injected")
        return
    _reset_corridor()
    _spawn_span()
    for cell: Vector2i in DECK_CELLS:
        TestHelper.assert_eq(
            _ts.get_land_type(cell, 1), "road", "level 1 is the deck land at %s" % cell
        )
        TestHelper.assert_eq(
            _ts.get_land_type(cell, 0), "water", "level 0 stays water at %s" % cell
        )
        TestHelper.assert_eq(
            _ts.get_painted_land_type(cell), "water", "painted water survives at %s" % cell
        )
    # Removing the span reverts the deck and leaves the ground land untouched.
    _clear()
    for cell: Vector2i in DECK_CELLS:
        TestHelper.assert_eq(_ts.get_land_type(cell, 1), "", "removed deck leaves no level 1")
        TestHelper.assert_eq(_ts.get_land_type(cell, 0), "water", "ground reverts to water")


func test_wheeled_crosses_low_deck_via_slope_ends():
    if _ts == null or _sh == null or _ef == null:
        TestHelper.fail("autoloads not injected")
        return
    _reset_corridor()
    var wheel := load(WHEEL_LOCOMOTOR_PATH) as Locomotor
    TestHelper.assert_true(wheel != null, "Wheel locomotor loads")
    if wheel == null:
        return
    var start := CellUtil.cell_to_world(SHORE_A)
    var end := CellUtil.cell_to_world(SHORE_B)

    # Control: no bridge -> the wheeled unit cannot use the uncovered water and
    # routes around it to reach the far shore.
    var control: PackedVector3Array = Pathfinder.find_path(start, end, {}, wheel)
    TestHelper.assert_true(control.size() > 0, "control route around the water exists")
    TestHelper.assert_eq(
        CellUtil.world_to_cell(control[control.size() - 1]),
        SHORE_B,
        "control reaches the far shore"
    )
    for cell: Vector2i in DECK_CELLS:
        TestHelper.assert_true(
            not _path_has_cell(control, cell), "control avoids uncovered water at %s" % cell
        )
    for cell: Vector2i in DECK_CELLS:
        TestHelper.assert_eq(_ts.get_land_type(cell, 1), "", "control has no deck at %s" % cell)

    # With the LOW span the slope ends admit ground traffic onto the level-1 deck.
    _spawn_span()
    var detailed: Dictionary = Pathfinder.find_path_detailed(
        start, end, {}, wheel, false, null, _ts, 0, 0
    )
    TestHelper.assert_true(detailed["path"].size() > 0, "bridge route exists")
    TestHelper.assert_true(_path_has_level(detailed, 1), "route uses the deck level")
    for cell: Vector2i in DECK_CELLS:
        TestHelper.assert_true(
            _path_has_cell(detailed["path"], cell), "route crosses deck cell %s" % cell
        )
    var base: float = float(GRADE) * HEIGHT_STEP
    for i in detailed["path"].size():
        var wp: Vector3 = detailed["path"][i]
        if CellUtil.world_to_cell(wp) in DECK_CELLS:
            TestHelper.assert_eq(int(detailed["levels"][i]), 1, "waypoint %d is on the deck" % i)
            TestHelper.assert_true(
                is_equal_approx(wp.y, base + LOW_RISE),
                "deck waypoint %d follows the deck height" % i
            )
    _clear()


func test_low_destructibility_split():
    if _ts == null or _sh == null or _ef == null:
        TestHelper.fail("autoloads not injected")
        return
    _reset_corridor()
    var end_piece := _spawn("BRIDGE_END", END_CELL)
    var normal_piece := _spawn("BRIDGE", NORMAL_CELL)
    _sh.rebuild()
    TestHelper.assert_true(_sh.has_bridge_on_cell(END_CELL, 1), "end deck registered")
    TestHelper.assert_true(_sh.has_bridge_on_cell(NORMAL_CELL, 1), "normal deck registered")
    if end_piece == null or normal_piece == null:
        _clear()
        return
    var end_comp := end_piece.get_node_or_null("BridgeComponent")
    var normal_comp := normal_piece.get_node_or_null("BridgeComponent")
    var end_health := end_piece.get_node_or_null("HealthComponent") as HealthComponent
    var normal_health := normal_piece.get_node_or_null("HealthComponent") as HealthComponent
    TestHelper.assert_true(end_comp != null and normal_comp != null, "both pieces have components")
    TestHelper.assert_true(end_health != null and normal_health != null, "both pieces have health")
    if end_health == null or normal_health == null:
        _clear()
        return

    # A LOW normal piece is destructible: health_zero reverts its deck.
    normal_health.kill()
    _sh.rebuild()
    TestHelper.assert_true(normal_comp._destroyed, "normal piece hooked the destruction revert")
    TestHelper.assert_eq(
        _sh.has_bridge_on_cell(NORMAL_CELL, 1), false, "destroyed normal piece leaves the registry"
    )
    TestHelper.assert_eq(_ts.get_land_type(NORMAL_CELL, 1), "", "normal cell loses its deck")
    TestHelper.assert_eq(
        _ts.get_land_type(NORMAL_CELL, 0), "water", "normal cell reverts to underlying water"
    )

    # A LOW end piece is indestructible: the hook is never connected.
    end_health.kill()
    _sh.rebuild()
    TestHelper.assert_true(
        _sh.has_bridge_on_cell(END_CELL, 1), "killed end piece stays in the registry"
    )
    TestHelper.assert_eq(_ts.get_land_type(END_CELL, 1), "road", "end deck still resolves")
    TestHelper.assert_eq(end_comp._destroyed, false, "end piece never hooked the revert")
    _clear()
