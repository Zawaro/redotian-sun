class_name UnitOrderGenerator extends OrderGenerator

## Priority of the synthesized ground MOVE. Force-fire keeps only component
## orders that outrank it, so a component's own MOVE cannot displace the
## request_move()-based one with its formation, queue and target-level handling.
const GROUND_MOVE_PRIORITY: int = 5

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
        # Non-local (enemy) selections are viewing-only: no command cursors and no
        # orders. A selectable, not-yet-selected target still shows SELECT so the
        # player can click to re-select (TS ACTION_SELECT on a hovered selectable);
        # everything else (ground, the selected enemy itself) is DEFAULT.
        var locals := _local_selection(sm)
        if locals.is_empty():
            if target and target.is_in_group("selectable") and not _is_already_selected(target, sm):
                return CursorState.Type.SELECT
            return CursorState.Type.DEFAULT
        if not target:
            # Force-fire turns a bare cell into a fire target: resolve the same
            # way the entity branch does so the cursor mirrors the order that
            # would actually be issued. Without the modifier this stays on the
            # untouched MOVE/undeploy path below.
            if modifiers.get(OrderResult.MOD_FORCE_ATTACK, false):
                var forced := OrderResolver.resolve_single(
                    locals, target, target_cell, target_pos, modifiers
                )
                if forced and forced.priority > GROUND_MOVE_PRIORITY:
                    return forced.cursor
            if _has_undeployable(sm):
                var result := OrderResolver.resolve_single(
                    locals, target, target_cell, target_pos, modifiers
                )
                cursor = result.cursor if result else CursorState.Type.MOVE
            elif _has_movable(sm):
                cursor = CursorState.Type.MOVE
        else:
            var result: OrderResult = OrderResolver.resolve_single(
                locals, target, target_cell, target_pos, modifiers
            )
            if result:
                cursor = result.cursor
            elif _is_already_selected(target, sm):
                if target.get_node_or_null("MovementController"):
                    cursor = CursorState.Type.MOVE
                else:
                    cursor = CursorState.Type.GENERIC_BLOCKED
            elif target.is_in_group("selectable"):
                cursor = CursorState.Type.SELECT
            elif _has_movable(sm):
                cursor = CursorState.Type.MOVE
            elif _has_undeployable(sm):
                cursor = CursorState.Type.MOVE
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
    var locals := _local_selection(sm)
    if locals.is_empty():
        return []
    var result: Array[OrderResult] = []
    var target_level: int = int(modifiers.get(OrderResult.MOD_TARGET_LEVEL, 0))
    if not target:
        # Force-fire: let components answer for the cell instead of
        # unconditionally synthesizing a move. Only orders above the plain
        # movement priority are kept — a component's own MOVE would bypass
        # formation, queued and target-level handling in request_move().
        if modifiers.get(OrderResult.MOD_FORCE_ATTACK, false):
            var forced := OrderResolver.resolve_all(
                locals, target, target_cell, target_pos, modifiers
            )
            var attacks: Array[OrderResult] = []
            for order in forced:
                if order.priority > GROUND_MOVE_PRIORITY:
                    attacks.append(order)
            if not attacks.is_empty():
                return attacks
        if _has_undeployable(sm):
            result = OrderResolver.resolve_all(locals, target, target_cell, target_pos, modifiers)
        elif _has_movable(sm):
            var queued: bool = modifiers.get(OrderResult.MOD_QUEUED, false)
            var move_order := OrderResult.new(
                CursorState.Type.MOVE,
                5,
                null,
                target_pos,
                queued,
                func(): sm.request_move(target_pos, false, target_level),
            )
            move_order.target_level = target_level
            result = [move_order]
    else:
        result = OrderResolver.resolve_all(locals, target, target_cell, target_pos, modifiers)
        if result.is_empty() and _is_already_selected(target, sm):
            if target.get_node_or_null("MovementController"):
                var queued: bool = modifiers.get(OrderResult.MOD_QUEUED, false)
                var move_order := OrderResult.new(
                    CursorState.Type.MOVE,
                    5,
                    target,
                    target_pos,
                    queued,
                    func(): sm.request_move(target_pos, true, target_level),
                )
                move_order.target_level = target_level
                result = [move_order]
    return result


## Selected entities owned by the local player (missing StatsComponent or
## player_id < 0 counts as local, matching `_is_local_entity`). Non-local (enemy)
## entities contribute no cursor or orders — selecting one is viewing only.
func _local_selection(sm: SelectionManager) -> Array[SelectComponent]:
    var locals: Array[SelectComponent] = []
    for sc in sm.selected_entities:
        if not is_instance_valid(sc):
            continue
        var entity := sc.get_parent() as Node3D
        if not is_instance_valid(entity):
            continue
        if _is_local_entity(entity):
            locals.append(sc)
    return locals


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
    return PlayerManager.is_entity_local(entity, PlayerManager.get_local_player_id())


func _is_enemy(target: Node3D) -> bool:
    var stats := target.get_node_or_null("StatsComponent") as StatsComponent
    if not stats or stats.player_id < 0:
        return false
    return PlayerManager.is_enemy(stats.player_id, PlayerManager.get_local_player_id())


func _is_already_selected(target: Node3D, sm: SelectionManager) -> bool:
    var target_sc := target.get_node_or_null("SelectComponent") as SelectComponent
    if not target_sc:
        return false
    return target_sc in sm.selected_entities


func _get_selection_manager() -> SelectionManager:
    return Engine.get_main_loop().root.get_node_or_null("SelectionManager") as SelectionManager
