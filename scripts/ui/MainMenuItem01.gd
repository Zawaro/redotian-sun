@tool
extends Node2D

var _text: String = "Default Text"
var _is_disabled: bool = false

@export var text: String:
    get:
        return _text
    set(value):
        _text = value
        update_child_text()
@export var is_disabled: bool:
    get:
        return _is_disabled
    set(value):
        _is_disabled = value
        update_label_color()

@onready var text_label = $Text
@onready var TextFog = $TextFogSubViewport/TextFog
@onready var TextGlow = $TextGlowSubViewport/TextGlow

# Color definitions — accent is the active game's menu colour (set by the menu
# controller); hover is neutral white.
const COLOR_DEFAULT = Color("#2ae7fd")
const COLOR_HOVER = Color("#ffffff")
const DISABLED_DARKEN := 0.6

var _accent: Color = COLOR_DEFAULT

var is_hovering: bool = false


## Sets the accent colour for this item (called by the owning menu from the
## active game's definition).
func set_accent(color: Color) -> void:
    _accent = color
    update_label_color()


func get_accent() -> Color:
    return _accent


func _ready() -> void:
    update_child_text()
    update_label_color()


func _input(event):
    if is_disabled:
        return
    if event is InputEventMouseMotion:
        var mouse_over = text_label.get_global_rect().has_point(get_viewport().get_mouse_position())
        if mouse_over != is_hovering:
            is_hovering = mouse_over
            update_label_color()


func update_child_text() -> void:
    if text_label:
        text_label.text = text
    if TextFog:
        TextFog.text = text
    if TextGlow:
        TextGlow.text = text


func update_label_color() -> void:
    if text_label:
        if is_disabled:
            text_label.modulate = _accent.darkened(DISABLED_DARKEN)
        elif is_hovering:
            text_label.modulate = COLOR_HOVER
        else:
            text_label.modulate = COLOR_DEFAULT
