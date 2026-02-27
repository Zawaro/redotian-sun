@tool
extends Camera3D

@onready var camera_pivot = $".."
var min_size = 10
var max_size = 50
var size_step = 1

func _process(_delta):
    if Engine.is_editor_hint():
        self.size = camera_pivot.get("camera_size")
    if not Engine.is_editor_hint():
        if Input.is_action_just_pressed("zoom_in"):
            var camera_size = self.size - size_step
            self.size = clamp(camera_size, min_size, max_size)
        if Input.is_action_just_pressed("zoom_out"):
            var camera_size = self.size + size_step
            self.size = clamp(camera_size, min_size, max_size)
