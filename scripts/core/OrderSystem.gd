extends Node

var active_generator: OrderGenerator = UnitOrderGenerator.get_instance()


func get_cursor(
    target: Node3D,
    target_cell: Vector2i,
    target_pos: Vector3,
    modifiers: Dictionary,
) -> CursorState.Type:
    if _target_out_of_bounds(target, target_cell):
        return CursorState.Type.GENERIC_BLOCKED
    var bounded_pos := _bounded_target_pos(target, target_pos)
    var effective := _fog_filter_target(target, target_cell, modifiers)
    return active_generator.get_cursor(
        effective.target, effective.target_cell, bounded_pos, effective.modifiers
    )


func get_orders(
    target: Node3D,
    target_cell: Vector2i,
    target_pos: Vector3,
    modifiers: Dictionary,
) -> Array[OrderResult]:
    if _target_out_of_bounds(target, target_cell):
        return []
    var bounded_pos := _bounded_target_pos(target, target_pos)
    var effective := _fog_filter_target(target, target_cell, modifiers)
    return active_generator.get_orders(
        effective.target, effective.target_cell, bounded_pos, effective.modifiers
    )


## Bounds gate: a player-initiated order whose entity target sits outside the
## visible (inset) playable diamond is rejected outright — never turned into a
## move. Ground orders (null target) fall through to the move path, which is
## clamped to the visible edge by `_bounded_target_pos`. Callers pass a real
## entity cell (MouseHandler resolves it from the raycast hit).
func _target_out_of_bounds(target: Node3D, target_cell: Vector2i) -> bool:
    if target == null:
        return false
    return not BoundsSystem.is_in_play_area_with_margin(target_cell, BoundsSystem.ORDER_EDGE_INSET)


## For a null (ground) target, clamp the world position into the visible diamond
## so moves and ground-attacks land on the boundary. Entity targets keep their
## exact position (their out-of-bounds case was already rejected above).
func _bounded_target_pos(target: Node3D, target_pos: Vector3) -> Vector3:
    if target != null:
        return target_pos
    return BoundsSystem.clamp_to_visible_diamond(target_pos, BoundsSystem.ORDER_EDGE_INSET)


## Fog gate: when fog of war is enabled, a target whose cell is not visible to
## the local player behaves as absent — it falls through to the move path and
## cannot be attacked (including force-fire). Buildings use their foundation
## footprint: any explored foundation cell keeps them targetable.
func _fog_filter_target(target: Node3D, target_cell: Vector2i, modifiers: Dictionary) -> Dictionary:
    if target == null:
        return {"target": null, "target_cell": target_cell, "modifiers": modifiers}
    var stats := target.get_node_or_null("StatsComponent") as StatsComponent
    var revealed: bool
    if stats != null and stats.entity_type == EntityData.EntityType.BUILDING:
        revealed = ShroudSystem.is_entity_revealed_to_local(target)
    else:
        var cell := target_cell
        if cell == Vector2i.ZERO:
            cell = CellUtil.world_to_cell(target.global_position)
        revealed = ShroudSystem.is_cell_visible_to_local(cell)
    if revealed:
        return {"target": target, "target_cell": target_cell, "modifiers": modifiers}
    var filtered := modifiers.duplicate()
    filtered.erase(OrderResult.MOD_FORCE_ATTACK)
    return {"target": null, "target_cell": target_cell, "modifiers": filtered}


func set_generator(gen: OrderGenerator) -> void:
    active_generator = gen


func cancel() -> void:
    active_generator.cancel()
    active_generator = UnitOrderGenerator.get_instance()
