# ponytail: thin data wrapper, grows when foundation validation or placement logic is needed
class_name FoundationComponent extends Node

@export var foundation: Vector2i = Vector2i(1, 1)
@export var height: float = 1.0


func configure(data: EntityData) -> void:
    foundation = data.foundation
    height = data.height


func get_cell_count() -> int:
    return foundation.x * foundation.y
