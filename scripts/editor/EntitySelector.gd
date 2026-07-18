extends Node

## Editor-local entity selection system.
## Uses EditorSelectComponent for collision and visual.
## Handles click-to-select, drag-to-select, delete, and rotate.

signal selection_changed(selected_count: int)

var editor: Node3D = null

var _selected_components: Array[EditorSelectComponent] = []
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_rect: Rect2 = Rect2()
var _drag_threshold: float = 5.0
var _camera: Camera3D = null
var _selection_rect: ReferenceRect = null

const EDITOR_SELECT_LAYER: int = 1 << 17


func setup(cam: Camera3D, ui_layer: CanvasLayer) -> void:
    _camera = cam
    _selection_rect = ReferenceRect.new()
    _selection_rect.name = "EditorSelectionRect"
    _selection_rect.editor_only = false
    _selection_rect.border_width = 1.0
    _selection_rect.border_color = Color.WHITE
    _selection_rect.visible = false
    ui_layer.add_child(_selection_rect)


func cleanup() -> void:
    deselect_all()
    _dragging = false


func handle_input(event: InputEvent) -> void:
    if not editor or editor._active_tool != editor.Tool.NONE:
        return

    if event is InputEventMouseButton and event.pressed:
        match event.button_index:
            MOUSE_BUTTON_LEFT:
                _dragging = true
                _drag_start = event.position
                _drag_rect = Rect2()
                if _selection_rect:
                    _selection_rect.visible = true
                    _selection_rect.position = _drag_start
                    _selection_rect.size = Vector2.ZERO
            MOUSE_BUTTON_RIGHT:
                deselect_all()

    if event is InputEventMouseButton and not event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT and _dragging:
            _dragging = false
            if _selection_rect:
                _selection_rect.visible = false
            var dist: float = event.position.distance_to(_drag_start)
            if dist >= _drag_threshold:
                _box_select(_drag_rect)
            else:
                _click_select(event.position)

    if event is InputEventMouseMotion and _dragging:
        var diff: Vector2 = event.position - _drag_start
        _drag_rect = Rect2(_drag_start, diff).abs()
        if _selection_rect:
            _selection_rect.position = _drag_rect.position
            _selection_rect.size = _drag_rect.size

    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_BACKSPACE:
            delete_selected()
        elif event.keycode == KEY_R:
            rotate_selected(45.0)


func get_selected_entries() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for comp in _selected_components:
        if is_instance_valid(comp):
            (
                result
                . append(
                    {
                        "cell_key": comp.get_cell_key(),
                        "data": comp.get_entry_data(),
                    }
                )
            )
    return result


func is_entity_selected(check_cell_key: String) -> bool:
    for comp in _selected_components:
        if is_instance_valid(comp) and comp.get_cell_key() == check_cell_key:
            return true
    return false


func deselect_all() -> void:
    for comp in _selected_components:
        if is_instance_valid(comp):
            comp.set_selected(false)
    _selected_components.clear()
    selection_changed.emit(0)


func select_component(comp: EditorSelectComponent) -> void:
    deselect_all()
    comp.set_selected(true)
    _selected_components.append(comp)
    selection_changed.emit(_selected_components.size())


func delete_selected() -> void:
    if _selected_components.is_empty():
        return
    for comp in _selected_components:
        if not is_instance_valid(comp):
            continue
        var key: String = comp.get_cell_key()
        var node: Node3D = comp.get_parent() as Node3D
        editor._painted_entities.erase(key)
        if is_instance_valid(node):
            node.queue_free()
    _selected_components.clear()
    selection_changed.emit(0)


func rotate_selected(degrees: float) -> void:
    if _selected_components.is_empty():
        return
    for comp in _selected_components:
        if not is_instance_valid(comp):
            continue
        var entry: Dictionary = comp.get_entry_data()
        var node: Node3D = comp.get_parent() as Node3D
        if not is_instance_valid(node):
            continue
        var entity_id: String = entry.get("id", "")
        var entity_data := EntityFactory.get_entity_data(entity_id)
        if not entity_data:
            continue
        if entity_data.entity_type == EntityData.EntityType.BUILDING:
            continue
        var current_rot: float = entry.get("rotation_y", 0.0)
        var new_rot: float = fmod(current_rot + degrees, 360.0)
        entry["rotation_y"] = new_rot
        _apply_rotation_with_slope(node, new_rot)


func _click_select(mouse_pos: Vector2) -> void:
    if not _camera:
        return
    var from := _camera.project_ray_origin(mouse_pos)
    var dir := _camera.project_ray_normal(mouse_pos).normalized()
    var space_state := editor.get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(from, from + dir * 500.0)
    query.collide_with_areas = true
    query.collision_mask = EDITOR_SELECT_LAYER
    var result := space_state.intersect_ray(query)
    if result.is_empty():
        deselect_all()
        return

    var collider: Node = result.get("collider") as Node
    var comp := _find_select_component(collider)
    if not comp:
        deselect_all()
        return
    if is_entity_selected(comp.get_cell_key()):
        return
    select_component(comp)


func _box_select(rect: Rect2) -> void:
    if not _camera:
        return
    deselect_all()
    var ground_rects := _screen_rect_to_ground_rect(rect)
    if ground_rects.is_empty():
        return
    var ground_rect: Rect2 = ground_rects[0]
    for cell_key in editor._painted_entities:
        var entry: Dictionary = editor._painted_entities[cell_key]
        var node: Node3D = entry.get("node") as Node3D
        if not is_instance_valid(node):
            continue
        var comp := node.get_node_or_null("EditorSelectComponent") as EditorSelectComponent
        if not comp:
            continue
        var entity_ground := Vector2(
            node.global_position.x,
            node.global_position.z,
        )
        if ground_rect.has_point(entity_ground):
            comp.set_selected(true)
            _selected_components.append(comp)
    selection_changed.emit(_selected_components.size())


func _find_select_component(node: Node) -> EditorSelectComponent:
    while is_instance_valid(node):
        if node is EditorSelectComponent:
            return node as EditorSelectComponent
        node = node.get_parent()
    return null


func _screen_rect_to_ground_rect(screen_rect: Rect2) -> Array[Rect2]:
    if not _camera:
        return []
    var corners: Array[Vector2] = [
        screen_rect.position,
        screen_rect.position + Vector2(screen_rect.size.x, 0),
        screen_rect.position + Vector2(0, screen_rect.size.y),
        screen_rect.position + screen_rect.size,
    ]
    var ground_points: PackedVector3Array = PackedVector3Array()
    var ground_plane := Plane(Vector3.UP, 0.0)
    for corner in corners:
        var from := _camera.project_ray_origin(corner)
        var dir := _camera.project_ray_normal(corner).normalized()
        var hit = ground_plane.intersects_ray(from, dir)
        if hit:
            ground_points.append(hit as Vector3)
    if ground_points.size() < 2:
        return []
    var min_x := ground_points[0].x
    var max_x := ground_points[0].x
    var min_z := ground_points[0].z
    var max_z := ground_points[0].z
    for pt in ground_points:
        min_x = minf(min_x, pt.x)
        max_x = maxf(max_x, pt.x)
        min_z = minf(min_z, pt.z)
        max_z = maxf(max_z, pt.z)
    return [Rect2(Vector2(min_x, min_z), Vector2(max_x - min_x, max_z - min_z))]


func _apply_rotation_with_slope(node: Node3D, rotation_y_deg: float) -> void:
    var yaw := deg_to_rad(rotation_y_deg)
    var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
    var normal := TerrainSystem.get_normal_at_world(node.global_position).normalized()
    if normal.is_equal_approx(Vector3.UP):
        node.rotation.y = yaw
    else:
        var projected := (forward - forward.dot(normal) * normal).normalized()
        var right := projected.cross(normal).normalized()
        var basis := Basis()
        basis.x = right
        basis.y = normal
        basis.z = -projected
        node.global_transform.basis = basis
    var comp := node.get_node_or_null("EditorSelectComponent") as EditorSelectComponent
    if comp:
        comp.basis = node.basis.inverse()


func refresh_slope_tilt() -> void:
    for comp in _selected_components:
        if not is_instance_valid(comp):
            continue
        var entry: Dictionary = comp.get_entry_data()
        var node: Node3D = comp.get_parent() as Node3D
        if not is_instance_valid(node):
            continue
        var rot_y: float = entry.get("rotation_y", 0.0)
        _apply_rotation_with_slope(node, rot_y)
