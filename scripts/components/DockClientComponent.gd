class_name DockClientComponent extends Node

## Entity IDs this unit is allowed to dock with (e.g. ["PROC"] for refinery). Empty = any.
@export var can_dock_with: PackedStringArray = []
## Extra distance penalty squared added per queued docker when ranking dock hosts.
@export var occupancy_penalty: float = 10.0
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
var _retry_cooldown: float = 0.0
var _recheck_timer: float = 0.0

const REFINERY_TIMEOUT: float = 5.0
const DOCKING_TIMEOUT: float = 5.0
const QUEUED_TIMEOUT: float = 5.0
const RETRY_COOLDOWN: float = 2.0
const RECHECK_INTERVAL: float = 2.0

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
    if _retry_cooldown > 0.0:
        _retry_cooldown -= delta
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
            var host_node := _queued_host
            _queued_host = null
            var dock := host_node.get_node_or_null("DockHostComponent") as DockHostComponent
            if dock:
                dock.leave_dock(self)
            dock_cancelled.emit()
        else:
            _recheck_timer -= delta
            if _recheck_timer <= 0.0:
                _recheck_timer = RECHECK_INTERVAL
                var parent := get_parent() as Node3D
                if parent:
                    var current_dock := _queued_host.get_node_or_null(
                        "DockHostComponent"
                    ) as DockHostComponent
                    if current_dock:
                        var current_size := current_dock.get_effective_queue_size()
                        var better := _find_shorter_queue(
                            parent, _queued_host, current_size
                        )
                        if better:
                            _queued_host = null
                            current_dock.leave_dock(self)
                            var bound := _try_bind_host(better)
                            if bound:
                                _target_host = better
                                _refinery_timeout = REFINERY_TIMEOUT
                                _move_to_dock(better)
                            else:
                                _queued_host = better
                                _queued_timeout = QUEUED_TIMEOUT
                                _recheck_timer = RECHECK_INTERVAL
                                var bdock := better.get_node_or_null(
                                    "DockHostComponent"
                                ) as DockHostComponent
                                if bdock:
                                    _move_to_cell(bdock.find_wait_cell())
                                dock_slot_failed.emit()


func seek_dock(parent: Node3D, specific_host: Node3D = null) -> void:
    # Player dock command overrides any current target.
    if specific_host:
        if is_reserved():
            release_reservation()
        _target_host = null
        _retry_cooldown = 0.0
        _disconnect_host_signal()
        var bound := _try_bind_host(specific_host)
        if bound:
            _target_host = specific_host
            _refinery_timeout = REFINERY_TIMEOUT
            _move_to_dock(specific_host)
            return
        _queued_host = specific_host
        _queued_timeout = QUEUED_TIMEOUT
        _recheck_timer = RECHECK_INTERVAL
        var dock := specific_host.get_node_or_null("DockHostComponent") as DockHostComponent
        if dock:
            _move_to_cell(dock.find_wait_cell())
        dock_slot_failed.emit()
        return

    if is_reserved() or _target_host or _retry_cooldown > 0.0:
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
    _queued_host = host
    _queued_timeout = QUEUED_TIMEOUT
    _recheck_timer = RECHECK_INTERVAL
    var dock := host.get_node_or_null("DockHostComponent") as DockHostComponent
    if dock:
        _move_to_cell(dock.find_wait_cell())
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


func _move_to_cell(cell: Vector2i) -> void:
    if not _mc:
        return
    _mc.set_target_position(Pathfinder.cell_to_world(cell))


func _on_arrived(_position: Vector3) -> void:
    if not _target_host:
        return
    _refinery_timeout = 0.0
    # Verify we're at the correct dock cell — pathfinder may route to a nearby cell.
    var dock := _target_host.get_node_or_null("DockHostComponent") as DockHostComponent
    if dock and _mc:
        var my_cell := Pathfinder.world_to_cell(get_parent().global_position)
        if my_cell != dock._dock_cell:
            _mc.set_target_position(Pathfinder.cell_to_world(dock._dock_cell))
            return
    if is_reserved():
        _docking_timeout = -1.0
        dock_slot_reserved.emit(_reserved_host)
        return
    reserve_at(_target_host)


func _on_pathfinding_failed() -> void:
    if _target_host or is_reserved():
        _retry_cooldown = RETRY_COOLDOWN
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
        _docking_timeout = -1.0
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


## Find a host with a shorter effective queue than max_size.
func _find_shorter_queue(
    parent: Node3D, exclude: Node3D, max_size: int
) -> Node3D:
    var best: Node3D = null
    var best_size := max_size
    var best_dist := INF
    var parent_cell := Pathfinder.world_to_cell(parent.global_position)
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
        var size := dock.get_effective_queue_size()
        if size > best_size:
            continue
        var dock_cell := Pathfinder.world_to_cell(
            Pathfinder.cell_to_world(dock._dock_cell)
        )
        var dist := Vector2(parent_cell - dock_cell).length_squared()
        if size < best_size or dist < best_dist:
            best_size = size
            best_dist = dist
            best = child
    return best


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
    if is_instance_valid(_reserved_host):
        dock_slot_reserved.emit(_reserved_host)
    elif is_instance_valid(_queued_host):
        var host := _queued_host
        _queued_host = null
        _target_host = host
        _bind_host(host)
        _move_to_dock(host)


func on_dock_undocked(docker: Node) -> void:
    if docker != self:
        return
    _target_host = null
    _reserved_host = null
    dock_undocked.emit(docker)
