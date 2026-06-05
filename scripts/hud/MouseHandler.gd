extends Control
class_name MouseHandler

@export var camera_controller: CameraController
@export var raycast_distance: float = 500.0
@export var selection_manager: SelectionManager

@onready var selection_rect: ReferenceRect = $SelectionRect

var MOUSE_DRAG_THRESHOLD := 5.0

# Drag state — stored across _process() frames instead of event callbacks.
var mouse_dragging := false
var drag_start_position := Vector2.ZERO
var active_rect: Rect2


func _ready():
    selection_rect.hide()
    
    # Debug logging for raycasting infrastructure
    if not camera_controller:
        printerr("[MouseHandler] WARNING: camera_controller export is null. " + \
            "All mouse-based interactions (selection, movement) will fail silently.")
    else:
        var cam3d = _get_camera_3d()
        if !cam3d:
            printerr("[MouseHandler] Camera3D not found under camera_controller path.")
    
    if selection_manager:
        print("SelectionManager found!")


# Poll input directly (like CameraController.gd) instead of using _input().
# This is required because Control nodes embedded under Node3D root don't receive
# _input() events without focus in Play Scene mode. The Input singleton polls OS-level state
# and works regardless of scene hierarchy or node focus chains.
func _process(_delta):
    if Engine.is_editor_hint():
        return
    
    var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)
    
    # Left mouse button just pressed — start drag tracking.
    if Input.is_action_just_pressed("select_entity"):
        mouse_dragging = true
        drag_start_position = get_viewport().get_mouse_position()
        selection_rect.show()
        selection_rect.position = drag_start_position
        selection_rect.size = Vector2.ZERO
    
    # Left mouse button just released — resolve as box-select or single click.
    if Input.is_action_just_released("select_entity"):
        var threshold_exceeded: bool = selection_rect.size.x >= MOUSE_DRAG_THRESHOLD
        
        if mouse_dragging and threshold_exceeded:
            if not shift_pressed:
                assert(selection_manager, "SelectionManager is not set")
                selection_manager.deselect_all()
            if active_rect.has_area():
                _select_entities_2d_projected(active_rect)
        else:
            var mouse_pos := get_viewport().get_mouse_position()
            _handle_single_click(mouse_pos, shift_pressed)
        
        mouse_dragging = false
    
    # Right mouse button just released — always deselect.
    if Input.is_action_just_released("deselect_entity"):
        assert(selection_manager, "SelectionManager is not set")
        selection_manager.deselect_all()
    
    # Update drag rectangle while left mouse held and moving (polling).
    if mouse_dragging:
        var m_end := get_viewport().get_mouse_position()
        var diff: Vector2 = m_end - drag_start_position
        active_rect = Rect2(drag_start_position, diff).abs()
        selection_rect.position = active_rect.position
        selection_rect.size = active_rect.size
    
    # Hover preview during mouse motion (when not dragging left button).
    if not mouse_dragging and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        var mouse_pos := get_viewport().get_mouse_position()
        _handle_hover_preview(mouse_pos)
    
    if not mouse_dragging:
        selection_rect.hide()


func _get_camera_3d() -> Camera3D:
    if camera_controller and camera_controller.has_node("Camera3D"):
        return camera_controller.get_node("Camera3D") as Camera3D
    
    # Debug logging for diagnosis of missing camera in raycasting flow
    printerr("[MouseHandler] _get_camera_3d() returned null — " + \
        ("camera_controller is not set. " if !camera_controller else \
         "camera_controller has no 'Camera3D' child node. "))
    return null


## Handle left-click raycast for entity select or ground movement command.
func _handle_single_click(mouse_pos: Vector2, shift_pressed: bool):
    var camera := _get_camera_3d()
    if not camera or not camera.is_current():
        return
    
    var from = camera.project_ray_origin(mouse_pos)
    var dir := camera.project_ray_normal(mouse_pos).normalized()
    
    # Phase 1: Check for entity hit at mask 1 << 15 (existing behavior preserved).
    var space_state = camera.get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(from, from + dir * raycast_distance)
    query.collision_mask = 1 << 15
    query.collide_with_areas = true
    
    var result = space_state.intersect_ray(query)

    if result.has("collider"):
        # Task 2.4: Entity found — select it as before (existing behavior preserved).
        var collider := result.collider as Node
        var select_comp := _find_select_component(collider)
        if select_comp:
            assert(selection_manager, "SelectionManager is not set")
            selection_manager.select_entity(select_comp, shift_pressed)
    else:
        # Task 2.1/2.2: No entity under cursor — cast ground plane ray for movement command.
        var ground_pos := _get_ground_position_at_mouse()
        if ground_pos != Vector3.INF and not selection_manager.selected_entities.is_empty():
            assert(selection_manager, "SelectionManager is not set")
            selection_manager.request_move(ground_pos)


## Box-select: select entities whose projection falls inside the drag rectangle.
func _select_entities_2d_projected(rect: Rect2):
    var all_entities = get_tree().get_nodes_in_group("entities")
    var camera := _get_camera_3d()
    for entity in all_entities:
        if not (entity is SelectComponent):
            continue
        
        var select_component: SelectComponent = entity
        
        if rect.has_point(camera.unproject_position(select_component.global_position)):
            if not selection_manager.is_entity_selected(select_component):
                selection_manager.add_entity(select_component)


## Walk up the node tree to find a SelectComponent descendant.
func _find_select_component(node: Node) -> SelectComponent:
    while is_instance_valid(node):
        if node is SelectComponent:
            return node as SelectComponent
        node = node.get_parent()
    return null


## Handle hover preview by raycasting at entities under the cursor.
func _handle_hover_preview(mouse_pos: Vector2) -> void:
    var camera := _get_camera_3d()
    if not camera:
        return
    
    var from = camera.project_ray_origin(mouse_pos)
    var dir := camera.project_ray_normal(mouse_pos).normalized()
    
    var space_state = camera.get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(from, from + dir * raycast_distance)
    query.collision_mask = 1 << 15
    query.collide_with_areas = true
    
    var result = space_state.intersect_ray(query)
    
    if result.has("collider"):
        var collider := result.collider as Node
        var select_comp := _find_select_component(collider)
        if select_comp:
            selection_manager.set_hover_preview(true, select_comp)
            return
    
    selection_manager.clear_hover_preview()


## Return where the camera ray through mouse cursor intersects terrain surface (iterative solve).
func _get_ground_position_at_mouse() -> Vector3:
    var camera := _get_camera_3d()
    if not camera:
        return Vector3.INF
    
    var mouse_pos := get_viewport().get_mouse_position() as Vector2
    var from = camera.project_ray_origin(mouse_pos)
    var dir := camera.project_ray_normal(mouse_pos).normalized()
    
    var ground_plane := Plane(Vector3.UP, 0.0) as Plane
    var intersection = ground_plane.intersects_ray(from, dir)
    
    if intersection == null:
        return Vector3.INF
    
    var hit_pos := intersection as Vector3
    for i in 4:
        var terrain_y := TerrainSystem.get_height_at_world_smooth(hit_pos)
        var adjusted := Plane(Vector3.UP, terrain_y)
        var new_hit = adjusted.intersects_ray(from, dir)
        if new_hit == null:
            break
        hit_pos = new_hit as Vector3
    
    var dist_sq: float = from.distance_squared_to(hit_pos)
    if 0.0 < dist_sq and dist_sq <= raycast_distance * raycast_distance:
        return hit_pos
    
    return Vector3.INF
