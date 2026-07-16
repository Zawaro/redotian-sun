class_name ProductionQueue extends RefCounted

## A single item in a production queue.
var entity_data: EntityData
var progress: float = 0.0
var is_paused: bool = false
var count: int = 1
var deducted: float = 0.0


func _init(data: EntityData, queue_count: int = 1) -> void:
    entity_data = data
    count = queue_count
