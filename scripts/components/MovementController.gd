class_name MovementController extends Node3D

signal arrived(position: Vector3)

enum State { IDLE, ROTATING, MOVING, WAIT }

@export var move_speed: float = 8.0
@export var cell_radius: float = 1.0
@export var rotation_speed: float = 180.0
@export_range(1.0, 45.0) var rotation_angle_threshold: float = 5.0
@export_node_path("MeshInstance3D") var rotation_target_path: NodePath
@export var debug_show_path: bool = false

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


func _ready() -> void:
    _parent = get_parent() as Node3D
    _resolve_rotation_target()
    _speed_jitter = randf_range(0.95, 1.0)
    _wait_threshold = 10.0 + randf_range(0.0, 15.0)


func _num_segments() -> int:
    return maxi(0, _waypoints.size() - 1)


func set_target_position(target: Vector3) -> void:
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

    var target_cell := Pathfinder.world_to_cell(target)
    if _is_cell_occupied_by_idle(target_cell):
        var free := _find_nearest_free_cell(target_cell)
        target = Pathfinder.cell_to_world(free)

    var blocked := _build_blocked_cells()
    var path: PackedVector3Array = Pathfinder.find_path(_parent.global_position, target, blocked)

    if path.is_empty():
        _scatter_blockers()
        return

    var full_path: PackedVector3Array = [_parent.global_position]
    full_path.append_array(path)

    for i in range(1, full_path.size()):
        full_path[i].y = TerrainSystem.get_height_at_world_smooth(full_path[i])

    _waypoints = full_path
    _spline_t = 0.001
    _wait_frames = 0
    _repair_frames = 0
    if is_instance_valid(_rotation_target):
        _rotation_yaw = _rotation_target.global_rotation.y
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
        var forward := Vector3(-sin(_rotation_yaw), 0.0, -cos(_rotation_yaw))
        var normal := TerrainSystem.get_normal_at_world(_parent.global_position).normalized()
        var projected := (forward - forward.dot(normal) * normal).normalized()
        var right := projected.cross(normal).normalized()
        var rot_basis := Basis()
        rot_basis.x = right
        rot_basis.y = normal
        rot_basis.z = -projected
        _rotation_target.global_transform.basis = rot_basis


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
            var next_cell := Pathfinder.world_to_cell(_waypoints[seg + 1])
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

    var parent_cell := Pathfinder.world_to_cell(parent_pos)
    var min_neighbor_dist_ahead: float = INF

    for dx in range(-1, 2):
        for dz in range(-1, 2):
            for entry in SpatialHash.instance.get_entries(parent_cell + Vector2i(dx, dz)):
                var entity_parent := entry.node as Node3D
                if not is_instance_valid(entity_parent) or entity_parent == _parent:
                    continue

                var mc := entry.mc as MovementController
                if mc._state == State.IDLE:
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
        var forward := Vector3(final_direction.x, 0.0, final_direction.z).normalized()
        var normal := TerrainSystem.get_normal_at_world(_parent.global_position).normalized()
        var projected := (forward - forward.dot(normal) * normal).normalized()
        var right := projected.cross(normal).normalized()
        var rot_basis := Basis()
        rot_basis.x = right
        rot_basis.y = normal
        rot_basis.z = -projected
        _rotation_target.global_transform.basis = rot_basis

    var step := final_direction * move_speed * _speed_jitter * speed_factor * delta
    _spline_t += step.length() / seg_length

    if _spline_t >= float(_num_segments()):
        _spline_t = float(_num_segments())
        var final_cell := Pathfinder.world_to_cell(final_pos)
        if _is_cell_occupied_by_idle(final_cell):
            _state = State.WAIT
            return

        var approach_step := (final_pos - _parent.global_position).limit_length(move_speed * delta)
        if approach_step.length() < 0.001:
            _parent.global_position.y = TerrainSystem.get_height_at_world_smooth(
                _parent.global_position
            )
            _state = State.IDLE
            SpatialHash.instance.release_cell(Pathfinder.world_to_cell(_parent.global_position))
            if debug_show_path:
                DebugVisualizer.clear_path(get_path())
            arrived.emit(_parent.global_position)
        else:
            _parent.global_position += Vector3(approach_step.x, 0.0, approach_step.z)
            _snap_to_terrain()
    else:
        _parent.global_position += step
        var spline_pos := _get_spline_pos(_spline_t)
        var lerped := _parent.global_position.lerp(spline_pos, 0.2)
        _parent.global_position = Vector3(lerped.x, _parent.global_position.y, lerped.z)
        _snap_to_terrain()


func _handle_wait() -> void:
    _wait_frames += 1

    if _wait_frames == 15:
        _scatter_blockers()

    if _wait_frames > _wait_threshold:
        _wait_frames = 0
        _scatter_blockers()
        var target_cell := Pathfinder.world_to_cell(_waypoints[_waypoints.size() - 1])
        var free_cell := _find_nearest_free_cell(target_cell)
        set_target_position(Pathfinder.cell_to_world(free_cell))
        return

    var final_cell := Pathfinder.world_to_cell(_waypoints[_waypoints.size() - 1])
    if not _is_cell_occupied_by_idle(final_cell):
        var cell_center := Pathfinder.cell_to_world(final_cell)
        _parent.global_position = _parent.global_position.lerp(cell_center, 0.3)
        if _parent.global_position.distance_to(cell_center) < 0.05:
            _parent.global_position = cell_center
            _state = State.IDLE
            SpatialHash.instance.release_cell(final_cell)
            if debug_show_path:
                DebugVisualizer.clear_path(get_path())
            arrived.emit(_parent.global_position)
        return


func squaref(v: float) -> float:
    return v * v


func _spline_segment() -> int:
    return clampi(floori(_spline_t), 0, maxi(0, _num_segments() - 1))


func _get_spline_pos(t: float) -> Vector3:
    return SplineUtil.evaluate(_waypoints, t)


func _get_spline_tangent(t: float) -> Vector3:
    return SplineUtil.tangent(_waypoints, t)


func _build_blocked_cells() -> Dictionary:
    var result: Dictionary = SpatialHash.instance.get_blocked_cells().duplicate()
    var cell := Pathfinder.world_to_cell(_parent.global_position)
    result.erase(str(cell.x) + "," + str(cell.y))
    for key in SpatialHash.instance.get_reserved():
        result.erase(key)
    return result


func _is_cell_occupied_by_idle(cell: Vector2i) -> bool:
    return SpatialHash.instance.is_cell_idle(cell)


func _find_nearest_free_cell(cell: Vector2i) -> Vector2i:
    if not _is_cell_occupied_by_idle(cell):
        return cell
    for radius in range(1, 5):
        for dx in range(-radius, radius + 1):
            for dz in range(-radius, radius + 1):
                if abs(dx) != radius and abs(dz) != radius:
                    continue
                var n := cell + Vector2i(dx, dz)
                if not _is_cell_occupied_by_idle(n):
                    return n
    return cell


func _scatter_blockers() -> void:
    var cell := Pathfinder.world_to_cell(_parent.global_position)
    var blocked := SpatialHash.instance.get_blocked_cells()
    for radius in range(1, 4):
        for dx in range(-radius, radius + 1):
            for dz in range(-radius, radius + 1):
                if abs(dx) != radius and abs(dz) != radius:
                    continue
                var ncell := cell + Vector2i(dx, dz)
                var nkey := str(ncell.x) + "," + str(ncell.y)
                if not blocked.has(nkey):
                    continue
                if _scattered_this_frame.has(nkey):
                    continue
                var push_dir := Vector2i(sign(dx), sign(dz))
                var push_cell := ncell + push_dir
                if SpatialHash.instance.is_cell_idle(push_cell):
                    continue
                if not SpatialHash.instance.reserve_cell(push_cell):
                    continue
                _scattered_this_frame[nkey] = true
                SpatialHash.instance.force_reserve(ncell)
                for entry in SpatialHash.instance.get_entries(ncell):
                    var mc := entry.mc as MovementController
                    if mc and mc._state == State.IDLE and mc != self:
                        mc.set_target_position(Pathfinder.cell_to_world(push_cell))


func _snap_to_terrain() -> void:
    var terrain_y := TerrainSystem.get_height_at_world_smooth(_parent.global_position)
    _parent.global_position.y = lerpf(_parent.global_position.y, terrain_y, 0.95)
