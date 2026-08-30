extends Node

## Emitted after set_generator() installs a generator and after cancel()
## resets to the unit generator, so UI (e.g. Sidebar buttons) can sync its
## visual state from the signal instead of being told imperatively.
signal generator_changed

var active_generator: OrderGenerator = UnitOrderGenerator.get_instance()


func get_cursor(
    target: Node3D,
    target_cell: Vector2i,
    target_pos: Vector3,
    modifiers: Dictionary,
) -> CursorState.Type:
    var bounds := _order_bounds(target, target_cell, target_pos)
    if bounds.blocked:
        return CursorState.Type.GENERIC_BLOCKED
    var effective := _fog_filter_target(target, target_cell, modifiers)
    return active_generator.get_cursor(
        effective.target, effective.target_cell, bounds.pos, effective.modifiers
    )


func get_orders(
    target: Node3D,
    target_cell: Vector2i,
    target_pos: Vector3,
    modifiers: Dictionary,
) -> Array[OrderResult]:
    var bounds := _order_bounds(target, target_cell, target_pos)
    if bounds.blocked:
        return []
    var effective := _fog_filter_target(target, target_cell, modifiers)
    return active_generator.get_orders(
        effective.target, effective.target_cell, bounds.pos, effective.modifiers
    )


## Bounds gate — the single decision point for order targets (callers must not
## branch on `target` nullness themselves). A player-initiated order whose
## entity target sits outside the visible (inset) playable diamond is rejected
## outright — never turned into a move. Ground orders (null target) fall
## through to the move path with their position clamped to the visible edge.
## Callers pass a real entity cell (MouseHandler resolves it from the raycast
## hit). Runs before the fog gate: a rejected out-of-bounds target stays
## BLOCKED even when shrouded.
func _order_bounds(target: Node3D, target_cell: Vector2i, target_pos: Vector3) -> Dictionary:
    if target != null:
        return {"blocked": not BoundsSystem.is_in_order_area(target_cell), "pos": target_pos}
    return {
        "blocked": false,
        "pos": BoundsSystem.clamp_to_visible_diamond(target_pos, BoundsSystem.ORDER_EDGE_INSET),
    }


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


## Sell/repair mode is derived from the active generator's type — no parallel
## booleans anywhere. is_action_mode() is the generic "not unit orders" query
## for gameplay guards (MouseHandler order routing, PauseMenu ESC handling),
## which must read these instead of any UI script's mode state.
func is_sell_mode() -> bool:
    return active_generator is SellOrderGenerator


func is_repair_mode() -> bool:
    return active_generator is RepairOrderGenerator


func is_action_mode() -> bool:
    return not active_generator is UnitOrderGenerator


func set_generator(gen: OrderGenerator) -> void:
    active_generator = gen
    generator_changed.emit()


func cancel() -> void:
    active_generator.cancel()
    active_generator = UnitOrderGenerator.get_instance()
    generator_changed.emit()
