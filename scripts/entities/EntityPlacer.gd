extends Node

## Centralized entity placement system. Handles creating, positioning, and
## adding entities to the scene. Manages inert preview entities for placement
## mode (frozen, non-interactive, transparent until finalized).

signal entity_placed(entity: Node3D, entity_data: EntityData)

var _preview: Node3D = null
var _preview_data: EntityData = null
var _preview_original_layers: Dictionary = {}
var _preview_original_surface_overrides: Dictionary = {}


func place_entity(
    entity_data: EntityData, world_pos: Vector3, player_id: int, parent: Node3D = null
) -> Node3D:
    var entity := EntityFactory.create_entity(entity_data.id)
    if not entity:
        return null
    var stats := entity.get_node_or_null("StatsComponent") as StatsComponent
    if stats:
        stats.player_id = player_id
    entity.position = world_pos
    var target := parent if parent else get_tree().current_scene
    target.add_child(entity)
    entity_placed.emit(entity, entity_data)
    return entity


# --- Preview system ---


func start_preview(entity_data: EntityData) -> void:
    cancel_preview()
    var entity := EntityFactory.create_entity(entity_data.id)
    if not entity:
        return
    # Make inert: remove from all groups, disable processing, disable collision
    _remove_preview_groups(entity)
    entity.process_mode = Node.PROCESS_MODE_DISABLED
    _store_and_disable_collision(entity)
    # Visual
    _set_node_transparency(entity, 0.33)
    get_tree().current_scene.add_child(entity)
    _preview = entity
    _preview_data = entity_data


func update_preview_position(world_pos: Vector3) -> void:
    if is_instance_valid(_preview):
        _preview.position = world_pos


func finalize_preview(player_id: int) -> Node3D:
    if not is_instance_valid(_preview) or not _preview_data:
        return null
    # Restore: groups, processing, collision, transparency
    _add_preview_groups(_preview, _preview_data)
    _preview.process_mode = Node.PROCESS_MODE_INHERIT
    _restore_collision(_preview)
    _clear_preview_materials(_preview)
    # Set player
    var stats := _preview.get_node_or_null("StatsComponent") as StatsComponent
    if stats:
        stats.player_id = player_id
    # Emit signal
    var entity := _preview
    var data := _preview_data
    _preview = null
    _preview_data = null
    _preview_original_layers.clear()
    _preview_original_surface_overrides.clear()
    entity_placed.emit(entity, data)
    return entity


func cancel_preview() -> void:
    if is_instance_valid(_preview):
        _preview.queue_free()
    _preview = null
    _preview_data = null
    _preview_original_layers.clear()
    _preview_original_surface_overrides.clear()


func has_preview() -> bool:
    return is_instance_valid(_preview)


# --- Group management ---


func _remove_preview_groups(entity: Node3D) -> void:
    for group in entity.get_groups():
        entity.remove_from_group(group)


func _add_preview_groups(entity: Node3D, data: EntityData) -> void:
    var etype := data.entity_type
    if etype != EntityData.EntityType.OVERLAY:
        if etype != EntityData.EntityType.TERRAIN or data.foundation != Vector2i(1, 1):
            entity.add_to_group("entities")
    var is_unit := (
        etype == EntityData.EntityType.INFANTRY
        or etype == EntityData.EntityType.VEHICLE
        or etype == EntityData.EntityType.AIRCRAFT
    )
    if is_unit:
        entity.add_to_group("selectable")
        entity.add_to_group("drag_selectable")
    elif etype == EntityData.EntityType.BUILDING:
        entity.add_to_group("selectable")
    if data.resource_category != "":
        entity.add_to_group("resources")
    if data.resource_category == "tiberium_tree":
        entity.add_to_group("resource_trees")


# --- Collision management ---


func _store_and_disable_collision(node: Node) -> void:
    if node is CollisionObject3D:
        var co := node as CollisionObject3D
        _preview_original_layers[node] = [co.collision_layer, co.collision_mask]
        co.collision_layer = 0
        co.collision_mask = 0
    if node is MeshInstance3D:
        var overrides: Array[Material] = []
        for i in node.get_surface_override_material_count():
            overrides.append(node.get_surface_override_material(i))
        _preview_original_surface_overrides[node] = overrides
    for child in node.get_children():
        _store_and_disable_collision(child)


func _restore_collision(node: Node) -> void:
    if node is CollisionObject3D and _preview_original_layers.has(node):
        var layers: Array = _preview_original_layers[node]
        var co := node as CollisionObject3D
        co.collision_layer = layers[0]
        co.collision_mask = layers[1]
    for child in node.get_children():
        _restore_collision(child)


func _clear_preview_materials(node: Node) -> void:
    if node is MeshInstance3D:
        var mi := node as MeshInstance3D
        mi.material_override = null
        if _preview_original_surface_overrides.has(node):
            var overrides: Array = _preview_original_surface_overrides[node]
            for i in mi.get_surface_override_material_count():
                if i < overrides.size():
                    mi.set_surface_override_material(i, overrides[i])
                else:
                    mi.set_surface_override_material(i, null)
        else:
            for i in mi.get_surface_override_material_count():
                mi.set_surface_override_material(i, null)
    for child in node.get_children():
        _clear_preview_materials(child)


# --- Transparency ---


func _set_node_transparency(node: Node, alpha: float) -> void:
    if node is MeshInstance3D:
        var mat := StandardMaterial3D.new()
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mat.albedo_color = Color(0.5, 0.5, 0.5, alpha)
        (node as MeshInstance3D).material_override = mat
    for child in node.get_children():
        _set_node_transparency(child, alpha)
