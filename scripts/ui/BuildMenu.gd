extends PanelContainer

const CAMEO_W := 128
const CAMEO_H := 96
const CAMEO_COLORS: Array[Color] = [
    Color(0.3, 0.3, 0.4),  # ConYard
    Color(0.8, 0.7, 0.2),  # Power Plant
    Color(0.3, 0.5, 0.3),  # Barracks
    Color(0.6, 0.4, 0.2),  # Refinery
    Color(0.3, 0.4, 0.6),  # War Factory
    Color(0.5, 0.5, 0.5),  # Guard Tower
    Color(0.6, 0.6, 0.5),  # Civilian Tower
]

@onready var grid: GridContainer = %GridContainer

var _building_buttons: Array[Button] = []


func _ready() -> void:
    var bm := get_node("/root/BuildingManager") as Node
    if bm:
        bm.build_mode_changed.connect(_on_build_mode_changed)
        _populate_buttons(bm)


func _populate_buttons(bm: Node) -> void:
    var building_types: Array[Resource] = bm.building_types as Array[Resource]
    for idx in building_types.size():
        var bt: BuildingType = building_types[idx] as BuildingType
        if not bt:
            continue

        var btn := Button.new()
        btn.custom_minimum_size = Vector2(CAMEO_W, CAMEO_H)
        btn.size_flags_horizontal = Control.SIZE_FILL
        btn.size_flags_vertical = Control.SIZE_FILL

        var color: Color = CAMEO_COLORS[idx] if idx < CAMEO_COLORS.size() else Color.GRAY
        var style := StyleBoxFlat.new()
        style.bg_color = color
        style.set_corner_radius_all(2)
        style.set_content_margin_all(0)
        btn.add_theme_stylebox_override("normal", style)
        btn.add_theme_stylebox_override("focus", style)

        var hover_style := style.duplicate()
        hover_style.bg_color = color.lightened(0.2)
        btn.add_theme_stylebox_override("hover", hover_style)

        var pressed_style := style.duplicate()
        pressed_style.bg_color = color.darkened(0.2)
        btn.add_theme_stylebox_override("pressed", pressed_style)

        var label := Label.new()
        label.text = bt.display_name
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.anchor_left = 0.0
        label.anchor_top = 0.7
        label.anchor_right = 1.0
        label.anchor_bottom = 1.0
        label.offset_left = 2.0
        label.offset_top = 0.0
        label.offset_right = -2.0
        label.offset_bottom = -2.0
        label.grow_horizontal = Control.GROW_DIRECTION_BOTH
        label.grow_vertical = Control.GROW_DIRECTION_END
        label.add_theme_font_size_override("font_size", 14)
        label.add_theme_color_override("font_color", Color.WHITE)
        btn.add_child(label)

        btn.pressed.connect(_on_building_button_pressed.bind(bt))
        grid.add_child(btn)
        _building_buttons.append(btn)


func _on_building_button_pressed(building_type: BuildingType) -> void:
    var bm := get_node("/root/BuildingManager") as Node
    if bm:
        bm.enter_build_mode(building_type)


func _on_build_mode_changed(is_active: bool) -> void:
    var bm := get_node("/root/BuildingManager") as Node
    if not bm:
        return
    var building_types: Array[Resource] = bm.building_types as Array[Resource]
    for i in range(_building_buttons.size()):
        var btn := _building_buttons[i]
        var bt := building_types[i] as BuildingType
        if is_active and bm.current_building_type == bt:
            btn.modulate = Color(1.3, 1.3, 0.8)
        else:
            btn.modulate = Color.WHITE
