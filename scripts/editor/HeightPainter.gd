extends Node

signal height_changed(cell: Vector2i, new_base_height: int)

var editor: Node3D = null

var _is_painting: bool = false
var _last_cell: Vector2i = Vector2i(-999, -999)
var _start_mouse_y: float = 0.0
var _height_threshold: float = 20.0
var _accumulated_delta: float = 0.0


func _input(event: InputEvent) -> void:
    if Engine.is_editor_hint():
        return
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _start_painting(event.position)
            else:
                _stop_painting()
    elif event is InputEventMouseMotion and _is_painting:
        _process_painting(event.position)


func _start_painting(mouse_pos: Vector2) -> void:
    _is_painting = true
    _start_mouse_y = mouse_pos.y
    _accumulated_delta = 0.0
    if editor:
        _last_cell = editor.get_hovered_cell()


func _stop_painting() -> void:
    _is_painting = false
    _last_cell = Vector2i(-999, -999)
    _accumulated_delta = 0.0


func _process_painting(mouse_pos: Vector2) -> void:
    if not editor:
        return
    var _current_cell: Vector2i = editor.get_hovered_cell()
    var mouse_delta: float = _start_mouse_y - mouse_pos.y
    _accumulated_delta += mouse_delta
    _start_mouse_y = mouse_pos.y
    if abs(_accumulated_delta) >= _height_threshold:
        var change: int = 1 if _accumulated_delta > 0 else -1
        _accumulated_delta = 0.0
        _apply_height_change(_last_cell, change)


func _apply_height_change(cell: Vector2i, change: int) -> void:
    if change > 0:
        TerrainSystem.raise_cell(cell)
    else:
        TerrainSystem.lower_cell(cell)
    var data := TerrainSystem.get_cell(cell)
    var base_h: int = data.get("height", 0)
    height_changed.emit(cell, base_h)
