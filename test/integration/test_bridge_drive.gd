extends Node

# Bridge drive integration — a wheeled vehicle is ordered from one shore across a
# high-bridge span over water and stops on the far shore. The per-frame harness
# drives the real MovementController physics tick (no faked teleport): the
# produced path must cross every bridge cell, the driven Y on each bridge cell
# must equal TerrainSystem.get_cell_surface_height (the walkable deck), and the
# drive must end idle on the far shore.
#
# The fixture flattens the whole strip one grade step and authors the high bridge
# with a one-step rise so the deck is exactly one climb step above the shore —
# drivable at Wheel's climb_tolerance of 1 while still observably above the water
# terrain beneath.

const WHEEL_LOCOMOTOR_PATH: String = "res://games/ts/locomotors/Wheel.tres"
const START_CELL: Vector2i = Vector2i(19, 20)
const FAR_CELL: Vector2i = Vector2i(23, 20)
const WATER_CELLS: Array[Vector2i] = [Vector2i(20, 20), Vector2i(21, 20), Vector2i(22, 20)]
const BASE_GRADE: int = 1
const BRIDGE_RISE_STEPS: float = 1.0
const DRIVE_DT: float = 1.0 / 60.0
const MAX_DRIVE_FRAMES: int = 1800
const SETTLE_FRAMES: int = 4

var _ts: Node = null
var _sh: Node = null
var _ef: Node = null
var _bridges: Array[Node3D] = []


## Flattens a vertex rectangle to `grade` (raw steps), matching the direct
## `_vertex_grid` edit + snapshot invalidation the other bridge fixtures use.
func _flatten_rect(min_v: Vector2i, max_v: Vector2i, grade: int) -> void:
    for vx in range(min_v.x, max_v.x + 1):
        for vz in range(min_v.y, max_v.y + 1):
            _ts._set_vertex_no_cascade(vx, vz, grade)
    _ts.invalidate_height_snapshot()


func _spawn_bridges(rise: float) -> void:
    var root: Node = Engine.get_main_loop().root
    for cell in WATER_CELLS:
        var bridge: Node3D = _ef.create_entity("BRIDGE_HIGH", {"bridge_rise": rise})
        if bridge == null:
            continue
        root.add_child(bridge)
        bridge.global_position = CellUtil.cell_to_world(cell)
        _bridges.append(bridge)


func _make_vehicle() -> Array:
    var root: Node = Engine.get_main_loop().root
    var entity := Node3D.new()
    entity.name = "BridgeDriveVehicle"
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.entity_type = EntityData.EntityType.VEHICLE
    stats.player_id = 0
    stats.weight = 3.0
    entity.add_child(stats)
    var mc := MovementController.new()
    mc.name = "MovementController"
    entity.add_child(mc)
    mc._parent = entity
    root.add_child(entity)
    return [entity, mc]


func _path_cells(path: PackedVector3Array) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for wp in path:
        cells.append(CellUtil.world_to_cell(wp))
    return cells


## Deck level the produced path reports for `cell`, or -1 when the cell is not on
## the path. Proves the route is planned on the deck surface, not merely over its
## cell center.
func _path_level_for_cell(
    path: PackedVector3Array, levels: PackedInt32Array, cell: Vector2i
) -> int:
    for i in path.size():
        if CellUtil.world_to_cell(path[i]) == cell:
            return levels[i] if i < levels.size() else 0
    return -1


func test_wheeled_vehicle_drives_across_high_bridge_deck() -> void:
    if _ts == null or _sh == null or _ef == null:
        TestHelper.fail("autoloads not injected")
        return
    _ts.init_grid(50, 50)
    _ts.clear()
    # Flat shore + water strip, one grade step, so the bridge is drivable at the
    # climb boundary without any raised-shore vertex leak.
    _flatten_rect(Vector2i(19, 19), Vector2i(24, 22), BASE_GRADE)
    for cell in WATER_CELLS:
        _ts.set_land_type(cell, "water")
    var base_height: float = float(BASE_GRADE) * _ts.HEIGHT_STEP
    var deck_height: float = base_height + BRIDGE_RISE_STEPS * _ts.HEIGHT_STEP
    _spawn_bridges(BRIDGE_RISE_STEPS * _ts.HEIGHT_STEP)
    _sh.rebuild()

    var pair := _make_vehicle()
    var vehicle: Node3D = pair[0] as Node3D
    var mc: MovementController = pair[1] as MovementController
    mc._locomotor_data = load(WHEEL_LOCOMOTOR_PATH) as Locomotor
    vehicle.global_position = CellUtil.cell_to_world(START_CELL)
    vehicle.global_position.y = base_height

    mc.set_target_position(CellUtil.cell_to_world(FAR_CELL))
    TestHelper.assert_true(
        mc._state != MovementController.State.IDLE, "vehicle accepted the move order"
    )
    var path_cells := _path_cells(mc._waypoints)
    for cell in WATER_CELLS:
        TestHelper.assert_true(path_cells.has(cell), "produced path crosses bridge cell %s" % cell)
    # The route must be planned on the level-1 deck, not the level-0 ground/water
    # beneath it — a level-0 crossing would be refused for a wheeled unit.
    for cell in WATER_CELLS:
        (
            TestHelper
            . assert_eq(
                _path_level_for_cell(mc._waypoints, mc._waypoint_levels, cell),
                1,
                "produced path carries the deck level at %s" % cell,
            )
        )

    # Drive the real physics tick. Track the Y error per bridge cell, keeping the
    # last (most settled) sample from each cell because the deck is entered from
    # a lower grade and the vertical snap lerps over a few frames.
    var frames_on_cell: Dictionary = {}
    var settled_error: Dictionary = {}
    var frames := 0
    while frames < MAX_DRIVE_FRAMES and mc._state != MovementController.State.IDLE:
        mc._physics_process(DRIVE_DT)
        frames += 1
        var cell := CellUtil.world_to_cell(vehicle.global_position)
        if not _sh.has_bridge_on_cell(cell, 1):
            continue
        frames_on_cell[cell] = int(frames_on_cell.get(cell, 0)) + 1
        if int(frames_on_cell[cell]) < SETTLE_FRAMES:
            continue
        var error: float = absf(vehicle.global_position.y - _ts.get_cell_surface_height(cell, 1))
        settled_error[cell] = error

    TestHelper.assert_true(
        frames < MAX_DRIVE_FRAMES, "vehicle completed the drive within the frame budget"
    )
    TestHelper.assert_eq(mc._state, MovementController.State.IDLE, "vehicle stopped")
    for cell in WATER_CELLS:
        TestHelper.assert_true(settled_error.has(cell), "vehicle drove onto bridge cell %s" % cell)
    var worst_error := 0.0
    for cell in settled_error:
        worst_error = maxf(worst_error, float(settled_error[cell]))
    TestHelper.assert_true(
        worst_error < 0.05, "driven Y follows the bridge deck (worst error %.4f)" % worst_error
    )

    var final_cell := CellUtil.world_to_cell(vehicle.global_position)
    TestHelper.assert_eq(final_cell, FAR_CELL, "vehicle stopped on the far shore")
    (
        TestHelper
        . assert_true(
            is_equal_approx(vehicle.global_position.y, base_height),
            "far-shore Y matches the shore grade",
        )
    )
    # The deck is one step above the water terrain beneath, so following the deck
    # (not the terrain sample) is observable. The deck lives at level 1; level 0
    # keeps the water's own ground height.
    var mid: Vector2i = WATER_CELLS[1]
    (
        TestHelper
        . assert_true(
            is_equal_approx(_ts.get_cell_surface_height(mid, 1), deck_height),
            "high deck sits one rise above the cell's base grade",
        )
    )
    (
        TestHelper
        . assert_true(
            (
                _ts.get_cell_surface_height(mid, 1)
                > _ts.get_height_at_world_smooth(CellUtil.cell_to_world(mid))
            ),
            "bridge deck is elevated above the water terrain beneath",
        )
    )
    (
        TestHelper
        . assert_true(
            is_equal_approx(_ts.get_cell_surface_height(mid, 0), base_height),
            "level 0 under the deck keeps the water's ground height",
        )
    )

    _teardown(pair)


func _teardown(pair: Array) -> void:
    var root: Node = Engine.get_main_loop().root
    if pair.size() == 2:
        var vehicle: Node = pair[0] as Node
        if is_instance_valid(vehicle):
            root.remove_child(vehicle)
            vehicle.free()
    for bridge in _bridges:
        if is_instance_valid(bridge):
            root.remove_child(bridge)
            bridge.free()
    _bridges.clear()
    if _sh != null:
        _sh.rebuild()
    if CellReservation.instance:
        CellReservation.instance.clear()
    if _ts != null:
        _ts.init_grid(50, 50)
        _ts.clear()
