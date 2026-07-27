class_name MovementController extends Node3D

signal arrived(position: Vector3)
signal pathfinding_failed

enum State { IDLE, ROTATING, MOVING, WAIT }

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

static var _scattered_this_frame: Dictionary = {}
static var _last_physics_frame: int = -1

var _state: State = State.IDLE
var _waypoints: PackedVector3Array = PackedVector3Array()
var _spline_t: float = 0.0
var _rotation_target: Node3D
var _parent: Node3D
var _wait_frames: int = 0
var _wait_threshold: float = 60.0
var _repair_frames: int = 0
var _speed_jitter: float = 1.0
var _rotation_yaw: float = 0.0

var _is_infantry: bool = false
var _crusher: bool = false
var _rules: GlobalRules
var _player_id: int = -1
var _assigned_slot: int = -1
var _sub_slot_position: Vector3 = Vector3.ZERO
var _has_sub_slot: bool = false
var _last_position: Vector3 = Vector3.ZERO


func configure(data: EntityData) -> void:
    locomotor = data.locomotor
    movement_zone = data.movement_zone


func _ready() -> void:
    _parent = get_parent() as Node3D
    _resolve_rotation_target()
    _speed_jitter = randf_range(0.95, 1.0)
    _wait_threshold = 10.0 + randf_range(0.0, 15.0)
    if EntityFactory and EntityFactory.has_method("get_global_rules"):
        _rules = EntityFactory.get_global_rules()
    var stats := _parent.get_node_or_null("StatsComponent") as StatsComponent
    if stats:
        _is_infantry = stats.entity_type == EntityData.EntityType.INFANTRY
        _crusher = stats.crusher
        _player_id = stats.player_id
        if _rules:
            move_speed *= _rules.veteran_speed_multiplier(stats.veteran_level)


func _num_segments() -> int:
    return maxi(0, _waypoints.size() - 1)


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
        if _is_infantry:
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
    _state = State.IDLE
    SpatialHash.instance.release_cell(CellUtil.world_to_cell(_parent.global_position))
    if debug_show_path:
        DebugVisualizer.clear_path(get_path())


func set_target_position(target: Vector3, unblock_buildings: bool = false) -> void:
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

    var target_cell := CellUtil.world_to_cell(target)
    if _is_cell_occupied_by_idle(target_cell):
        var free := _find_nearest_free_cell(target_cell)
        target = CellUtil.cell_to_world(free)
        target_cell = free

    if _is_infantry:
        _assign_sub_slot_at_cell(target_cell)
        if _has_sub_slot:
            target = _sub_slot_position

    var blocked := _build_blocked_cells(unblock_buildings)
    var path: PackedVector3Array = Pathfinder.find_path(_parent.global_position, target, blocked)

    if path.is_empty():
        _scatter_blockers()
        pathfinding_failed.emit()
        return

    if _is_infantry and path.size() > 2:
        path = Pathfinder.smooth_path(path, blocked)

    if _is_infantry and _has_sub_slot and path.size() > 0:
        path[path.size() - 1] = _sub_slot_position
    if _is_infantry and path.size() > 1:
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
    _wait_frames = 0
    _repair_frames = 0
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
            _handle_wait()
        State.IDLE:
            _parent.global_position.y = TerrainSystem.get_height_at_world_smooth(
                _parent.global_position
            )


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
    if seg_length < 0.01:
        seg_length = 0.01

    if seg + 1 < _waypoints.size() - 1:
        _repair_frames += 1
        if _repair_frames >= 10:
            _repair_frames = 0
            var next_cell := CellUtil.world_to_cell(_waypoints[seg + 1])
            if _is_cell_occupied_by_idle(next_cell):
                set_target_position(_waypoints[_waypoints.size() - 1])
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

    var slope_coeff := 1.0
    if _rules and not _is_infantry:
        var ahead := parent_pos + spline_dir * CellUtil.CELL_SIZE
        var grade := (
            (TerrainSystem.get_height_at_world_smooth(ahead) - parent_pos.y) / CellUtil.CELL_SIZE
        )
        slope_coeff = _rules.movement_slope_coefficient(locomotor, grade)

    var step := final_direction * move_speed * _speed_jitter * speed_factor * slope_coeff * delta
    _spline_t += step.length() / seg_length

    if _spline_t >= float(_num_segments()):
        _spline_t = float(_num_segments())
        var final_cell := CellUtil.world_to_cell(final_pos)
        if _is_cell_occupied_by_idle(final_cell):
            _state = State.WAIT
            return

        var approach_step := (final_pos - _parent.global_position).limit_length(move_speed * delta)
        if approach_step.length() < 0.001:
            _parent.global_position.y = TerrainSystem.get_height_at_world_smooth(
                _parent.global_position
            )
            _has_sub_slot = false
            _state = State.IDLE
            # ponytail: no _claim_sub_slot() here — sub-slot is determined at
            # movement start in set_target_position(). Snapping on arrival is
            # visually broken.
            SpatialHash.instance.release_cell(CellUtil.world_to_cell(_parent.global_position))
            if debug_show_path:
                DebugVisualizer.clear_path(get_path())
            arrived.emit(_parent.global_position)
        else:
            _parent.global_position += Vector3(approach_step.x, 0.0, approach_step.z)
            _snap_to_terrain()
    else:
        _parent.global_position += step
        var skip_lerp := (
            _is_infantry and (_spline_segment() == 0 or _spline_segment() >= _num_segments() - 1)
        )
        if not skip_lerp:
            var spline_pos := _get_spline_pos(_spline_t)
            var lerped := _parent.global_position.lerp(spline_pos, 0.2)
            _parent.global_position = Vector3(lerped.x, _parent.global_position.y, lerped.z)
        _snap_to_terrain()

    if _crusher:
        var new_cell := CellUtil.world_to_cell(_parent.global_position)
        var old_cell := CellUtil.world_to_cell(_last_position)
        if new_cell != old_cell:
            _try_crush(new_cell)
    _last_position = _parent.global_position


func _handle_wait() -> void:
    _wait_frames += 1

    if _wait_frames == 15:
        _scatter_blockers()

    if _wait_frames > _wait_threshold:
        _wait_frames = 0
        _scatter_blockers()
        var target_cell := CellUtil.world_to_cell(_waypoints[_waypoints.size() - 1])
        var free_cell := _find_nearest_free_cell(target_cell)
        set_target_position(CellUtil.cell_to_world(free_cell))
        return

    var final_cell := CellUtil.world_to_cell(_waypoints[_waypoints.size() - 1])
    if not _is_cell_occupied_by_idle(final_cell):
        var cell_center := CellUtil.cell_to_world(final_cell)
        _parent.global_position = _parent.global_position.lerp(cell_center, 0.3)
        if _parent.global_position.distance_to(cell_center) < 0.05:
            _parent.global_position = cell_center
            _has_sub_slot = false
            _state = State.IDLE
            # ponytail: no _claim_sub_slot() here — sub-slot is determined at
            # movement start in set_target_position(). Snapping on arrival is
            # visually broken.
            SpatialHash.instance.release_cell(final_cell)
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
    var positions: Array[Vector3] = CellSubPositions.get_sub_positions(cell)
    var taken_slots: Dictionary = {}
    # Loop 1: entities already at this cell (in SpatialHash).
    var entries: Array = SpatialHash.instance.get_entries(cell)
    for entry in entries:
        var entry_mc: MovementController = entry["mc"]
        if entry_mc and entry_mc != self and entry_mc._has_sub_slot:
            taken_slots[entry_mc._assigned_slot] = true
    # Loop 2: entities en route to this cell (not in SpatialHash yet).
    for entity in get_tree().get_nodes_in_group("entities"):
        if entity == _parent:
            continue
        var mc: MovementController = entity.get_node_or_null("MovementController")
        if mc and mc != self and mc._has_sub_slot:
            var mc_cell := CellUtil.world_to_cell(mc._sub_slot_position)
            if mc_cell == cell:
                taken_slots[mc._assigned_slot] = true
    if (
        _assigned_slot >= 0
        and _assigned_slot < positions.size()
        and not taken_slots.has(_assigned_slot)
    ):
        _sub_slot_position = CellUtil.cell_to_world(cell) + positions[_assigned_slot]
        _has_sub_slot = true
        return
    for i in range(positions.size()):
        if not taken_slots.has(i):
            _assigned_slot = i
            _sub_slot_position = CellUtil.cell_to_world(cell) + positions[i]
            _has_sub_slot = true
            break


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
                        mc.set_target_position(CellUtil.cell_to_world(push_cell))


func nudge_from_cell(blocking_cell: Vector2i) -> bool:
    var entries := SpatialHash.instance.get_entries(blocking_cell)
    for entry in entries:
        var mc := entry.mc as MovementController
        if mc and mc._state == State.IDLE:
            var free := _find_nearest_free_cell(blocking_cell)
            mc.set_target_position(CellUtil.cell_to_world(free))
            return true
    return false


func _snap_to_terrain() -> void:
    var terrain_y := TerrainSystem.get_height_at_world_smooth(_parent.global_position)
    _parent.global_position.y = lerpf(_parent.global_position.y, terrain_y, 0.95)


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
