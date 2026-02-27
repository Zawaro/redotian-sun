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

@onready var Text = $Text
@onready var TextFog = $TextFogSubViewport/TextFog
@onready var TextGlow = $TextGlowSubViewport/TextGlow

# Color definitions
const COLOR_DEFAULT  = Color("#2ae7fd")
const COLOR_HOVER    = Color("#ffffff")
const COLOR_DISABLED = Color("#1e5961")

var is_hovering: bool = false;

func _ready() -> void:
    update_child_text()
    update_label_color()

func _input(event):
    if is_disabled:
        return
    if event is InputEventMouseMotion:
        var mouse_over = Text.get_global_rect().has_point(get_viewport().get_mouse_position())
        if mouse_over != is_hovering:
            is_hovering = mouse_over
            update_label_color()
        

func update_child_text() -> void:
    if Text:
        Text.text = text
    if TextFog:
        TextFog.text = text
    if TextGlow:
        TextGlow.text = text

func update_label_color() -> void:
    if Text:
        if is_disabled:
            Text.modulate = COLOR_DISABLED
        elif is_hovering:
            Text.modulate = COLOR_HOVER
        else:
            Text.modulate = COLOR_DEFAULT
