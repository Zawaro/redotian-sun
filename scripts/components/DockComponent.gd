class_name DockComponent extends Node

@export var dock_position: Vector3 = Vector3.ZERO
@export var dock_rotation: float = 0.0
@export var allowed_entities: PackedStringArray = []
@export var unload_rate: float = 28.0
@export var load_rate: float = 0.0

var queue: Array = []
var current_docker = null

signal slot_available


func configure(data: EntityData) -> void:
    dock_position = data.dock_position
    dock_rotation = data.dock_rotation
    allowed_entities = [data.dock] if not data.dock.is_empty() else []


func can_dock(entity_id: String) -> bool:
    return allowed_entities.is_empty() or entity_id in allowed_entities


func request_dock(docker) -> bool:
    var docker_id := docker.get_dock_id() if docker.has_method("get_dock_id") else ""
    if not can_dock(docker_id):
        return false
    if current_docker == null:
        current_docker = docker
        return true
    if docker in queue:
        return false
    queue.append(docker)
    return false


func leave_dock(docker) -> void:
    if current_docker == docker:
        current_docker = null
        if not queue.is_empty():
            var next_docker = queue.pop_front()
            current_docker = next_docker
            slot_available.emit()
            if next_docker.has_method("on_slot_available"):
                next_docker.on_slot_available()
    else:
        var idx := queue.find(docker)
        if idx >= 0:
            queue.remove_at(idx)
