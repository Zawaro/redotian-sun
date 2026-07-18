@tool
extends Camera3D

@export var camera_controller: CameraController
var min_size = 10
var max_size = 50
var size_step = 1


func _process(_delta):
    if Engine.is_editor_hint():
        self.size = camera_controller.camera_size


func _unhandled_input(event: InputEvent) -> void:
    if Engine.is_editor_hint():
        return
    if event.is_action("zoom_in"):
        var camera_size = self.size - size_step
        self.size = clamp(camera_size, min_size, max_size)
    elif event.is_action("zoom_out"):
        var camera_size = self.size + size_step
        self.size = clamp(camera_size, min_size, max_size)
