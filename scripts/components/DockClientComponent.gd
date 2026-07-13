class_name DockClientComponent extends Node

## Entity IDs this unit is allowed to dock with (e.g. ["PROC"] for refinery). Empty = any.
@export var can_dock_with: PackedStringArray = []
## Extra distance penalty squared added per queued docker when ranking dock hosts.
@export var occupancy_penalty: float = 5.0
## Search radius in cells when finding the nearest compatible dock host.
@export var search_radius_cells: int = 20

var _reserved_host: Node3D = null
var _queued_host: Node3D = null
var _target_host: Node3D = null
var _dock_id: String = ""
var _mc: MovementController = null
var _refinery_timeout: float = 0.0
var _docking_timeout: float = 0.0
var _queued_timeout: float = 0.0

const REFINERY_TIMEOUT: float = 5.0
const DOCKING_TIMEOUT: float = 5.0
const QUEUED_TIMEOUT: float = 10.0

## Emitted when a dock host accepts this client's reservation request.
signal dock_slot_reserved(host: Node3D)
## Emitted when no compatible dock host is reachable or all are full.
signal dock_slot_failed
## Emitted when docking is cancelled (timeout or pathfinding failure).
signal dock_cancelled
## Emitted when the dock host undocks this client (cargo fully unloaded).
signal dock_undocked(docker: Node)


func _ready() -> void:
    _mc = get_parent().get_node_or_null("MovementController") as MovementController
    if _mc:
        _mc.arrived.connect(_on_arrived)
        _mc.pathfinding_failed.connect(_on_pathfinding_failed)


func configure(data: EntityData) -> void:
    _dock_id = data.dock
    can_dock_with = [data.dock] if not data.dock.is_empty() else []


func get_dock_id() -> String:
    return _dock_id


func is_reserved() -> bool:
    return is_instance_valid(_reserved_host)


func _process(delta: float) -> void:
    if _target_host and not is_reserved():
        _refinery_timeout -= delta
        if _refinery_timeout <= 0.0:
            _cancel_dock()
    if is_reserved():
        if _docking_timeout > 0.0:
            _docking_timeout -= delta
            if _docking_timeout <= 0.0:
                _cancel_dock()
    if _queued_host and not is_reserved() and not _target_host:
        _queued_timeout -= delta
        if _queued_timeout <= 0.0:
            print("[DockClient] queued timeout, retry")
            _queued_host = null
            dock_slot_failed.emit()


func seek_dock(parent: Node3D) -> void:
    if is_reserved() or _target_host:
        return
    _disconnect_host_signal()

    var host := find_nearest_host(parent)
    if not host:
        dock_slot_failed.emit()
        return
    var bound := _try_bind_host(host)
    if bound:
        print("[DockClient] seek_dock reserved %s, moving" % host.name)
        _target_host = host
        _refinery_timeout = REFINERY_TIMEOUT
        _move_to_dock(host)
        return

    var next_host := find_nearest_host(parent, host)
    if next_host:
        bound = _try_bind_host(next_host)
        if bound:
            print("[DockClient] seek_dock reserved (2nd) %s, moving" % next_host.name)
            _target_host = next_host
            _refinery_timeout = REFINERY_TIMEOUT
            _move_to_dock(next_host)
            return

    # Both nearest docks occupied — queue at the nearest
    print("[DockClient] seek_dock: both docks busy, queuing at %s" % host.name)
    _queued_host = host
    _queued_timeout = QUEUED_TIMEOUT
    dock_slot_failed.emit()


func _move_to_dock(host: Node3D) -> void:
    var dock := host.get_node_or_null("DockHostComponent") as DockHostComponent
    if not dock or not _mc:
        dock_slot_failed.emit()
        return
    var cs := Pathfinder.CELL_SIZE
    var found := dock._get_foundation()
    var origin_cell := Vector2i(
        floori((host.global_position.x - found.x * 0.5 * cs) / cs),
        floori((host.global_position.z - found.y * 0.5 * cs) / cs)
    )
    var top_left_world := Pathfinder.cell_to_world(origin_cell)
    var dock_offset := dock.dock_position
    var basis := host.global_transform.basis
    var target_pos := top_left_world + basis * dock_offset
    _mc.set_target_position(target_pos)


func _on_arrived(_position: Vector3) -> void:
    if not _target_host:
        return
    print("[DockClient] arrived at dock, reserving at %s" % _target_host.name)
    _refinery_timeout = 0.0
    if is_reserved():
        print("[DockClient] already reserved, signaling arrival")
        _docking_timeout = DOCKING_TIMEOUT
        dock_slot_reserved.emit(_reserved_host)
        return
    reserve_at(_target_host)


func _on_pathfinding_failed() -> void:
    if _target_host or is_reserved():
        print("[DockClient] pathfinding failed, cancelling dock")
        _cancel_dock()


func _cancel_dock() -> void:
    var was_reserved := is_reserved()
    release_reservation()
    _target_host = null
    if was_reserved:
        print("[DockClient] dock cancelled (was reserved)")
        dock_cancelled.emit()
    else:
        print("[DockClient] dock failed (no reservation)")
        dock_slot_failed.emit()


func _disconnect_host_signal() -> void:
    if not is_instance_valid(_reserved_host):
        return
    var dock := _reserved_host.get_node_or_null("DockHostComponent") as DockHostComponent
    if dock and dock.docker_undocked.is_connected(on_dock_undocked):
        dock.docker_undocked.disconnect(on_dock_undocked)


func reserve_at(host: Node3D) -> bool:
    _disconnect_host_signal()
    var bound := _try_bind_host(host)
    if bound:
        print("[DockClient] reserved at %s" % host.name)
        _queued_host = null
        _docking_timeout = DOCKING_TIMEOUT
        dock_slot_reserved.emit(host)
        return true
    print("[DockClient] reserve_at FAILED at %s (busy), queued" % host.name)
    _queued_host = host
    _queued_timeout = QUEUED_TIMEOUT
    dock_slot_failed.emit()
    return false


func find_nearest_host(parent: Node3D, exclude: Node3D = null) -> Node3D:
    var parent_cell := Pathfinder.world_to_cell(parent.global_position)
    var nearest: Node3D = null
    var nearest_dist := float(search_radius_cells * search_radius_cells)
    var buildings_parent := get_tree().current_scene.get_node_or_null("Buildings")
    if not buildings_parent:
        return null

    for child in buildings_parent.get_children():
        if child == exclude:
            continue
        var dock := child.get_node_or_null("DockHostComponent") as DockHostComponent
        if not dock:
            continue
        var entity_id := dock.get_entity_id()
        if not can_dock_with.is_empty() and entity_id not in can_dock_with:
            continue
        var dock_cell := Pathfinder.world_to_cell(Pathfinder.cell_to_world(dock._dock_cell))
        var dist := Vector2(parent_cell - dock_cell).length_squared()
        dist += dock.get_queue_size() * occupancy_penalty * occupancy_penalty
        if dist < nearest_dist:
            nearest_dist = dist
            nearest = child

    return nearest


func _try_bind_host(host: Node3D) -> Node3D:
    if not host:
        return null
    var dock := host.get_node_or_null("DockHostComponent") as DockHostComponent
    if not dock:
        return null
    if dock.request_dock(self):
        _bind_host(host)
        return host
    return null


func _bind_host(host: Node3D) -> void:
    _reserved_host = host
    var dock := host.get_node_or_null("DockHostComponent") as DockHostComponent
    if dock and not dock.docker_undocked.is_connected(on_dock_undocked):
        dock.docker_undocked.connect(on_dock_undocked)


func release_reservation() -> void:
    if not is_instance_valid(_reserved_host):
        return
    var dock := _reserved_host.get_node_or_null("DockHostComponent") as DockHostComponent
    if dock:
        if dock.docker_undocked.is_connected(on_dock_undocked):
            dock.docker_undocked.disconnect(on_dock_undocked)
        dock.leave_dock(self)
    _reserved_host = null
    _queued_host = null


func on_slot_available() -> void:
    var res := is_instance_valid(_reserved_host)
    var que := is_instance_valid(_queued_host)
    print("[DockClient] on_slot_available, reserved=%s, queued=%s" % [res, que])
    if is_instance_valid(_reserved_host):
        dock_slot_reserved.emit(_reserved_host)
    elif is_instance_valid(_queued_host):
        var host := _queued_host
        _queued_host = null
        _target_host = host
        _bind_host(host)
        _move_to_dock(host)
    else:
        var parent := get_parent() as Node3D
        if parent:
            var host := find_nearest_host(parent)
            if host:
                _target_host = host
                _move_to_dock(host)
            else:
                dock_slot_failed.emit()


func on_dock_undocked(_docker: Node) -> void:
    print("[DockClient] on_dock_undocked")
    dock_undocked.emit(_docker)
