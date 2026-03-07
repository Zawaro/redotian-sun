extends Node3D
class_name MouseHandler

@export var camera_pivot: CameraPivot
@export var raycast_distance: float = 500.0
@export var selection_manager: SelectionManager

var viewport_rect: Rect2i

func _ready():
    if has_node("../SelectionManager"):
        selection_manager = get_node("../SelectionManager") as SelectionManager
        print("✅ SelectionManager found!")
    else:
        push_error("❌ SelectionManager not found — please add it as a sibling")
    
    viewport_rect = get_viewport().get_visible_rect()

func _process(_delta):
    var mouse_pos = get_viewport().get_mouse_position()
    handle_hover_preview(mouse_pos)

func _input(event: InputEvent):
    if event is InputEventMouseButton:
        handle_mouse_button(event)

func get_camera_3d() -> Camera3D:
    if camera_pivot and camera_pivot.has_node("Camera3D"):
        return camera_pivot.get_node("Camera3D") as Camera3D
    return null

func handle_mouse_button(event: InputEventMouseButton):
    var mouse_pos = get_viewport().get_mouse_position()
    
    match event.button_index:
        MOUSE_BUTTON_LEFT:
            if event.pressed:
                # Left click = select unit at position
                var shift_pressed = Input.is_key_pressed(KEY_SHIFT)
                handle_single_click(mouse_pos, shift_pressed)
        
        MOUSE_BUTTON_RIGHT:
            if event.pressed and not event.shift_pressed:
                selection_manager.deselect_all()

func handle_single_click(mouse_pos: Vector2, shift_pressed: bool):
    var camera = get_camera_3d()
    if not camera or not camera.is_current():
        return
    
    var from = camera.project_ray_origin(mouse_pos)
    var dir = -camera.global_transform.basis.z.normalized()
    var to = from + dir * 5000.0
    
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = 1 << 15
    query.collide_with_areas = true
    
    var result = space_state.intersect_ray(query)
    
    if result and result.collider:
        var select_comp = _find_select_component(result.collider)
        if select_comp:
            selection_manager.select_unit(select_comp, shift_pressed)

func handle_hover_preview(mouse_pos: Vector2):
    var camera = get_camera_3d()
    if not camera:
        return
    
    var from = camera.project_ray_origin(mouse_pos)
    var dir = -camera.global_transform.basis.z.normalized()
    var to = from + dir * 5000.0
    
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = 1 << 15
    query.collide_with_areas = true
    # query.exclude = [local_player_unit.get_rid()]   # optional: ignore own unit if needed
    
    var result = space_state.intersect_ray(query)
    
    if result and result.collider:
        var select_comp = _find_select_component(result.collider)
        if select_comp:
            selection_manager.set_hover_preview(true, select_comp)
            return
    
    selection_manager.clear_hover_preview()

func _find_select_component(node: Node) -> SelectComponent:
    while node:
        if node is SelectComponent:
            return node
        node = node.get_parent()
    return null
