class_name MovementController extends Node3D

signal arrived(position: Vector3)
signal movement_started
signal pathfinding_failed

enum State { IDLE, ROTATING, MOVING, WAIT }
enum VerticalState { GROUND, ASCENDING, AIR, DESCENDING }

@export_group("Movement")
@export var move_speed: float = 8.0
@export var cell_radius: float = 1.0
@export var rotation_speed: float = 180.0
@export_range(1.0, 45.0) var rotation_angle_threshold: float = 5.0
@export_node_path("MeshInstance3D") var rotation_target_path: NodePath
@export var debug_show_path: bool = false
@export var locomotor: String = ""
@export var movement_zone: String = ""

const REPULSION_STRENGTH: float = 0.1

## Locomotor id for tracked vehicles (rules.ini [General] TrackedUphill/Downhill).
const LOCOMOTOR_TRACK: String = "Track"

## Timing thresholds in seconds, derived from the frame counts they replaced at 60 FPS.
## Delta-accumulated, so they stay frame-rate independent and scale with game speed.
const REPAIR_INTERVAL: float = 10.0 / 60.0
const WAIT_SCATTER_SECONDS: float = 15.0 / 60.0
const WAIT_MIN_SECONDS: float = 10.0 / 60.0
const WAIT_MAX_SECONDS: float = 25.0 / 60.0

static var _scattered_this_frame: Dictionary = {}
static var _last_physics_frame: int = -1

var _state: State = State.IDLE
var _vertical_state: VerticalState = VerticalState.GROUND
var _waypoints: PackedVector3Array = PackedVector3Array()
var _spline_t: float = 0.0
var _rotation_target: Node3D
var _parent: Node3D
var _wait_time: float = 0.0
var _wait_threshold: float = 1.0
var _repair_time: float = 0.0
var _speed_jitter: float = 1.0
var _rotation_yaw: float = 0.0

var _is_infantry: bool = false
var _crusher: bool = false
var _player_id: int = -1
var _assigned_slot: int = -1
var _sub_slot_position: Vector3 = Vector3.ZERO
var _has_sub_slot: bool = false
var _last_position: Vector3 = Vector3.ZERO
var _veteran_speed_mult: float = 1.0
var _rules: GlobalRules = null
var _locomotor_data: Locomotor = null
var _hover_height: float = 0.0
var _jumpjet_air_height: float = 0.0
var _is_hover: bool = false
var _is_jumpjet: bool = false
var _is_subterranean: bool = false
var _hybrid_active: bool = false
var _land_on_arrival: bool = false
var _ice_cracking_weight: float = 2.0
var _weight: float = 1.0


func configure(data: EntityData) -> void:
    locomotor = data.locomotor
    movement_zone = data.movement_zone


func _ready() -> void:
    _parent = get_parent() as Node3D
    _resolve_rotation_target()
    _speed_jitter = randf_range(0.95, 1.0)
    _wait_threshold = randf_range(WAIT_MIN_SECONDS, WAIT_MAX_SECONDS)
    _rules = GlobalRules.get_current()
    var stats := _parent.get_node_or_null("StatsComponent") as StatsComponent
    if stats:
        _is_infantry = stats.entity_type == EntityData.EntityType.INFANTRY
        _crusher = stats.crusher
        _player_id = stats.player_id
        _weight = stats.weight
        _veteran_speed_mult = _get_veteran_speed_mult(stats.veteran_level)
    _resolve_locomotor()


func _resolve_locomotor() -> void:
    if not _rules or locomotor.is_empty():
        return
    _locomotor_data = _rules.get_locomotor(locomotor)
    if _locomotor_data == null:
        push_error("[MovementController] Unknown locomotor: %s" % locomotor)
        return
    _is_hover = _locomotor_data.is_hover
    _is_jumpjet = _locomotor_data.is_jumpjet
    _is_subterranean = _locomotor_data.is_subterranean
    if _locomotor_data.hover_height_override > 0.0:
        _hover_height = _locomotor_data.hover_height_override
    else:
        _hover_height = float(_rules.hover_height) * (CellUtil.CELL_SIZE / 256.0)
    _jumpjet_air_height = _locomotor_data.jumpjet_target_height * TerrainSystem.HEIGHT_STEP
    _ice_cracking_weight = _rules.ice_cracking_weight


func _get_veteran_speed_mult(veteran_level: int) -> float:
    if veteran_level <= 0:
        return 1.0
    if not _rules:
        return 1.0
    return _rules.get_veteran_speed_multiplier(veteran_level)


func _slope_coefficient() -> float:
    if not _rules or _is_hover:
        return 1.0
    var uphill: float
    var downhill: float
    match locomotor:
        LOCOMOTOR_TRACK:
            uphill = _rules.tracked_uphill
            downhill = _rules.tracked_downhill
        "Wheel":
            uphill = _rules.wheeled_uphill
            downhill = _rules.wheeled_downhill
        _:
            return 1.0
    if _waypoints.size() < 2:
        return 1.0
    var seg := _spline_segment()
    var next_idx := mini(seg + 1, _waypoints.size() - 1)
    var probe := CellUtil.cell_to_world(CellUtil.world_to_cell(_waypoints[next_idx]))
    var height_ahead := TerrainSystem.get_height_at_world_smooth(probe)
    var height_now := TerrainSystem.get_height_at_world_smooth(_parent.global_position)
    var grade := height_ahead - height_now
    if absf(grade) < 0.05:
        return 1.0
    return uphill if grade > 0.0 else downhill


func _terrain_speed_factor() -> float:
    if not _locomotor_data or _locomotor_data.is_fly:
        return 1.0
    if _is_jumpjet and _vertical_state != VerticalState.GROUND:
        return 1.0
    var cell := CellUtil.world_to_cell(_parent.global_position)
    return _locomotor_data.get_speed_multiplier(TerrainSystem.get_land_type(cell))


func _is_floating() -> bool:
    if _is_hover:
        return true
    return _is_jumpjet and _vertical_state != VerticalState.GROUND


## Split factor while a jumpjet vertically transitions (ascend/descend) at the
## same time as moving forward: each axis gets 50% of move_speed. Pure vertical
## transitions (idle landing) keep full speed.
func _vertical_split_factor() -> float:
    if not _is_jumpjet:
        return 1.0
    if _vertical_state != VerticalState.ASCENDING and _vertical_state != VerticalState.DESCENDING:
        return 1.0
    if _state == State.IDLE:
        return 1.0
    return 0.5


func is_airborne_jumpjet() -> bool:
    return _is_jumpjet and _vertical_state != VerticalState.GROUND


func _num_segments() -> int:
    return maxi(0, _waypoints.size() - 1)


func is_moving() -> bool:
    return _state != State.IDLE


func get_assigned_slot() -> int:
    return _assigned_slot


func stop() -> void:
    if _state == State.IDLE:
        return
    if _state == State.ROTATING:
        _finish_stop()
        return
    if _state == State.WAIT:
        var final_pos := _waypoints[_waypoints.size() - 1]
        var dist := _parent.global_position.distance_to(final_pos)
        if dist < 0.1:
            var final_cell := CellUtil.world_to_cell(final_pos)
            if not _is_cell_occupied_by_idle(final_cell):
                _finish_stop()
                return
    if _state == State.MOVING:
        var seg := _spline_segment()
        var next_idx := mini(seg + 1, _waypoints.size() - 1)
        var next_waypoint := _waypoints[next_idx]
        if _is_infantry and not (_is_jumpjet and _vertical_state != VerticalState.GROUND):
            var current_cell := CellUtil.world_to_cell(_parent.global_position)
            _assign_sub_slot_at_cell(current_cell)
            if _has_sub_slot:
                next_waypoint = _sub_slot_position
            else:
                var free_cell := CellUtil.spiral_first_free(
                    current_cell, 3, _is_cell_occupied_by_idle
                )
                _assign_sub_slot_at_cell(free_cell)
                if _has_sub_slot:
                    next_waypoint = _sub_slot_position
                else:
                    next_waypoint = CellUtil.cell_to_world(free_cell)
        else:
            var dist_to_next := (next_waypoint - _parent.global_position).length()
            if dist_to_next > CellUtil.CELL_SIZE:
                var dir := (next_waypoint - _parent.global_position).normalized()
                var candidate := _parent.global_position + dir * CellUtil.CELL_SIZE
                var candidate_cell := CellUtil.world_to_cell(candidate)
                var current_cell := CellUtil.world_to_cell(_parent.global_position)
                if candidate_cell != current_cell:
                    next_waypoint = CellUtil.cell_to_world(candidate_cell)
        _waypoints = PackedVector3Array([_parent.global_position, next_waypoint])
        _spline_t = 0.0


func _finish_stop() -> void:
    _waypoints = PackedVector3Array()
    _spline_t = 0.0
    _has_sub_slot = false
    _hybrid_active = false
    _land_on_arrival = false
    _state = State.IDLE
    SpatialHash.instance.release_cell(CellUtil.world_to_cell(_parent.global_position))
    CellReservation.instance.release_all(_parent)
    if debug_show_path:
        DebugVisualizer.clear_path(get_path())


## Cancels an airborne jumpjet's current move without losing its air zone, so a
## new order (e.g. an attack) resumes from the air instead of landing first.
func cancel_move_retain_vertical() -> void:
    if not is_airborne_jumpjet():
        return
    if _state != State.IDLE:
        _finish_stop()


## `internal` marks re-targets issued by this controller itself (repair,
## blocked-arrival settle, wait scatter, nudges) rather than new player orders;
## those do not emit `movement_started`.
func set_target_position(
    target: Vector3,
    unblock_buildings: bool = false,
    keep_zone: bool = false,
    internal: bool = false,
) -> void:
    if (
        is_nan(target.x)
        or is_nan(target.y)
        or is_nan(target.z)
        or not is_finite(target.x)
        or not is_finite(target.y)
        or not is_finite(target.z)
    ):
        printerr("[MovementController] Ignoring invalid target position: ", target)
        return

    if not internal:
        movement_started.emit()

    var target_cell := CellUtil.world_to_cell(target)

    # Jumpjet flight decision before any ground booking: fly when airborne,
    # when attacking from the air, or when the target is far; otherwise walk
    # on the ground like infantry (default zone GROUND).
    var fly_move := false
    if _is_jumpjet and _locomotor_data:
        if keep_zone:
            fly_move = _vertical_state != VerticalState.GROUND
        elif _vertical_state != VerticalState.GROUND:
            fly_move = true
        else:
            var fly_dist := _parent.global_position.distance_to(target)
            var fly_threshold: float = _locomotor_data.jumpjet_fly_distance
            fly_move = fly_threshold > 0.0 and fly_dist > fly_threshold

    var path: PackedVector3Array
    var blocked: Dictionary = {}
    var hybrid_fallback := false

    if fly_move:
        # Air move: straight line to the target, no path-cell booking. When the
        # move will land (not keep_zone), reserve a sub-slot at the landing cell
        # so the jumpjet descends onto a sub-slot instead of the cell center.
        _has_sub_slot = false
        hybrid_fallback = true
        if _is_infantry and not keep_zone:
            # Never fly into an occupied landing cell: relocate up front, like
            # the ground branch, before booking so arrival is clean.
            if _is_cell_occupied_by_idle(target_cell):
                var free := _find_nearest_free_cell(target_cell)
                target = CellUtil.cell_to_world(free)
                target_cell = free
            _assign_sub_slot_at_cell(target_cell)
            if not _has_sub_slot:
                var free_cell := _find_nearest_free_sub_slot_cell(target_cell)
                _assign_sub_slot_at_cell(free_cell)
                if _has_sub_slot:
                    target = _sub_slot_position
            else:
                target = _sub_slot_position
        # `target` is the exact stop position (clamped attack approach) or the
        # booked landing sub-slot; both are single straight-line fly segments.
        path = PackedVector3Array([target])
    else:
        # Ground move: normal infantry booking, then walk pathfinding.
        if _is_cell_occupied_by_idle(target_cell):
            var free := _find_nearest_free_cell(target_cell)
            target = CellUtil.cell_to_world(free)
            target_cell = free
        if _is_infantry:
            _assign_sub_slot_at_cell(target_cell)
            if not _has_sub_slot:
                var free_cell := _find_nearest_free_sub_slot_cell(target_cell)
                _assign_sub_slot_at_cell(free_cell)
                target_cell = free_cell
                if _has_sub_slot:
                    target = _sub_slot_position
            else:
                target = _sub_slot_position

        blocked = _build_blocked_cells(unblock_buildings)
        path = Pathfinder.find_path(_parent.global_position, target, blocked, _locomotor_data)

        if _is_jumpjet and _locomotor_data:
            if path.is_empty():
                var same_cell := (
                    CellUtil.world_to_cell(_parent.global_position)
                    == CellUtil.world_to_cell(target)
                )
                if same_cell:
                    # Already at the target cell: settle into the sub-slot on
                    # the ground instead of taking off.
                    path = PackedVector3Array([target])
                else:
                    # Unreachable on foot: fly straight to the target, then land.
                    hybrid_fallback = true
                    path = PackedVector3Array([target])
        elif _is_subterranean and _locomotor_data:
            var dig_dist := _parent.global_position.distance_to(target)
            var dig_threshold: float = _locomotor_data.subterranean_dig_distance
            if path.is_empty() or (dig_threshold > 0.0 and dig_dist > dig_threshold):
                hybrid_fallback = true
                path = PackedVector3Array([target])

    if _is_jumpjet:
        if _vertical_state == VerticalState.DESCENDING:
            hybrid_fallback = true
        var desired_zone: VerticalState = (
            VerticalState.AIR if hybrid_fallback else VerticalState.GROUND
        )
        _apply_zone_desire(desired_zone)

    _land_on_arrival = _is_jumpjet and hybrid_fallback and not keep_zone
    _hybrid_active = hybrid_fallback

    if path.is_empty():
        _scatter_blockers()
        pathfinding_failed.emit()
        return

    if _is_infantry and path.size() > 2 and not hybrid_fallback:
        path = Pathfinder.smooth_path(path, blocked)

    if _is_infantry and _has_sub_slot and path.size() > 0 and not hybrid_fallback:
        path[path.size() - 1] = _sub_slot_position
    if _is_infantry and path.size() > 1 and not hybrid_fallback:
        for i in range(0, path.size() - 1):
            var wp_cell := CellUtil.world_to_cell(path[i])
            var wp_positions := CellSubPositions.get_sub_positions(wp_cell)
            var offset_idx := CellUtil.cell_key(wp_cell) % wp_positions.size()
            path[i] = path[i] + wp_positions[offset_idx]

    var full_path: PackedVector3Array = [_parent.global_position]
    full_path.append_array(path)

    for i in range(1, full_path.size()):
        full_path[i].y = TerrainSystem.get_height_at_world_smooth(full_path[i])

    _waypoints = full_path
    _spline_t = 0.0
    _wait_time = 0.0
    _repair_time = 0.0
    _last_position = _parent.global_position
    if is_instance_valid(_rotation_target):
        _rotation_yaw = _rotation_target.global_rotation.y
    if _is_infantry:
        _state = State.MOVING
        if is_instance_valid(_rotation_target) and _waypoints.size() > 1:
            var tangent := (_waypoints[1] - _waypoints[0]).normalized()
            var target_yaw := atan2(-tangent.x, -tangent.z)
            _rotation_yaw = target_yaw
            _apply_facing(Vector3(-sin(target_yaw), 0.0, -cos(target_yaw)))
    else:
        _state = State.ROTATING
    if debug_show_path:
        DebugVisualizer.draw_path(get_path(), _parent.global_position, _waypoints, 0)


func _resolve_rotation_target() -> void:
    if not rotation_target_path.is_empty():
        var resolved := get_node(rotation_target_path) as Node3D
        if is_instance_valid(resolved):
            _rotation_target = resolved

    if not is_instance_valid(_rotation_target):
        _rotation_target = _parent


func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return

    var frame := Engine.get_process_frames()
    if frame != _last_physics_frame:
        _last_physics_frame = frame
        _scattered_this_frame.clear()

    match _state:
        State.ROTATING:
            _handle_rotating(delta)
        State.MOVING:
            _handle_moving_movement(delta)
        State.WAIT:
            _handle_wait(delta)
        State.IDLE:
            if _is_jumpjet:
                _update_vertical(delta)
            else:
                var idle_y := TerrainSystem.get_height_at_world_smooth(_parent.global_position)
                _parent.global_position.y = idle_y + (_hover_height if _is_floating() else 0.0)


func _handle_rotating(delta: float) -> void:
    if not is_instance_valid(_rotation_target):
        _state = State.MOVING
        return

    var tangent := _get_spline_tangent(_spline_t)
    if tangent.length() < 0.01:
        _state = State.MOVING
        return

    var target_yaw := atan2(-tangent.x, -tangent.z)
    var step := deg_to_rad(rotation_speed) * delta

    if (
        abs(angle_difference(_rotation_yaw, target_yaw))
        < max(step, deg_to_rad(rotation_angle_threshold))
    ):
        _spline_t = 0.001
        _state = State.MOVING
    else:
        _rotation_yaw += sign(angle_difference(_rotation_yaw, target_yaw)) * step
        _apply_facing(Vector3(-sin(_rotation_yaw), 0.0, -cos(_rotation_yaw)))


func _handle_moving_movement(delta: float) -> void:
    var seg := _spline_segment()
    var seg_begin := _get_spline_pos(float(seg))
    var seg_end := _get_spline_pos(float(seg + 1))
    var seg_length := seg_begin.distance_to(seg_end)
    # Floating units move horizontally while their Y is owned by the vertical
    # state machine (`_update_vertical` / hover float). Using the 3D segment
    # length here would let `_spline_t` reach the path end after travelling more
    # horizontal distance than the destination needs — overshooting past the
    # stop and then gliding back (the "bounce"). Measure on the XZ plane instead.
    if _is_floating():
        seg_length = Vector2(seg_begin.x - seg_end.x, seg_begin.z - seg_end.z).length()
    if seg_length < 0.01:
        seg_length = 0.01

    if seg + 1 < _waypoints.size() - 1:
        _repair_time += delta
        if _repair_time >= REPAIR_INTERVAL:
            _repair_time = 0.0
            var next_cell := CellUtil.world_to_cell(_waypoints[seg + 1])
            if (
                not (_is_jumpjet and _vertical_state != VerticalState.GROUND)
                and _is_cell_occupied_by_idle(next_cell)
            ):
                set_target_position(
                    _waypoints[_waypoints.size() - 1], false, not _land_on_arrival, true
                )
                return

    var parent_pos := _parent.global_position
    var spline_dir := _get_spline_tangent(_spline_t)
    spline_dir.y = 0.0
    spline_dir = spline_dir.normalized()
    var direction := spline_dir

    var final_pos := _waypoints[_waypoints.size() - 1]
    var dist_to_final := parent_pos.distance_to(final_pos)
    var repulsion_weight := clampf(dist_to_final / (cell_radius * 4.0), 0.0, 1.0)

    var parent_cell := CellUtil.world_to_cell(parent_pos)
    var min_neighbor_dist_ahead: float = INF

    for dx in range(-1, 2):
        for dz in range(-1, 2):
            for entry in SpatialHash.instance.get_entries(parent_cell + Vector2i(dx, dz)):
                var entity_parent := entry.node as Node3D
                if not is_instance_valid(entity_parent) or entity_parent == _parent:
                    continue

                var mc := entry.mc as MovementController
                if not mc or mc._state == State.IDLE:
                    continue

                if _is_infantry and mc._is_infantry:
                    continue

                var neighbor_dist: float = parent_pos.distance_to(entity_parent.global_position)
                var to_neighbor := (entity_parent.global_position - parent_pos).normalized()
                if to_neighbor.dot(spline_dir) > 0.0 and neighbor_dist < min_neighbor_dist_ahead:
                    min_neighbor_dist_ahead = neighbor_dist

                if neighbor_dist < cell_radius * 2.0 and neighbor_dist > 0.01:
                    var push_away: Vector3 = (
                        (parent_pos - entity_parent.global_position).normalized()
                        / squaref(neighbor_dist)
                    )
                    direction += push_away * REPULSION_STRENGTH * repulsion_weight

    var speed_factor: float = 1.0
    if min_neighbor_dist_ahead < INF:
        var t := clampf(min_neighbor_dist_ahead / (cell_radius * 1.5), 0.0, 1.0)
        speed_factor = 0.3 + 0.7 * smoothstep(0.0, 1.0, t)
    var deviation := (direction - spline_dir).limit_length(0.3 * repulsion_weight)
    var final_direction := (spline_dir + deviation).normalized()

    if is_instance_valid(_rotation_target):
        _apply_facing(Vector3(final_direction.x, 0.0, final_direction.z).normalized())

    var step := (
        final_direction
        * move_speed
        * _vertical_split_factor()
        * _speed_jitter
        * speed_factor
        * _veteran_speed_mult
        * _slope_coefficient()
        * _terrain_speed_factor()
        * delta
    )
    _spline_t += step.length() / seg_length

    if _spline_t >= float(_num_segments()):
        _spline_t = float(_num_segments())
        var final_cell := CellUtil.world_to_cell(final_pos)
        # An airborne attack hold hovers at its in-range stop position regardless
        # of what occupies the ground cell below — re-targeting would push it off
        # the range circle and make it bounce back. Only landing moves (and ground
        # movers) re-target off a blocked cell.
        var airborne_hold := is_airborne_jumpjet() and not _land_on_arrival
        if not airborne_hold and _is_cell_occupied_by_idle(final_cell):
            if _is_jumpjet:
                # A jumpjet can fly: don't freeze waiting for the cell to clear,
                # glide to the nearest free cell instead (keeping its zone intent).
                var free_cell := _find_nearest_free_cell(final_cell)
                set_target_position(
                    CellUtil.cell_to_world(free_cell), false, not _land_on_arrival, true
                )
            else:
                _state = State.WAIT
            return

        var approach_direction := (final_pos - _parent.global_position).normalized()
        var approach_step := (final_pos - _parent.global_position).limit_length(
            (
                move_speed
                * _vertical_split_factor()
                * _veteran_speed_mult
                * _slope_coefficient()
                * _terrain_speed_factor()
                * delta
            )
        )
        # Jumpjets hover above terrain, so arrival is measured on the XZ plane.
        var arrival_dist: float = (
            Vector2(approach_step.x, approach_step.z).length()
            if _is_jumpjet
            else approach_step.length()
        )
        if arrival_dist < 0.001:
            if not _is_jumpjet:
                _parent.global_position.y = TerrainSystem.get_height_at_world_smooth(
                    _parent.global_position
                )
            if _is_jumpjet and _land_on_arrival and _vertical_state != VerticalState.GROUND:
                _vertical_state = VerticalState.DESCENDING
            _has_sub_slot = false
            _hybrid_active = false
            _state = State.IDLE
            # ponytail: no _claim_sub_slot() here — sub-slot is determined at
            # movement start in set_target_position(). Snapping on arrival is
            # visually broken.
            SpatialHash.instance.release_cell(CellUtil.world_to_cell(_parent.global_position))
            CellReservation.instance.release_all(_parent)
            if debug_show_path:
                DebugVisualizer.clear_path(get_path())
            arrived.emit(_parent.global_position)
        else:
            _parent.global_position += Vector3(approach_step.x, 0.0, approach_step.z)
            _snap_to_terrain(delta)
    else:
        _parent.global_position += step
        var skip_lerp := (
            _is_infantry and (_spline_segment() == 0 or _spline_segment() >= _num_segments() - 1)
        )
        if not skip_lerp:
            var spline_pos := _get_spline_pos(_spline_t)
            var lerped := _parent.global_position.lerp(spline_pos, 0.2)
            _parent.global_position = Vector3(lerped.x, _parent.global_position.y, lerped.z)
        _snap_to_terrain(delta)

    var new_cell := CellUtil.world_to_cell(_parent.global_position)
    var old_cell := CellUtil.world_to_cell(_last_position)
    if new_cell != old_cell:
        _damage_ice(new_cell)
        if _crusher:
            _try_crush(new_cell)
    _last_position = _parent.global_position


func _handle_wait(delta: float) -> void:
    _wait_time += delta
    if _is_jumpjet:
        _update_vertical(delta)

    # Fire the mid-wait scatter once, on the tick that crosses the threshold.
    if _wait_time >= WAIT_SCATTER_SECONDS and _wait_time - delta < WAIT_SCATTER_SECONDS:
        _scatter_blockers()

    if _wait_time > _wait_threshold:
        _wait_time = 0.0
        _scatter_blockers()
        var target_cell := CellUtil.world_to_cell(_waypoints[_waypoints.size() - 1])
        var free_cell := _find_nearest_free_cell(target_cell)
        # Keep the move's zone intent: an attack hold stays airborne, a landing
        # move still lands.
        set_target_position(
            CellUtil.cell_to_world(free_cell), false, _is_jumpjet and not _land_on_arrival, true
        )
        return

    var final_cell := CellUtil.world_to_cell(_waypoints[_waypoints.size() - 1])
    if not _is_cell_occupied_by_idle(final_cell):
        var cell_center := CellUtil.cell_to_world(final_cell)
        var wait_target := _sub_slot_position if _has_sub_slot else cell_center
        if _is_jumpjet:
            _parent.global_position.x = lerpf(_parent.global_position.x, wait_target.x, 0.3)
            _parent.global_position.z = lerpf(_parent.global_position.z, wait_target.z, 0.3)
        else:
            _parent.global_position = _parent.global_position.lerp(wait_target, 0.3)
        var wait_arrival_dist: float = (
            (
                Vector2(
                    _parent.global_position.x - wait_target.x,
                    _parent.global_position.z - wait_target.z,
                )
                . length()
            )
            if _is_jumpjet
            else _parent.global_position.distance_to(wait_target)
        )
        if wait_arrival_dist < 0.05:
            if not _is_jumpjet:
                _parent.global_position = wait_target
            if _is_jumpjet and _land_on_arrival and _vertical_state != VerticalState.GROUND:
                _vertical_state = VerticalState.DESCENDING
            _has_sub_slot = false
            _hybrid_active = false
            _state = State.IDLE
            # ponytail: no _claim_sub_slot() here — sub-slot is determined at
            # movement start in set_target_position(). Snapping on arrival is
            # visually broken.
            SpatialHash.instance.release_cell(final_cell)
            CellReservation.instance.release_all(_parent)
            if debug_show_path:
                DebugVisualizer.clear_path(get_path())
            arrived.emit(_parent.global_position)
        return


func squaref(v: float) -> float:
    return v * v


func _try_crush(cell: Vector2i) -> void:
    var enemies: Array = SpatialHash.instance.get_crushable_enemies_on_cell(cell, _player_id)
    for enemy in enemies:
        if not is_instance_valid(enemy):
            continue
        var hc := (enemy as Node3D).get_node_or_null("HealthComponent") as HealthComponent
        if hc:
            hc.kill()


## One-time weight-based damage to breakable surfaces (ice) on cell entry.
## Units below the cracking threshold deal none, and floating units (hover,
## jumpjet flight) do not touch the surface. Damage is per entry, not per tick.
func _damage_ice(cell: Vector2i) -> void:
    if _is_floating() or _weight < _ice_cracking_weight or SpatialHash.instance == null:
        return
    for ice in SpatialHash.instance.get_ice_entities_on_cell(cell):
        if not is_instance_valid(ice):
            continue
        var hc := (ice as Node3D).get_node_or_null("HealthComponent") as HealthComponent
        if hc:
            hc.take_damage(roundi(_weight))


func _apply_facing(direction: Vector3) -> void:
    if not is_instance_valid(_rotation_target):
        return
    var forward := Vector3(direction.x, 0.0, direction.z).normalized()
    if forward.length_squared() < 0.001:
        return
    var normal := (
        Vector3.UP
        if _is_infantry
        else TerrainSystem.get_normal_at_world(_parent.global_position).normalized()
    )
    var projected := (forward - forward.dot(normal) * normal).normalized()
    if projected.length_squared() < 0.001:
        return
    var right := projected.cross(normal).normalized()
    var rot_basis := Basis()
    rot_basis.x = right
    rot_basis.y = normal
    rot_basis.z = -projected
    _rotation_target.global_transform.basis = rot_basis


func _assign_sub_slot_at_cell(cell: Vector2i) -> void:
    _has_sub_slot = false
    var slot: int = CellReservation.instance.reserve_sub_slot(cell, _parent, _assigned_slot)
    if slot < 0:
        return
    _assigned_slot = slot
    var positions: Array[Vector3] = CellSubPositions.get_sub_positions(cell)
    _sub_slot_position = CellUtil.cell_to_world(cell) + positions[slot]
    _has_sub_slot = true


func _spline_segment() -> int:
    return clampi(floori(_spline_t), 0, maxi(0, _num_segments() - 1))


func _get_spline_pos(t: float) -> Vector3:
    return SplineUtil.evaluate(_waypoints, t)


func _get_spline_tangent(t: float) -> Vector3:
    return SplineUtil.tangent(_waypoints, t)


func _build_blocked_cells(unblock_buildings: bool = false) -> Dictionary:
    var result: Dictionary = SpatialHash.instance.get_blocked_cells().duplicate()
    var cell := CellUtil.world_to_cell(_parent.global_position)
    result.erase(CellUtil.cell_key(cell))
    if not _is_infantry and _crusher:
        result.merge(SpatialHash.instance.get_crusher_blocking_cells(_player_id))
    elif not _is_infantry:
        result.merge(SpatialHash.instance.get_infantry_cells())
    if unblock_buildings:
        for key in SpatialHash.instance.get_building_cells():
            result.erase(key)
    else:
        var building_cells := SpatialHash.instance.get_building_cells()
        for key in SpatialHash.instance.get_reserved():
            if not building_cells.has(key):
                result.erase(key)
    return result


func _is_cell_occupied_by_idle(cell: Vector2i) -> bool:
    if SpatialHash.instance.is_cell_blocked(cell):
        return true
    var key: int = CellUtil.cell_key(cell)
    if SpatialHash.instance._grid.has(key):
        for entry in SpatialHash.instance._grid[key]:
            if entry.node != _parent:
                if _is_infantry and entry.entity_type == EntityData.EntityType.INFANTRY:
                    continue
                return true
    return false


func _find_nearest_free_cell(cell: Vector2i) -> Vector2i:
    return CellUtil.spiral_first_free(cell, 4, _is_cell_occupied_by_idle)


func _find_nearest_free_sub_slot_cell(cell: Vector2i) -> Vector2i:
    return CellUtil.spiral_first_free(cell, 4, _is_cell_unavailable_for_sub_slot)


func _is_cell_unavailable_for_sub_slot(cell: Vector2i) -> bool:
    if SpatialHash.instance.is_cell_blocked(cell):
        return true
    var key := CellUtil.cell_key(cell)
    if SpatialHash.instance.get_building_cells().has(key):
        return true
    if SpatialHash.instance.is_bib_cell(cell):
        return true
    return CellReservation.instance.is_cell_full(cell)


func _scatter_blockers() -> void:
    var cell := CellUtil.world_to_cell(_parent.global_position)
    var blocked := SpatialHash.instance.get_blocked_cells()
    for radius in range(1, 4):
        for dx in range(-radius, radius + 1):
            for dz in range(-radius, radius + 1):
                if abs(dx) != radius and abs(dz) != radius:
                    continue
                var ncell := cell + Vector2i(dx, dz)
                var nkey := CellUtil.cell_key(ncell)
                if not blocked.has(nkey):
                    continue
                if _scattered_this_frame.has(nkey):
                    continue
                var push_dir := Vector2i(sign(dx), sign(dz))
                var push_cell := ncell + push_dir
                if SpatialHash.instance.is_cell_blocked(push_cell):
                    continue
                if not SpatialHash.instance.reserve_cell(push_cell):
                    continue
                _scattered_this_frame[nkey] = true
                SpatialHash.instance.force_reserve(ncell)
                for entry in SpatialHash.instance.get_entries(ncell):
                    var mc := entry.mc as MovementController
                    if mc and mc._state == State.IDLE and mc != self:
                        (
                            mc
                            . set_target_position(
                                CellUtil.cell_to_world(push_cell),
                                false,
                                mc.is_airborne_jumpjet(),
                                true,
                            )
                        )


func nudge_from_cell(blocking_cell: Vector2i) -> bool:
    var entries := SpatialHash.instance.get_entries(blocking_cell)
    for entry in entries:
        var mc := entry.mc as MovementController
        if mc and mc._state == State.IDLE:
            var free := _find_nearest_free_cell(blocking_cell)
            mc.set_target_position(
                CellUtil.cell_to_world(free), false, mc.is_airborne_jumpjet(), true
            )
            return true
    return false


func _snap_to_terrain(delta: float = 0.0) -> void:
    if _is_jumpjet:
        _update_vertical(delta)
        return
    var terrain_y := TerrainSystem.get_height_at_world_smooth(_parent.global_position)
    var target_y := terrain_y + (_hover_height if _is_floating() else 0.0)
    _parent.global_position.y = lerpf(_parent.global_position.y, target_y, 0.95)


func _update_vertical(delta: float) -> void:
    if not _is_jumpjet:
        return
    var terrain_y := TerrainSystem.get_height_at_world_smooth(_parent.global_position)
    match _vertical_state:
        VerticalState.GROUND:
            _parent.global_position.y = terrain_y
        VerticalState.AIR:
            _parent.global_position.y = terrain_y + _jumpjet_air_height
        VerticalState.ASCENDING:
            var target_air_y := terrain_y + _jumpjet_air_height
            _parent.global_position.y += move_speed * _vertical_split_factor() * delta
            if _parent.global_position.y >= target_air_y:
                _parent.global_position.y = target_air_y
                _vertical_state = VerticalState.AIR
        VerticalState.DESCENDING:
            _parent.global_position.y -= move_speed * _vertical_split_factor() * delta
            if _parent.global_position.y <= terrain_y:
                _parent.global_position.y = terrain_y
                _vertical_state = VerticalState.GROUND
                _land_on_arrival = false


func _apply_zone_desire(desired: VerticalState) -> void:
    if not _is_jumpjet:
        return
    if desired == _vertical_state:
        return
    match _vertical_state:
        VerticalState.GROUND:
            if desired == VerticalState.AIR:
                _vertical_state = VerticalState.ASCENDING
        VerticalState.AIR:
            if desired == VerticalState.GROUND:
                _vertical_state = VerticalState.DESCENDING
        VerticalState.ASCENDING:
            _vertical_state = (
                VerticalState.DESCENDING
                if desired == VerticalState.GROUND
                else VerticalState.ASCENDING
            )
        VerticalState.DESCENDING:
            _vertical_state = (
                VerticalState.ASCENDING
                if desired == VerticalState.AIR
                else VerticalState.DESCENDING
            )


func get_cursor_for_target(_target: Node3D, _target_cell: Vector2i) -> CursorState.Type:
    return CursorState.Type.MOVE


func get_order_for_target(
    target: Node3D,
    _target_cell: Vector2i,
    target_pos: Vector3,
    modifiers: Dictionary,
) -> OrderResult:
    if target:
        return null
    var queued: bool = modifiers.get(OrderResult.MOD_QUEUED, false)
    return OrderResult.new(
        CursorState.Type.MOVE,
        5,
        null,
        target_pos,
        queued,
        func(): set_target_position(target_pos),
    )
