class_name DockHostComponent extends Node

## Local offset from the building's top-left cell to the dock cell.
@export var dock_position: Vector3 = Vector3.ZERO
## Rotation in degrees the docker entity snaps to when docking (e.g. -90 for west-facing).
@export var dock_rotation: float = 0.0
## Accepted dock type IDs (e.g. ["harvest"]). Empty = accepts all types.
@export var dock_types: PackedStringArray = []
## Max number of entities that can wait in the dock queue.
@export var max_queue_length: int = 3
## Frames to wait before promoting the next queued docker after a slot opens.
@export var dock_wait_ticks: int = 10

var queue: Array[Node] = []
var current_docker: Node = null
var _entity_data: EntityData = null
var _dock_cell: Vector2i = Vector2i.ZERO
var _wait_counter: int = 0
var _pending_dockers: Array[Node] = []

## Emitted when a docker is accepted and begins docking.
signal docker_docked(docker: Node)
## Emitted when a docker leaves the dock (finished unloading or cancelled).
signal docker_undocked(docker: Node)
## Emitted when a queue slot becomes available for the next waiting docker.
signal slot_available


func _ready() -> void:
    if Engine.is_editor_hint():
        return
    _compute_dock_cell()


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
                if is_cell_available(cell):
                    return cell
    return _dock_cell


func has_dock_type(type: String) -> bool:
    return dock_types.is_empty() or type in dock_types


func get_entity_id() -> String:
    return _entity_data.id if _entity_data else ""


func get_queue_size() -> int:
    return queue.size()


## Effective wait: 0 if slot is free, queue.size() if occupied.
func get_effective_queue_size() -> int:
    if current_docker == null:
        return 0
    return queue.size()


## Accept a docker into the dock. Returns true if docked immediately, false if queued or rejected.
func request_dock(docker: Node) -> bool:
    if current_docker == docker:
        return true
    if current_docker == null:
        current_docker = docker
        docker_docked.emit(docker)
        if SpatialHash.instance:
            SpatialHash.instance.force_reserve(_dock_cell)
        return true
    if queue.size() >= max_queue_length:
        return false
    if docker in queue:
        return false
    queue.append(docker)
    _pending_dockers.append(docker)
    return false


func _process(_delta: float) -> void:
    if _pending_dockers.is_empty():
        return
    _wait_counter += 1
    if _wait_counter >= dock_wait_ticks:
        _wait_counter = 0
        var docker := _pending_dockers.pop_front() as Node
        if is_instance_valid(docker) and docker in queue:
            queue.erase(docker)
            if current_docker == null:
                current_docker = docker
                if SpatialHash.instance:
                    SpatialHash.instance.force_reserve(_dock_cell)
                docker_docked.emit(docker)
                slot_available.emit()
                if docker.has_method("on_slot_available"):
                    docker.on_slot_available()


## Remove a docker from the dock. If queued, removes from queue. If current, frees the slot.
func leave_dock(docker: Node) -> void:
    if current_docker == docker:
        if SpatialHash.instance:
            SpatialHash.instance.release_cell(_dock_cell)
        current_docker = null
        # Promote next queued docker BEFORE emitting undocked signal.
        # This prevents the undocking harvester from re-reserving the slot
        # before the queue is processed.
        if not queue.is_empty():
            var next_docker := queue.pop_front() as Node
            _pending_dockers.erase(next_docker)
            current_docker = next_docker
            if SpatialHash.instance:
                SpatialHash.instance.force_reserve(_dock_cell)
        docker_undocked.emit(docker)
        if docker.has_method("on_dock_undocked"):
            docker.on_dock_undocked(docker)
        if current_docker and current_docker != docker:
            docker_docked.emit(current_docker)
            slot_available.emit()
            if current_docker.has_method("on_slot_available"):
                current_docker.on_slot_available()
    else:
        var idx := queue.find(docker)
        if idx >= 0:
            queue.remove_at(idx)
            _pending_dockers.erase(docker)
