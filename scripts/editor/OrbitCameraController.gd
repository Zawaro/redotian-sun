extends Node3D

## Free-orbit camera for the asset preview: drag to orbit the pivot, wheel to
## zoom, middle/right drag to pan. Owns a perspective Camera3D child that the
## preview controller flips `current` on. Not used outside the preview scene.

@export var target: Node3D = null
@export var distance: float = 8.0
@export var min_distance: float = 3.0
@export var max_distance: float = 30.0

var _camera: Camera3D = null
var _pivot := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.5
var _panning := false


func _ready() -> void:
    _camera = get_node_or_null("Camera3D") as Camera3D
    if _camera == null:
        _camera = Camera3D.new()
        _camera.name = "Camera3D"
        add_child(_camera)
    _camera.current = false
    if target != null:
        _pivot = target.global_position
    _apply_transform()


func is_active_camera() -> bool:
    return _camera != null and _camera.current


func set_active(active: bool) -> void:
    if _camera != null:
        _camera.current = active
    _pivot = target.global_position if target != null else Vector3.ZERO
    _apply_transform()


func _process(_delta: float) -> void:
    if is_active_camera() and target != null and _pivot == Vector3.ZERO:
        _pivot = target.global_position


func _unhandled_input(event: InputEvent) -> void:
    if not is_active_camera():
        return
    if event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
            _panning = mouse_event.pressed
            get_viewport().set_input_as_handled()
        elif mouse_event.pressed:
            if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
                distance = clampf(distance * 0.9, min_distance, max_distance)
                _apply_transform()
                get_viewport().set_input_as_handled()
            elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
                distance = clampf(distance * 1.1, min_distance, max_distance)
                _apply_transform()
                get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion:
        var motion := event as InputEventMouseMotion
        if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
            _yaw -= motion.relative.x * 0.01
            _pitch = clampf(_pitch + motion.relative.y * 0.01, 0.05, 1.4)
            _apply_transform()
        elif _panning:
            var cam := get_viewport().get_camera_3d()
            if cam != null:
                var right := -cam.global_transform.basis.x
                var up := cam.global_transform.basis.y
                _pivot += right * motion.relative.x * 0.02 + up * motion.relative.y * 0.02
                _apply_transform()


func _apply_transform() -> void:
    var cp := cos(_pitch)
    var offset := Vector3(cp * cos(_yaw), sin(_pitch), cp * sin(_yaw)) * distance
    global_position = _pivot + offset
    look_at(_pivot, Vector3.UP)
