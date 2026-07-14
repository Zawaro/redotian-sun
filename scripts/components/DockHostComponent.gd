class_name DockHostComponent extends Node

## Local offset from the building's top-left cell to the dock cell.
@export var dock_position: Vector3 = Vector3.ZERO
## Rotation in degrees the docker entity snaps to when docking (e.g. -90 for west-facing).
@export var dock_rotation: float = 0.0
## Accepted dock type IDs (e.g. ["harvest"]). Empty = accepts all types.
@export var dock_types: PackedStringArray = []
## Frames to wait before promoting the next queued docker after the first.
@export var dock_wait_ticks: int = 10
## Seconds before a docked client is evicted for not completing the dock sequence.
@export var stale_timeout: float = 5.0

var queue: Array[Node] = []
var current_docker: Node = null
var _entity_data: EntityData = null
var _dock_cell: Vector2i = Vector2i.ZERO
## Ticks until next promotion. 0 = promote on next _process tick.
var _wait_counter: int = 0
## Seconds since the current docker was docked. Resets on each new docker.
var _stale_timer: float = 0.0
## True when the old docker has undocked but the dock cell may still be occupied.
var _awaiting_vacate: bool = false
## The docker that is currently vacating the dock cell. Prevents re-dock via signal chain.
var _vacating_docker: Node = null
## Seconds since vacate began. Safety timeout to avoid permanent deadlock.
var _vacate_timer: float = 0.0
## Seconds to wait for the dock cell to clear before promoting anyway.
const VACATE_TIMEOUT: float = 3.0

## Emitted when a docker is accepted and begins docking.
signal docker_docked(docker: Node)
## Emitted when a docker leaves the dock (finished unloading or cancelled).
signal docker_undocked(docker: Node)
## Emitted when a queue slot becomes available for the next waiting docker.
signal slot_available
## Emitted when a docked client is evicted for taking too long.
signal dock_timeout(docker: Node)


func _ready() -> void:
    if Engine.is_editor_hint():
        return
    _compute_dock_cell()


func _exit_tree() -> void:
    if Engine.is_editor_hint():
        return
    _clear_queue("host freed")


func configure(data: EntityData) -> void:
    _entity_data = data
    dock_position = data.dock_position
    dock_rotation = data.dock_rotation


func _get_foundation() -> Vector2i:
    var fc := get_parent().get_node_or_null("FoundationComponent") as FoundationComponent
    return fc.foundation if fc else Vector2i(1, 1)


func _compute_dock_cell() -> void:
    var entity := get_parent() as Node3D
    if not entity:
        return
    var cs := Pathfinder.CELL_SIZE
    var found := _get_foundation()
    var origin_cell := Vector2i(
        floori((entity.global_position.x - found.x * 0.5 * cs) / cs),
        floori((entity.global_position.z - found.y * 0.5 * cs) / cs)
    )
    var top_left := Pathfinder.cell_to_world(origin_cell)
    _dock_cell = Pathfinder.world_to_cell(top_left + entity.global_transform.basis * dock_position)


func is_cell_available(cell: Vector2i) -> bool:
    if not SpatialHash.instance:
        return true
    var key: int = SpatialHash.instance._cell_key(cell)
    if SpatialHash.instance._building_cells.has(key):
        return false
    var blocked: bool = SpatialHash.instance._blocked_cells.has(key)
    var reserved: bool = SpatialHash.instance._reserved.has(key)
    return not blocked and not reserved


func find_wait_cell(max_radius: int = 3) -> Vector2i:
    for r in range(0, max_radius + 1):
        for dx in range(-r, r + 1):
            for dz in range(-r, r + 1):
                if r > 0 and abs(dx) != r and abs(dz) != r:
                    continue
                var cell := _dock_cell + Vector2i(dx, dz)
                if is_cell_available(cell) and not SpatialHash.instance.is_bib_cell(cell):
                    return cell
    return _dock_cell


func has_dock_type(type: String) -> bool:
    return dock_types.is_empty() or type in dock_types


func get_entity_id() -> String:
    return _entity_data.id if _entity_data else ""


func get_queue_size() -> int:
    return queue.size()


## Effective wait: 0 if slot is free, queue.size()+1 if occupied (always penalize busy docks).
func get_effective_queue_size() -> int:
    if current_docker == null:
        return 0
    return queue.size() + 1


## Accept a docker into the dock. Returns true if docked immediately, false if queued.
func request_dock(docker: Node) -> bool:
    var docker_name: String = _entity_name(docker)
    var host_name: String = get_parent().name if get_parent() else "?"
    if docker == _vacating_docker:
        return false
    if current_docker == docker:
        print("[DockHost] %s: re-dock accepted for %s" % [host_name, docker_name])
        return true
    if current_docker == null:
        current_docker = docker
        _stale_timer = 0.0
        docker_docked.emit(docker)
        if SpatialHash.instance:
            SpatialHash.instance.force_reserve(_dock_cell)
        print("[DockHost] %s: docked %s immediately (queue empty)" % [host_name, docker_name])
        return true
    if docker in queue:
        print("[DockHost] %s: rejected %s — already in queue" % [host_name, docker_name])
        return false
    queue.append(docker)
    _wait_counter = 0
    var current_name: String = _entity_name(current_docker)
    print(
        (
            "[DockHost] %s: queued %s (position %d, current=%s)"
            % [host_name, docker_name, queue.size(), current_name]
        )
    )
    return false


func _process(delta: float) -> void:
    # Vacate polling — wait for the old docker to physically leave the dock cell.
    if _awaiting_vacate:
        _vacate_timer += delta
        if _is_dock_cell_clear() or _vacate_timer >= VACATE_TIMEOUT:
            _finish_vacate()
        return

    # Stale client detection — evict if current docker doesn't complete in time.
    if current_docker and stale_timeout > 0.0:
        _stale_timer += delta
        if _stale_timer >= stale_timeout:
            var stale_docker := current_docker
            dock_timeout.emit(stale_docker)
            leave_dock(stale_docker)
            return

    if queue.is_empty():
        return
    if current_docker != null:
        return
    _wait_counter += 1
    if _wait_counter >= dock_wait_ticks:
        _wait_counter = 0
        # Find first valid client, discard dead entries.
        var docker: Node = null
        while not queue.is_empty():
            var candidate := queue.pop_front() as Node
            if is_instance_valid(candidate):
                docker = candidate
                break
        if docker:
            current_docker = docker
            _stale_timer = 0.0
            if SpatialHash.instance:
                SpatialHash.instance.force_reserve(_dock_cell)
            docker_docked.emit(docker)
            slot_available.emit()
            if docker.has_method("on_slot_available"):
                docker.on_slot_available()


## Remove a docker from the dock. If queued, removes from queue. If current, frees the slot.
func leave_dock(docker: Node) -> void:
    var docker_name: String = _entity_name(docker)
    var host_name: String = get_parent().name if get_parent() else "?"
    var q_before: int = queue.size()
    if current_docker == docker:
        current_docker = null
        _stale_timer = 0.0
        if not queue.is_empty():
            _awaiting_vacate = true
            _vacating_docker = docker
            _vacate_timer = 0.0
        docker_undocked.emit(docker)
        if _awaiting_vacate:
            print(
                (
                    "[DockHost] %s: undocked %s — awaiting vacate (q_before=%d, q_after=%d)"
                    % [host_name, docker_name, q_before, queue.size()]
                )
            )
        else:
            if SpatialHash.instance:
                SpatialHash.instance.release_cell(_dock_cell)
            print("[DockHost] %s: undocked %s (no queue, cell released)" % [host_name, docker_name])
    else:
        var idx := queue.find(docker)
        if idx >= 0:
            queue.remove_at(idx)
            print("[DockHost] %s: removed %s from queue (pos %d)" % [host_name, docker_name, idx])


## Purge the queue and notify each client. Reason is for logging only.
func _clear_queue(reason: String) -> void:
    var host_name: String = get_parent().name if get_parent() else "?"
    while not queue.is_empty():
        var docker := queue.pop_front() as Node
        # on_dock_cancelled() cleans state without emitting signals — safe during teardown.
        if is_instance_valid(docker) and docker.has_method("on_dock_cancelled"):
            docker.on_dock_cancelled()
        print(
            "[DockHost] %s: purged %s from queue (%s)" % [host_name, _entity_name(docker), reason]
        )
    _wait_counter = 0


func _entity_name(node: Node) -> String:
    if not node:
        return "none"
    var parent := node.get_parent()
    return parent.name if parent else node.name


## Reset the stale timer — called when unloading begins so the timeout
## covers the full unload duration, not just the approach.
func reset_stale_timer() -> void:
    _stale_timer = 0.0


## Returns true if no entity from the "entities" group occupies the dock cell.
func _is_dock_cell_clear() -> bool:
    if not SpatialHash.instance:
        return true
    var entries: Array = SpatialHash.instance.get_entries(_dock_cell)
    return entries.is_empty()


## Release the dock cell reservation and promote the next queued docker.
## Skips dead clients in queue. Caller (_process) already verified the
## dock cell is clear or vacate timeout has elapsed.
func _finish_vacate() -> void:
    var host_name: String = get_parent().name if get_parent() else "?"
    _awaiting_vacate = false
    _vacating_docker = null
    _vacate_timer = 0.0
    if SpatialHash.instance:
        SpatialHash.instance.release_cell(_dock_cell)

    # Find the first valid client in queue, discarding dead entries.
    var next_docker: Node = null
    while not queue.is_empty():
        var candidate := queue.pop_front() as Node
        if is_instance_valid(candidate):
            next_docker = candidate
            break
        print("[DockHost] %s: skipped dead client in queue" % host_name)

    if next_docker:
        current_docker = next_docker
        _stale_timer = 0.0
        if SpatialHash.instance:
            SpatialHash.instance.force_reserve(_dock_cell)
        docker_docked.emit(current_docker)
        slot_available.emit()
        if current_docker.has_method("on_slot_available"):
            print(
                (
                    "[DockHost] %s: promoting %s after vacate"
                    % [host_name, _entity_name(current_docker)]
                )
            )
            current_docker.on_slot_available()
