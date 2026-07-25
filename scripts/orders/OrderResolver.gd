class_name OrderResolver


static func resolve_all(
    selected_entities: Array[SelectComponent],
    target: Node3D,
    target_cell: Vector2i,
    target_pos: Vector3,
    modifiers: Dictionary,
) -> Array[OrderResult]:
    var results: Array[OrderResult] = []
    for entity_idx in selected_entities.size():
        var select_comp: SelectComponent = selected_entities[entity_idx]
        if not is_instance_valid(select_comp):
            continue
        var entity: Node3D = select_comp.get_parent() as Node3D
        if not is_instance_valid(entity):
            continue
        var best: OrderResult = _best_for_entity(
            entity, entity_idx, target, target_cell, target_pos, modifiers
        )
        if best:
            results.append(best)
    return results


static func resolve_single(
    selected_entities: Array[SelectComponent],
    target: Node3D,
    target_cell: Vector2i,
    target_pos: Vector3,
    modifiers: Dictionary,
) -> OrderResult:
    var best: OrderResult = null
    for entity_idx in selected_entities.size():
        var select_comp: SelectComponent = selected_entities[entity_idx]
        if not is_instance_valid(select_comp):
            continue
        var entity: Node3D = select_comp.get_parent() as Node3D
        if not is_instance_valid(entity):
            continue
        var candidate: OrderResult = _best_for_entity(
            entity, entity_idx, target, target_cell, target_pos, modifiers
        )
        if candidate and (not best or _is_better(candidate, best)):
            best = candidate
    return best


static func _best_for_entity(
    entity: Node3D,
    _entity_idx: int,
    target: Node3D,
    target_cell: Vector2i,
    target_pos: Vector3,
    modifiers: Dictionary,
) -> OrderResult:
    var best: OrderResult = null
    for child in entity.get_children():
        if child.has_method("get_order_for_target"):
            var result: OrderResult = child.get_order_for_target(
                target, target_cell, target_pos, modifiers
            )
            if result and (not best or _is_better(result, best)):
                best = result
    return best


static func _is_better(candidate: OrderResult, current: OrderResult) -> bool:
    if candidate.priority > current.priority:
        return true
    if candidate.priority < current.priority:
        return false
    return false
