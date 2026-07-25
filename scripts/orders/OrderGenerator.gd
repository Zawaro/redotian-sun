class_name OrderGenerator


func get_cursor(
    _target: Node3D,
    _target_cell: Vector2i,
    _target_pos: Vector3,
    _modifiers: Dictionary,
) -> CursorState.Type:
    return CursorState.Type.DEFAULT


func get_orders(
    _target: Node3D,
    _target_cell: Vector2i,
    _target_pos: Vector3,
    _modifiers: Dictionary,
) -> Array[OrderResult]:
    return []


func cancel() -> void:
    pass
