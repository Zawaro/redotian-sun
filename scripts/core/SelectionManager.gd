extends Node

signal selection_changed(selected_entities: Array[SelectComponent])
signal hover_changed(entity: SelectComponent)

var selected_entities: Array[SelectComponent] = []
var is_hovering: bool = false
var hovered_entity: SelectComponent = null

var _pending_moves: Array[Array] = []
var _pending_index: int = 0


func _ready():
    if not Engine.is_editor_hint():
        print("✅ SelectionManager loaded successfully!")


func select_entity(entity: SelectComponent, shift_pressed: bool = false):
    if not entity:
        return

    if shift_pressed and entity in selected_entities:
        remove_entity(entity)
        return

    if shift_pressed:
        add_entity(entity)
    else:
        deselect_all()
        add_entity(entity)


func deselect_entity(entity: SelectComponent):
    remove_entity(entity)


func deselect_all():
    clear_hover_preview()
    for entity in selected_entities:
        if is_instance_valid(entity) and entity.has_method("set_is_selected"):
            entity.set_is_selected(false)
    var tree := get_tree()
    if tree:
        for entity in tree.get_nodes_in_group("selectable"):
            var select_comp := entity.get_node_or_null("SelectComponent") as SelectComponent
            if select_comp and select_comp.is_selected:
                select_comp.set_is_selected(false)
    selected_entities.clear()
    emit_signal("selection_changed", [])


func add_entity(entity: SelectComponent):
    if entity and is_instance_valid(entity) and not selected_entities.has(entity):
        selected_entities.append(entity)

        if entity.has_method("set_is_selected"):
            entity.set_is_selected(true)

        emit_signal("selection_changed", selected_entities.duplicate())


func remove_entity(entity: SelectComponent):
    if entity in selected_entities:
        selected_entities.erase(entity)

        if is_instance_valid(entity) and entity.has_method("set_is_selected"):
            entity.set_is_selected(false)

        emit_signal("selection_changed", selected_entities.duplicate())


func toggle_entity(entity: SelectComponent):
    if entity in selected_entities:
        remove_entity(entity)
    else:
        add_entity(entity)


func set_hover_preview(enabled: bool, entity: SelectComponent = null):
    if enabled and entity == hovered_entity:
        return

    is_hovering = enabled

    if hovered_entity and is_instance_valid(hovered_entity) and hovered_entity != entity:
        hovered_entity.set_is_hovering(false)
        hovered_entity = null

    if enabled and entity and is_instance_valid(entity):
        hovered_entity = entity
        hovered_entity.set_is_hovering(true)
        emit_signal("hover_changed", entity)


func clear_hover_preview():
    set_hover_preview(false, null)


func request_move(target_position: Vector3) -> void:
    if selected_entities.is_empty():
        return

    SpatialHash.instance.clear_reservations()

    for ent in selected_entities:
        if not is_instance_valid(ent):
            continue
        var parent := ent.get_parent() as Node3D
        if _is_entity_transitioning(parent):
            continue
        if not _is_local_entity(ent):
            continue
        if is_instance_valid(parent):
            SpatialHash.instance.force_reserve(CellUtil.world_to_cell(parent.global_position))

    var center := Vector3.ZERO
    var count := 0
    for ent in selected_entities:
        if not is_instance_valid(ent):
            continue
        var parent := ent.get_parent() as Node3D
        if _is_entity_transitioning(parent):
            continue
        if not _is_local_entity(ent):
            continue
        if is_instance_valid(parent):
            center += parent.global_position
            count += 1
    if count == 0:
        return
    center /= count

    _pending_moves.clear()
    _pending_index = 0

    var infantry: Array[SelectComponent] = []
    var vehicles: Array[SelectComponent] = []

    # Snapshot — undeploy mutates selected_entities mid-loop
    var snapshot := selected_entities.duplicate()
    for ent in snapshot:
        if not is_instance_valid(ent):
            continue
        var parent := ent.get_parent() as Node3D
        if not is_instance_valid(parent):
            continue
        if _is_entity_transitioning(parent):
            continue
        if not _is_local_entity(ent):
            continue

        # Check for deploy component on buildings — trigger undeploy instead of move
        var deploy := parent.get_node_or_null("DeployComponent") as DeployComponent
        if deploy and deploy.can_undeploy():
            var deploy_stats := parent.get_node_or_null("StatsComponent") as StatsComponent
            if deploy_stats and deploy_stats.entity_type == EntityData.EntityType.BUILDING:
                var undeploy_offset := parent.global_position - center
                var undeploy_cell_offset := Vector2i(
                    roundi(undeploy_offset.x / CellUtil.CELL_SIZE),
                    roundi(undeploy_offset.z / CellUtil.CELL_SIZE)
                )
                undeploy_cell_offset.x = clampi(undeploy_cell_offset.x, -2, 2)
                undeploy_cell_offset.y = clampi(undeploy_cell_offset.y, -2, 2)
                var undeploy_target := (
                    target_position
                    + Vector3(
                        undeploy_cell_offset.x * CellUtil.CELL_SIZE,
                        0,
                        undeploy_cell_offset.y * CellUtil.CELL_SIZE
                    )
                )
                deploy.execute_undeploy(parent, undeploy_target)
                continue

        var stats := parent.get_node_or_null("StatsComponent") as StatsComponent
        if stats and stats.entity_type == EntityData.EntityType.INFANTRY:
            infantry.append(ent)
        else:
            vehicles.append(ent)

    var cell_occupancy: Dictionary = {}
    var target_cell := CellUtil.world_to_cell(target_position)
    var existing_count := SpatialHash.instance.get_infantry_count(target_cell)
    if existing_count > 0:
        cell_occupancy[CellUtil.cell_key(target_cell)] = existing_count
    for inf in infantry:
        var parent := inf.get_parent() as Node3D
        if not is_instance_valid(parent):
            continue
        var assigned_cell := _find_infantry_cell(target_position, cell_occupancy)
        var cell_key := CellUtil.cell_key(assigned_cell)
        var slot: int = cell_occupancy.get(cell_key, 0)
        cell_occupancy[cell_key] = slot + 1
        var cell_center := CellUtil.cell_to_world(assigned_cell)
        var mc := parent.get_node_or_null("MovementController") as MovementController
        if mc:
            mc._assigned_slot = slot
        _pending_moves.append([inf, cell_center])

    for ent in vehicles:
        var parent := ent.get_parent() as Node3D
        if not is_instance_valid(parent):
            continue
        var offset := parent.global_position - center
        var cell_offset := Vector2i(
            roundi(offset.x / CellUtil.CELL_SIZE), roundi(offset.z / CellUtil.CELL_SIZE)
        )
        if abs(cell_offset.x) > 2 or abs(cell_offset.y) > 2:
            cell_offset.x = clampi(cell_offset.x, -2, 2)
            cell_offset.y = clampi(cell_offset.y, -2, 2)
        var target := (
            target_position
            + Vector3(cell_offset.x * CellUtil.CELL_SIZE, 0, cell_offset.y * CellUtil.CELL_SIZE)
        )
        var cell := CellUtil.world_to_cell(target)
        if not SpatialHash.instance.reserve_cell(cell):
            target = _fallback_target(target)
        _pending_moves.append([ent, target])


func request_harvest(target: Node3D) -> bool:
    var issued := false
    for ent in selected_entities:
        if not is_instance_valid(ent):
            continue
        var parent := ent.get_parent() as Node3D
        if not is_instance_valid(parent) or _is_entity_transitioning(parent):
            continue
        if not _is_local_entity(ent):
            continue
        var harvest := parent.get_node_or_null("HarvestComponent") as HarvestComponent
        if harvest:
            harvest.set_target_node(target)
            issued = true
    return issued


func request_dock(target: Node3D) -> bool:
    var dock_comp := target.get_node_or_null("DockHostComponent") as DockHostComponent
    if not dock_comp:
        return false
    var target_id := dock_comp.get_entity_id()
    var issued := false
    for ent in selected_entities:
        if not is_instance_valid(ent):
            continue
        var parent := ent.get_parent() as Node3D
        if not is_instance_valid(parent) or _is_entity_transitioning(parent):
            continue
        if not _is_local_entity(ent):
            continue
        var harvest := parent.get_node_or_null("HarvestComponent") as HarvestComponent
        if not harvest:
            continue
        var transport := parent.get_node_or_null("TransportComponent") as TransportComponent
        if transport and not transport.dock.is_empty() and transport.dock != target_id:
            continue
        harvest.set_target_refinery(target)
        issued = true
    return issued


func _process(_delta: float) -> void:
    _synchronize_visual_selection()
    var batch: int = 8
    while _pending_index < _pending_moves.size() and batch > 0:
        var data: Array = _pending_moves[_pending_index]
        _execute_move(data[0] as SelectComponent, data[1] as Vector3)
        _pending_index += 1
        batch -= 1


func _synchronize_visual_selection() -> void:
    var tree := get_tree()
    if not tree:
        return
    for entity in tree.get_nodes_in_group("selectable"):
        var select_comp := entity.get_node_or_null("SelectComponent") as SelectComponent
        if select_comp and select_comp.is_selected and not selected_entities.has(select_comp):
            add_entity(select_comp)


func _execute_move(select_comp: SelectComponent, position: Vector3) -> void:
    var parent := select_comp.get_parent() as Node
    if not is_instance_valid(parent):
        return
    if _is_entity_transitioning(parent as Node3D):
        return
    if not parent.has_node("MovementController"):
        return
    var mc := parent.get_node("MovementController") as MovementController
    if is_instance_valid(mc):
        mc.set_target_position(position)
    var harvest := parent.get_node_or_null("HarvestComponent") as HarvestComponent
    if harvest:
        harvest.cancel_harvest(true)


func _fallback_target(target: Vector3) -> Vector3:
    var cell := CellUtil.world_to_cell(target)
    var result := CellUtil.spiral_first_free(
        cell, 8, func(c: Vector2i) -> bool: return not SpatialHash.instance.reserve_cell(c)
    )
    if result == cell:
        return target
    return CellUtil.cell_to_world(result)


func _is_entity_transitioning(entity: Node3D) -> bool:
    if not is_instance_valid(entity):
        return false
    var deploy := entity.get_node_or_null("DeployComponent") as DeployComponent
    return deploy != null and deploy.is_transitioning()


func is_entity_selected(entity: SelectComponent) -> bool:
    return selected_entities.has(entity)


func get_selected_entities():
    return selected_entities


func _is_local_entity(select_comp: SelectComponent) -> bool:
    var parent := select_comp.get_parent() as Node3D
    if not is_instance_valid(parent):
        return false
    var stats := parent.get_node_or_null("StatsComponent") as StatsComponent
    if not stats:
        return true
    return stats.player_id < 0 or stats.player_id == PlayerManager.get_local_player_id()


func request_deploy() -> void:
    if selected_entities.is_empty():
        return
    for ent in selected_entities:
        var parent := ent.get_parent() as Node3D
        if not is_instance_valid(parent):
            continue
        if not _is_local_entity(ent):
            continue
        var deploy := parent.get_node_or_null("DeployComponent") as DeployComponent
        if not deploy or not deploy.can_deploy():
            continue
        # Check if entity is idle (for vehicles with MovementController)
        var mc := parent.get_node_or_null("MovementController") as MovementController
        if mc and mc._state != MovementController.State.IDLE:
            push_warning("[SelectionManager] Cannot deploy — entity is moving")
            continue
        deploy.execute_deploy(parent)


func request_set_rally_point(target_position: Vector3) -> void:
    var cell := CellUtil.world_to_cell(target_position)
    for ent in selected_entities:
        if not is_instance_valid(ent):
            continue
        if not _is_local_entity(ent):
            continue
        var parent := ent.get_parent() as Node3D
        if not is_instance_valid(parent):
            continue
        var rally := parent.get_node_or_null("RallyPointComponent") as RallyPointComponent
        if rally:
            rally.set_rally_point(cell)


func _find_infantry_cell(target_position: Vector3, occupancy: Dictionary) -> Vector2i:
    var target := CellUtil.world_to_cell(target_position)
    return CellUtil.spiral_first_free(
        target,
        4,
        func(cell: Vector2i) -> bool:
            var key := CellUtil.cell_key(cell)
            if occupancy.get(key, 0) >= 3:
                return true
            if SpatialHash.instance.is_cell_blocked(cell):
                return true
            return false
    )
