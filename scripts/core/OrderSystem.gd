extends Node

var active_generator: OrderGenerator = UnitOrderGenerator.get_instance()


func get_cursor(
    target: Node3D,
    target_cell: Vector2i,
    target_pos: Vector3,
    modifiers: Dictionary,
) -> CursorState.Type:
    return active_generator.get_cursor(target, target_cell, target_pos, modifiers)


func get_orders(
    target: Node3D,
    target_cell: Vector2i,
    target_pos: Vector3,
    modifiers: Dictionary,
) -> Array[OrderResult]:
    return active_generator.get_orders(target, target_cell, target_pos, modifiers)


func set_generator(gen: OrderGenerator) -> void:
    active_generator = gen


func cancel() -> void:
    active_generator.cancel()
    active_generator = UnitOrderGenerator.get_instance()
