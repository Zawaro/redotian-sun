class_name TurretComponent extends Node3D

## Owns the yaw of each socket declared by the entity's ArtData. This is the
## single source of truth for turret aim: combat reads alignment and the
## renderer reads the world transform from here, so simulation and visuals
## cannot drift. It never touches the entity body transform or MovementController.

## Angle tolerance in degrees at which a socket counts as aimed.
const DEFAULT_ANGLE_THRESHOLD: float = 5.0

var _entity: Node3D = null
var _art_data: ArtData = null
var _rotation_speed: float = 180.0
var _angle_threshold: float = DEFAULT_ANGLE_THRESHOLD
## socket id (String) -> yaw in radians, relative to the socket's rest orientation.
var _yaws: Dictionary = {}
## Non-instanced entities (buildings) render turrets as node-tree children.
## Instanced units (INFANTRY/VEHICLE/AIRCRAFT) render through UnitMeshRenderer.
var _use_instanced: bool = true
## socket id -> MeshInstance3D, only for the node-tree path.
var _node_turrets: Dictionary = {}
## Sibling MovementController, resolved lazily. Null for buildings/immobile.
var _mc: MovementController = null
var _mc_resolved: bool = false
## socket id -> physics frame combat last aimed it, so the default move/idle
## pass does not step the same socket twice in one tick.
var _aimed_frame: Dictionary = {}


func configure(data: EntityData) -> void:
    _entity = get_parent() as Node3D
    _art_data = data.art_data
    _rotation_speed = data.rotation_speed
    _yaws.clear()
    if _art_data:
        for socket in _art_data.sockets:
            if socket and not socket.id.is_empty():
                _yaws[socket.id] = 0.0
    var etype := data.entity_type
    _use_instanced = (
        etype == EntityData.EntityType.INFANTRY
        or etype == EntityData.EntityType.VEHICLE
        or etype == EntityData.EntityType.AIRCRAFT
    )
    if not _use_instanced:
        _build_node_turrets()
    # CombatComponent (priority 0) aims first, then the default move/idle pass
    # here, then UnitMeshRenderer (100) syncs instances.
    process_physics_priority = 50
    set_physics_process(true)


## Builds placeholder child meshes for non-instanced entities. Real turret
## models are a later change; placeholders match the instanced socket path.
func _build_node_turrets() -> void:
    for socket in get_sockets():
        if socket == null or socket.id.is_empty() or socket.placeholder_size == Vector3.ZERO:
            continue
        var mesh_instance := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = socket.placeholder_size
        mesh_instance.mesh = box
        mesh_instance.name = "Socket_%s" % socket.id
        add_child(mesh_instance)
        _node_turrets[socket.id] = mesh_instance


func _physics_process(delta: float) -> void:
    _advance_default_aim(delta)
    if _use_instanced or _node_turrets.is_empty():
        return
    var entity_visible := is_instance_valid(_entity) and _entity.visible
    for socket_id in _node_turrets:
        var mesh_instance: MeshInstance3D = _node_turrets[socket_id]
        var socket := _get_socket(socket_id)
        if not is_instance_valid(mesh_instance) or socket == null:
            continue
        mesh_instance.transform = _local_socket_transform(socket, get_yaw(socket_id))
        # ponytail: follows entity visibility; structure fog-ghost reparenting
        # (GhostDepot) for building turrets is deferred with #245.
        mesh_instance.visible = entity_visible


## Continuously faces the current order target: the movement destination while
## moving, else the rest orientation (chassis forward). Sockets combat aimed
## this tick are skipped, so attack aim always wins.
func _advance_default_aim(delta: float) -> void:
    _resolve_movement()
    var frame := Engine.get_physics_frames()
    for socket in get_sockets():
        if socket == null or socket.id.is_empty() or not socket.yaw_free:
            continue
        if _aimed_frame.get(socket.id, -1) == frame:
            continue
        if _mc and _mc.is_moving():
            slew(socket.id, _mc.get_target_position(), delta)
        else:
            realign(socket.id, delta)


func _resolve_movement() -> void:
    if _mc_resolved:
        return
    _mc_resolved = true
    var parent := get_parent()
    if parent:
        _mc = parent.get_node_or_null("MovementController") as MovementController


func has_sockets() -> bool:
    return _art_data != null and not _art_data.sockets.is_empty()


func get_sockets() -> Array[SocketData]:
    return _art_data.sockets if _art_data else []


func get_yaw(socket_id: String) -> float:
    return _yaws.get(socket_id, 0.0)


## Slews the socket toward a world position and reports whether it is aimed.
## Fixed sockets never yaw and always report aimed. Returns true once the
## socket yaw is within the angle threshold. A zero rotation speed holds the
## socket at its rest orientation unless the target is already within tolerance.
func slew(socket_id: String, target_pos: Vector3, delta: float) -> bool:
    var socket := _get_socket(socket_id)
    if socket == null or not is_instance_valid(_entity):
        return true
    if not socket.yaw_free:
        return true
    _aimed_frame[socket_id] = Engine.get_physics_frames()
    var desired := _desired_yaw(socket, target_pos)
    if is_nan(desired):
        return true
    return _slew_yaw_to(socket_id, desired, delta)


## Slews the socket back to its rest orientation (chassis forward) and reports
## whether it is aligned. Used when the entity has no order target.
func realign(socket_id: String, delta: float) -> bool:
    var socket := _get_socket(socket_id)
    if socket == null or not is_instance_valid(_entity):
        return true
    if not socket.yaw_free:
        return true
    return _slew_yaw_to(socket_id, 0.0, delta)


func _slew_yaw_to(socket_id: String, desired: float, delta: float) -> bool:
    var current: float = _yaws.get(socket_id, 0.0)
    var step := deg_to_rad(_rotation_speed) * delta
    var tolerance := maxf(step, deg_to_rad(_angle_threshold))
    if absf(angle_difference(current, desired)) <= tolerance:
        _yaws[socket_id] = desired
        return true
    _yaws[socket_id] = current + signf(angle_difference(current, desired)) * step
    return false


## World transform of the socket with its current yaw applied. The pivot
## position is fixed; only orientation rotates.
func get_socket_world_transform(socket_id: String) -> Transform3D:
    var socket := _get_socket(socket_id)
    if socket == null or not is_instance_valid(_entity):
        return Transform3D.IDENTITY
    var local := _local_socket_transform(socket, get_yaw(socket_id))
    return _entity.global_transform * local


## World transform of the socket muzzle: the socket transform extended by
## barrel_length along its forward axis.
func get_muzzle_world_transform(socket_id: String) -> Transform3D:
    var socket := _get_socket(socket_id)
    if socket == null:
        return get_socket_world_transform(socket_id)
    var muzzle := get_socket_world_transform(socket_id)
    muzzle.origin += -muzzle.basis.z * socket.barrel_length
    return muzzle


func _get_socket(socket_id: String) -> SocketData:
    if _art_data == null:
        return null
    return _art_data.get_socket(socket_id)


func _local_socket_transform(socket: SocketData, yaw: float) -> Transform3D:
    # Yaw is applied in entity-local space so the pivot position does not orbit
    # the entity origin; only the socket's orientation changes.
    var basis := Basis(Vector3.UP, yaw) * socket.pivot.basis
    return Transform3D(basis, socket.pivot.origin)


## Desired socket yaw (entity-local radians) that points the socket forward at
## the target, or NAN when the target is vertically above/below the socket.
func _desired_yaw(socket: SocketData, target_pos: Vector3) -> float:
    var socket_world_origin := _entity.global_transform * socket.pivot.origin
    var inverse_basis := _entity.global_transform.basis.inverse()
    var to_target := inverse_basis * (target_pos - socket_world_origin)
    to_target.y = 0.0
    if to_target.length_squared() < 0.001:
        return NAN
    var rest_forward := -socket.pivot.basis.z
    rest_forward.y = 0.0
    if rest_forward.length_squared() < 0.001:
        return NAN
    return rest_forward.normalized().signed_angle_to(to_target.normalized(), Vector3.UP)
