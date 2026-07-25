class_name UnitOrderGenerator extends OrderGenerator

static var _singleton: UnitOrderGenerator = null


static func get_instance() -> UnitOrderGenerator:
    if not _singleton:
        _singleton = UnitOrderGenerator.new()
    return _singleton


func get_cursor(
    target: Node3D,
    target_cell: Vector2i,
    target_pos: Vector3,
    modifiers: Dictionary,
) -> CursorState.Type:
    var cursor := CursorState.Type.DEFAULT
    var sm := _get_selection_manager()
    if sm and not sm.selected_entities.is_empty():
        if not target:
            if _has_undeployable(sm):
                var result := OrderResolver.resolve_single(
                    sm.selected_entities, target, target_cell, target_pos, modifiers
                )
                cursor = result.cursor if result else CursorState.Type.MOVE
            elif _has_movable(sm):
                cursor = CursorState.Type.MOVE
        else:
            var result: OrderResult = OrderResolver.resolve_single(
                sm.selected_entities, target, target_cell, target_pos, modifiers
            )
            if result:
                cursor = result.cursor
            elif target.is_in_group("selectable"):
                cursor = CursorState.Type.SELECT
    return cursor


func get_orders(
    target: Node3D,
    target_cell: Vector2i,
    target_pos: Vector3,
    modifiers: Dictionary,
) -> Array[OrderResult]:
    var sm := _get_selection_manager()
    if not sm or sm.selected_entities.is_empty():
        return []
    # Terrain click — check for undeploy before group move
    if not target:
        if _has_undeployable(sm):
            return OrderResolver.resolve_all(
                sm.selected_entities, target, target_cell, target_pos, modifiers
            )
        # Only issue move order if at least one entity can move
        if not _has_movable(sm):
            return []
        var queued: bool = modifiers.get(OrderResult.MOD_QUEUED, false)
        return [
            OrderResult.new(
                CursorState.Type.MOVE,
                5,
                null,
                target_pos,
                queued,
                func(): sm.request_move(target_pos),
            )
        ]
    # Entity click — per-entity orders (attack, harvest, deploy, etc.)
    return OrderResolver.resolve_all(
        sm.selected_entities, target, target_cell, target_pos, modifiers
    )


func _has_undeployable(sm: SelectionManager) -> bool:
    for sc in sm.selected_entities:
        if not is_instance_valid(sc):
            continue
        var entity := sc.get_parent() as Node3D
        if not is_instance_valid(entity):
            continue
        if not _is_local_entity(entity):
            continue
        var deploy := entity.get_node_or_null("DeployComponent") as DeployComponent
        if deploy and deploy.can_undeploy():
            return true
    return false


func _has_movable(sm: SelectionManager) -> bool:
    for sc in sm.selected_entities:
        if not is_instance_valid(sc):
            continue
        var entity := sc.get_parent() as Node3D
        if not is_instance_valid(entity):
            continue
        if not entity.get_node_or_null("MovementController"):
            continue
        if not _is_local_entity(entity):
            continue
        return true
    return false


func _is_local_entity(entity: Node3D) -> bool:
    var stats := entity.get_node_or_null("StatsComponent") as StatsComponent
    if not stats:
        return true
    return stats.player_id < 0 or stats.player_id == PlayerManager.get_local_player_id()


func _get_selection_manager() -> SelectionManager:
    return Engine.get_main_loop().root.get_node_or_null("SelectionManager") as SelectionManager
