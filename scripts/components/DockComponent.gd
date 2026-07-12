class_name DockComponent extends Node

@export var dock_position: Vector3 = Vector3.ZERO
@export var dock_rotation: float = 0.0
@export var foundation: Vector2i = Vector2i(1, 1)
@export var allowed_entities: PackedStringArray = []

var queue: Array[Node] = []
var current_docker: Node = null
var _entity_data: EntityData = null
var _dock_cell: Vector2i = Vector2i.ZERO

signal docker_docked(docker: Node)
signal docker_undocked(docker: Node)
signal slot_available


func _ready() -> void:
    if Engine.is_editor_hint():
        return
    _compute_dock_cell()
    if _entity_data:
        call_deferred("_log_cells", _entity_data)


func configure(data: EntityData) -> void:
    _entity_data = data
    dock_position = data.dock_position
    dock_rotation = data.dock_rotation
    foundation = data.foundation
    allowed_entities = [data.dock] if not data.dock.is_empty() else []


func _compute_dock_cell() -> void:
    var entity := get_parent() as Node3D
    if not entity:
        return
    var cs := Pathfinder.CELL_SIZE
    var origin_cell := Vector2i(
        floori((entity.global_position.x - foundation.x * 0.5 * cs) / cs),
        floori((entity.global_position.z - foundation.y * 0.5 * cs) / cs)
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


func _log_cells(data: EntityData) -> void:
    var entity := get_parent() as Node3D
    if not entity:
        return
    var cs := Pathfinder.CELL_SIZE
    var origin_cell := Vector2i(
        floori((entity.global_position.x - data.foundation.x * 0.5 * cs) / cs),
        floori((entity.global_position.z - data.foundation.y * 0.5 * cs) / cs)
    )
    var top_left_world := Pathfinder.cell_to_world(origin_cell)

    var foundation_cells_local: Array[Vector2i] = []
    for dx in data.foundation.x:
        for dz in data.foundation.y:
            foundation_cells_local.append(Vector2i(dx, dz))

    var bib_cells_local: Array[Vector2i] = []
    for offset in data.bib_cells:
        bib_cells_local.append(offset)

    var dock_local := Vector2i(int(dock_position.x / cs), int(dock_position.z / cs))
    var dock_global := Pathfinder.world_to_cell(
        top_left_world + entity.global_transform.basis * dock_position
    )

    print("=== %s ===" % data.id)
    print("  origin_cell: %s  top-left world: %s" % [origin_cell, top_left_world])
    print("  building world: %s" % entity.global_position)
    print("  foundation local (%d cells):" % foundation_cells_local.size())
    for c in foundation_cells_local:
        print("    %s → %s" % [c, Pathfinder.cell_to_world(origin_cell + c)])
    print("  bib local (%d cells):" % bib_cells_local.size())
    for c in bib_cells_local:
        print("    %s → %s" % [c, Pathfinder.cell_to_world(origin_cell + c)])
    print("  dock local: %s  world: %s" % [dock_local, dock_global])
    print("  dock_position: %s (relative to top-left)" % dock_position)


func can_dock(entity_id: String) -> bool:
    return allowed_entities.is_empty() or entity_id in allowed_entities


func get_entity_id() -> String:
    return _entity_data.id if _entity_data else ""


func request_dock(docker: Node) -> bool:
    var docker_id: String = docker.get_dock_id() if docker.has_method("get_dock_id") else ""
    if not can_dock(docker_id):
        return false
    if current_docker == docker:
        return true
    if current_docker == null:
        current_docker = docker
        docker_docked.emit(docker)
        if SpatialHash.instance:
            SpatialHash.instance.force_reserve(_dock_cell)
        return true
    if docker in queue:
        return false
    queue.append(docker)
    return false


func leave_dock(docker: Node) -> void:
    if current_docker == docker:
        if SpatialHash.instance:
            SpatialHash.instance.release_cell(_dock_cell)
        current_docker = null
        docker_undocked.emit(docker)
        if not queue.is_empty():
            var next_docker = queue.pop_front()
            current_docker = next_docker
            if SpatialHash.instance:
                SpatialHash.instance.force_reserve(_dock_cell)
            docker_docked.emit(next_docker)
            slot_available.emit()
            if next_docker.has_method("on_slot_available"):
                next_docker.on_slot_available()
    else:
        var idx := queue.find(docker)
        if idx >= 0:
            queue.remove_at(idx)
