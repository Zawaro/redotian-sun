@tool
class_name CameraController extends Node3D

@export var camera_size: float = 20
var fixed_toggle_point = Vector2(0, 0)
var is_panning = false
var navigation_speed: float = 180.0
var keyboard_navigation_divider: float = 3.0
var border_panning_threshold: float = 7.0

# Move camera with middle mouse press in isometric viewport where camera is rotated 45 degrees
func _process(_delta):
    if not Engine.is_editor_hint():
        # Preserve approximately the same movement speed as before at ~60 FPS,
        # but make it frame-rate independent by scaling with `_delta`.
        var axis_speed := (1.0 / keyboard_navigation_divider) * 60.0
        var forward := Vector3(1, 0, 1)
        
        # Handle middle mouse panning
        if Input.is_action_just_pressed("move_map"):
            is_panning = true
            fixed_toggle_point = get_viewport().get_mouse_position()
        if not Input.is_action_pressed("move_map"):
            is_panning = false
            
        if Input.is_action_pressed("move_map") and is_panning:
            slide_map_around(_delta)
            
        # Keyboard controls (WASD for camera pan)
        if Input.is_key_pressed(KEY_W):
            self.global_position -= forward * axis_speed * _delta
        if Input.is_key_pressed(KEY_S):
            self.global_position += forward * axis_speed * _delta
        if Input.is_key_pressed(KEY_A):
            self.global_position -= forward.rotated(Vector3(0, 1, 0), deg_to_rad(90)) * axis_speed * _delta
        if Input.is_key_pressed(KEY_D):
            self.global_position += forward.rotated(Vector3(0, 1, 0), deg_to_rad(90)) * axis_speed * _delta
        
        # Handle border panning (only when middle mouse not pressed)
        if not Input.is_action_pressed("move_map"):
            handle_border_panning(_delta, axis_speed, forward)

func slide_map_around(_delta):
    var current_mouse_pos = get_viewport().get_mouse_position()
    var rel = current_mouse_pos - fixed_toggle_point
    # Halve the horizontal (left/right) movement speed by reducing X contribution
    var rotated = Vector3(
        rel.x * 0.5 - rel.y,
        0,
        rel.x * 0.5 + rel.y,
    )
    # Scale by `_delta` (and 60) to approximate previous behavior at 60 FPS
    self.global_position += (rotated / navigation_speed).rotated(Vector3(0, 1, 0), deg_to_rad(90)) * _delta * 60.0

func handle_border_panning(_delta: float, axis_speed: float, forward: Vector3):
    var viewport_rect = get_viewport().get_visible_rect()
    
    # Get mouse position relative to viewport
    var mouse_pos = get_viewport().get_mouse_position()
    
    # Check if mouse is within viewport bounds (stop panning when outside)
    if not viewport_rect.has_point(mouse_pos):
        return
    
    # Calculate distance from each edge
    var dist_left = mouse_pos.x - viewport_rect.position.x
    var dist_right = viewport_rect.size.x - mouse_pos.x
    var dist_top = mouse_pos.y - viewport_rect.position.y
    var dist_bottom = viewport_rect.size.y - mouse_pos.y
    
    # Use EXACT same movement logic as keyboard controls for consistency
    if dist_left < border_panning_threshold:
        self.global_position -= forward.rotated(Vector3(0, 1, 0), deg_to_rad(90)) * axis_speed * _delta
    elif dist_right < border_panning_threshold:
        self.global_position += forward.rotated(Vector3(0, 1, 0), deg_to_rad(90)) * axis_speed * _delta
        
    if dist_top < border_panning_threshold:
        self.global_position -= forward * axis_speed * _delta
    elif dist_bottom < border_panning_threshold:
        self.global_position += forward * axis_speed * _delta
