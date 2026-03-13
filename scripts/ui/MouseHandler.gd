extends Control
class_name MouseHandler

@export var camera_controller: CameraController
@export var raycast_distance: float = 500.0
@export var selection_manager: SelectionManager

@onready var selection_rect: ReferenceRect = $SelectionRect

var MOUSE_DRAG_THRESHOLD = 0.1

var mouse_dragging := false
var drag_start_position: Vector2
var active_rect: Rect2

func _ready():
    if selection_manager:
        print("✅ SelectionManager found!")
    else:
        push_error("❌ SelectionManager not found — please add it as a sibling")

func _input(event: InputEvent) -> void:
    var shift_pressed = Input.is_key_pressed(KEY_SHIFT)
    var threshold_exceeded = selection_rect.size.x >= MOUSE_DRAG_THRESHOLD
    
    if event.is_action_pressed("select_entity"):
        mouse_dragging = true
        drag_start_position = event.position
        selection_rect.show()
        selection_rect.position = drag_start_position
        selection_rect.size = Vector2.ZERO
    elif event.is_action_released("select_entity"):
        if mouse_dragging and threshold_exceeded:
            if not shift_pressed:
                selection_manager.deselect_all()
            if active_rect:
                _select_entities_2d_projected(active_rect)
        else:
            var mouse_pos = get_viewport().get_mouse_position()
            _handle_single_click(mouse_pos, shift_pressed)
        mouse_dragging = false
        selection_rect.hide()
    elif event.is_action_released("deselect_entity"):
        assert(selection_manager, "SelectionManager is not set")
        selection_manager.deselect_all()
        
    if mouse_dragging and event is InputEventMouseMotion:
        var m_start := drag_start_position
        var m_end: Vector2 = event.position
        var diff = m_end - m_start
        active_rect = Rect2(m_start, diff).abs()
        selection_rect.position = active_rect.position
        selection_rect.size = active_rect.size
    elif event is InputEventMouseMotion:
        var mouse_pos = get_viewport().get_mouse_position()
        _handle_hover_preview(mouse_pos)

func _get_camera_3d() -> Camera3D:
    if camera_controller and camera_controller.has_node("Camera3D"):
        return camera_controller.get_node("Camera3D") as Camera3D
    return null

func _handle_single_click(mouse_pos: Vector2, shift_pressed: bool):
    var camera = _get_camera_3d()
    if not camera or not camera.is_current():
        return
    
    var from = camera.project_ray_origin(mouse_pos)
    var dir = -camera.global_transform.basis.z.normalized()
    var to = from + dir * raycast_distance
    
    var space_state = camera.get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = 1 << 15
    query.collide_with_areas = true
    
    var result = space_state.intersect_ray(query)

    if result and result.collider:
        var select_comp = _find_select_component(result.collider)
        if select_comp:
            assert(selection_manager, "SelectionManager is not set")
            selection_manager.select_entity(select_comp, shift_pressed)

func _handle_hover_preview(mouse_pos: Vector2):
    var camera = _get_camera_3d()
    if not camera:
        return
    
    var from = camera.project_ray_origin(mouse_pos)
    var dir = -camera.global_transform.basis.z.normalized()
    var to = from + dir * raycast_distance
    
    var space_state = camera.get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = 1 << 15
    query.collide_with_areas = true
    # query.exclude = [local_player_entity.get_rid()]   # optional: ignore own entity if needed
    
    var result = space_state.intersect_ray(query)
    
    if result and result.collider:
        var select_comp = _find_select_component(result.collider)
        if select_comp:
            selection_manager.set_hover_preview(true, select_comp)
            return
    
    selection_manager.clear_hover_preview()
    
func _select_entities_2d_projected(rect: Rect2) -> void:
    var all_entities = get_tree().get_nodes_in_group("entities")
    var camera = _get_camera_3d()
    for entity in all_entities:
        if not (entity is SelectComponent):
            continue
            
        var select_component: SelectComponent = entity
        
        if rect.has_point(camera.unproject_position(select_component.global_position)):
            if not selection_manager.is_entity_selected(select_component):
                selection_manager.add_entity(select_component)

func _find_select_component(node: Node) -> SelectComponent:
    while node:
        if node is SelectComponent:
            return node
        node = node.get_parent()
    return null
