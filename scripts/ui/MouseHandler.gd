extends Node3D
class_name MouseHandler

@export var camera_controller: CameraController
@export var raycast_distance: float = 500.0
@export var selection_manager: SelectionManager

func _ready():
    if selection_manager:
        print("✅ SelectionManager found!")
    else:
        push_error("❌ SelectionManager not found — please add it as a sibling")

func _input(event: InputEvent):
    if event is InputEventMouseMotion:
        var mouse_pos = get_viewport().get_mouse_position()
        handle_hover_preview(mouse_pos)

func _process(_delta):
    handle_input_actions()

func handle_input_actions():
    if Input.is_action_just_pressed("select_entity"):
        var shift_pressed = Input.is_key_pressed(KEY_SHIFT)
        var mouse_pos = get_viewport().get_mouse_position()
        handle_single_click(mouse_pos, shift_pressed)
    
    elif Input.is_action_just_pressed("deselect_entity"):
        assert(selection_manager, "SelectionManager is not set")
        selection_manager.deselect_all()

func get_camera_3d() -> Camera3D:
    if camera_controller and camera_controller.has_node("Camera3D"):
        return camera_controller.get_node("Camera3D") as Camera3D
    return null

func handle_single_click(mouse_pos: Vector2, shift_pressed: bool):
    var camera = get_camera_3d()
    if not camera or not camera.is_current():
        return
    
    var from = camera.project_ray_origin(mouse_pos)
    var dir = -camera.global_transform.basis.z.normalized()
    var to = from + dir * raycast_distance
    
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = 1 << 15
    query.collide_with_areas = true
    
    var result = space_state.intersect_ray(query)

    if result and result.collider:
        var select_comp = _find_select_component(result.collider)
        if select_comp:
            assert(selection_manager, "SelectionManager is not set")
            selection_manager.select_unit(select_comp, shift_pressed)

func handle_hover_preview(mouse_pos: Vector2):
    var camera = get_camera_3d()
    if not camera:
        return
    
    var from = camera.project_ray_origin(mouse_pos)
    var dir = -camera.global_transform.basis.z.normalized()
    var to = from + dir * raycast_distance
    
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
