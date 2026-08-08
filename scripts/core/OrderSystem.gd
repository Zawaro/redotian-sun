extends Node

var active_generator: OrderGenerator = UnitOrderGenerator.get_instance()


func get_cursor(
    target: Node3D,
    target_cell: Vector2i,
    target_pos: Vector3,
    modifiers: Dictionary,
) -> CursorState.Type:
    var effective := _fog_filter_target(target, target_cell, modifiers)
    return active_generator.get_cursor(
        effective.target, effective.target_cell, target_pos, effective.modifiers
    )


func get_orders(
    target: Node3D,
    target_cell: Vector2i,
    target_pos: Vector3,
    modifiers: Dictionary,
) -> Array[OrderResult]:
    var effective := _fog_filter_target(target, target_cell, modifiers)
    return active_generator.get_orders(
        effective.target, effective.target_cell, target_pos, effective.modifiers
    )


## Fog gate: when fog of war is enabled, a target whose cell is not visible to
## the local player behaves as absent — it falls through to the move path and
## cannot be attacked (including force-fire).
func _fog_filter_target(target: Node3D, target_cell: Vector2i, modifiers: Dictionary) -> Dictionary:
    if target == null:
        return {"target": null, "target_cell": target_cell, "modifiers": modifiers}
    var cell := target_cell
    if cell == Vector2i.ZERO:
        cell = CellUtil.world_to_cell(target.global_position)
    if ShroudSystem.is_cell_visible_to_local(cell):
        return {"target": target, "target_cell": target_cell, "modifiers": modifiers}
    var filtered := modifiers.duplicate()
    filtered.erase(OrderResult.MOD_FORCE_ATTACK)
    return {"target": null, "target_cell": target_cell, "modifiers": filtered}


func set_generator(gen: OrderGenerator) -> void:
    active_generator = gen


func cancel() -> void:
    active_generator.cancel()
    active_generator = UnitOrderGenerator.get_instance()
