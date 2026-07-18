extends Node

const TIB_DEFAULT_STRENGTH: int = 300

var editor: Node3D = null

var _paint_strength: float = 50.0
var _paint_radius: int = 1
var _is_painting: bool = false


func handle_input(event: InputEvent) -> void:
    if editor._active_tool in [editor.Tool.PAINT_RESOURCE, editor.Tool.ERASE]:
        if event is InputEventMouseButton:
            if event.button_index == MOUSE_BUTTON_LEFT:
                _is_painting = event.pressed
                if _is_painting and editor._hovered_cell.x >= 0:
                    _apply_brush(editor._hovered_cell)
        elif event is InputEventMouseMotion and _is_painting and editor._hovered_cell.x >= 0:
            _apply_brush(editor._hovered_cell)


func set_strength(value: float) -> void:
    _paint_strength = value


func set_radius(value: float) -> void:
    _paint_radius = ceili(value)


func _apply_brush(center: Vector2i) -> void:
    var extent := _paint_radius - 1
    for dx in range(-extent, extent + 1):
        for dz in range(-extent, extent + 1):
            var cell := center + Vector2i(dx, dz)
            var key := str(cell.x) + "," + str(cell.y)
            if editor._active_tool == editor.Tool.PAINT_RESOURCE:
                _paint_resource_cell(cell, key)
            elif editor._active_tool == editor.Tool.ERASE:
                _erase_resource_cell(cell, key)


func _paint_resource_cell(cell: Vector2i, key: String) -> void:
    if editor._painted_entities.has(key):
        var entry: Dictionary = editor._painted_entities[key]
        var node := entry.get("node") as Node3D
        if is_instance_valid(node):
            var tib := node.get_node_or_null("ResourceComponent") as ResourceComponent
            var hp := node.get_node_or_null("HealthComponent") as HealthComponent
            if tib and hp:
                var bales_to_add := _paint_strength / 100.0
                var health_to_add := int(bales_to_add * float(hp.max_health))
                hp.heal(health_to_add)
                tib._update_visual()
                entry["data"]["strength"] = hp.current_health
            return

    var health_val := int(_paint_strength / 100.0 * float(TIB_DEFAULT_STRENGTH))
    var overrides: Dictionary = {
        "strength": health_val,
        "resource_type_id": "tiberium_green",
    }
    var entity := EntityFactory.create_entity("TIB", overrides)
    if not entity:
        return
    entity.position = editor._cell_world_pos(cell)
    var data: Dictionary = overrides.duplicate()
    data["id"] = "TIB"
    editor._painted_entities[key] = {"node": entity, "data": data}
    editor.add_child(entity)


func _erase_resource_cell(_cell: Vector2i, key: String) -> void:
    if not editor._painted_entities.has(key):
        return
    var entry: Dictionary = editor._painted_entities[key]
    var node := entry.get("node") as Node3D
    if not is_instance_valid(node):
        editor._painted_entities.erase(key)
        return
    var tib := node.get_node_or_null("ResourceComponent") as ResourceComponent
    var hp := node.get_node_or_null("HealthComponent") as HealthComponent
    if not tib or not hp:
        editor._painted_entities.erase(key)
        return
    var bales_to_remove := _paint_strength / 100.0
    var health_to_remove := int(bales_to_remove * float(hp.max_health))
    hp.take_damage(health_to_remove)
    entry["data"]["strength"] = hp.current_health
    tib._update_visual()
    if hp.current_health <= 0:
        node.queue_free()
        editor._painted_entities.erase(key)
