@tool
extends Node3D
class_name CameraPivot

@export var camera_size: float = 20
var fixed_toggle_point = Vector2(0, 0)
var navigation_speed: float = 180
var keyboard_navigation_divider: float = 3

# Move camera with middle mouse press in isometric viewport where camera is rotated 45 degrees
func _process(_delta):
    if not Engine.is_editor_hint():
        # Preserve approximately the same movement speed as before at ~60 FPS,
        # but make it frame-rate independent by scaling with `_delta`.
        var axis_speed := (1.0 / keyboard_navigation_divider) * 60.0
        var forward := Vector3(1, 0, 1)
        
        if Input.is_action_just_pressed("move_map"):
            fixed_toggle_point = get_viewport().get_mouse_position()
        if Input.is_action_pressed("move_map"):
            slide_map_around(_delta)
        if Input.is_key_pressed(KEY_W):
            self.global_position -= forward * axis_speed * _delta
        if Input.is_key_pressed(KEY_S):
            self.global_position += forward * axis_speed * _delta
        if Input.is_key_pressed(KEY_A):
            self.global_position -= forward.rotated(Vector3(0, 1, 0), deg_to_rad(90)) * axis_speed * _delta
        if Input.is_key_pressed(KEY_D):
            self.global_position += forward.rotated(Vector3(0, 1, 0), deg_to_rad(90)) * axis_speed * _delta

func slide_map_around(_delta):
    var current_mouse_pos = get_viewport().get_mouse_position()
    var rel = current_mouse_pos - fixed_toggle_point
    var rotated = Vector3(
        rel.x - rel.y,
        0,
        rel.x + rel.y,
    )
    # Scale by `_delta` (and 60) to approximate previous behavior at 60 FPS
    self.global_position += (rotated / navigation_speed).rotated(Vector3(0, 1, 0), deg_to_rad(90)) * _delta * 60.0
    fixed_toggle_point = current_mouse_pos
