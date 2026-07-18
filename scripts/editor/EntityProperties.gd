extends PanelContainer

## Right sidebar panel for editing entity properties in the MapEditor.
## Dynamically shows fields based on which components the selected entity has.

const ROTATION_NAMES: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
const ROTATION_VALUES: Array[float] = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]

var _vbox: VBoxContainer
var _current_entry: Dictionary = {}
var _current_cell_key: String = ""
var _entity_selector: Node = null


func setup(selector: Node) -> void:
    _entity_selector = selector
    visible = false
    _setup_ui()


func rebuild(cell_key: String, entry: Dictionary) -> void:
    _current_cell_key = cell_key
    _current_entry = entry
    _clear_children()
    if entry.is_empty():
        visible = false
        return
    visible = true
    _build_header()
    _build_rotation_field()
    _build_player_field()
    _build_component_fields()
    _build_delete_button()


func hide_panel() -> void:
    visible = false
    _current_entry = {}
    _current_cell_key = ""


func _setup_ui() -> void:
    custom_minimum_size = Vector2(220, 0)
    size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    size_flags_vertical = Control.SIZE_EXPAND_FILL

    _vbox = VBoxContainer.new()
    _vbox.name = "PropertiesVBox"
    add_child(_vbox)


func _clear_children() -> void:
    for child in _vbox.get_children():
        child.queue_free()


func _build_header() -> void:
    var entity_id: String = _current_entry.get("id", "")
    var entity_data := EntityFactory.get_entity_data(entity_id)
    var display_name: String = entity_data.display_name if entity_data else entity_id

    var title := Label.new()
    title.text = display_name
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 16)
    _vbox.add_child(title)

    var id_label := Label.new()
    id_label.text = "ID: %s" % entity_id
    id_label.add_theme_font_size_override("font_size", 11)
    _vbox.add_child(id_label)

    var sep := HSeparator.new()
    _vbox.add_child(sep)


func _build_rotation_field() -> void:
    var entity_id: String = _current_entry.get("id", "")
    var entity_data := EntityFactory.get_entity_data(entity_id)
    if entity_data and entity_data.entity_type == EntityData.EntityType.BUILDING:
        return

    var section := Label.new()
    section.text = "Rotation"
    section.add_theme_font_size_override("font_size", 13)
    _vbox.add_child(section)

    var row := HBoxContainer.new()
    _vbox.add_child(row)

    var label := Label.new()
    label.text = "Facing:"
    row.add_child(label)

    var dropdown := OptionButton.new()
    dropdown.name = "RotationDropdown"
    var current_rot: float = _current_entry.get("rotation_y", 0.0)
    for i in ROTATION_VALUES.size():
        dropdown.add_item(ROTATION_NAMES[i], i)
        if absf(ROTATION_VALUES[i] - current_rot) < 0.1:
            dropdown.select(i)
    dropdown.item_selected.connect(_on_rotation_changed.bind(dropdown))
    row.add_child(dropdown)

    _add_separator()


func _build_player_field() -> void:
    var section := Label.new()
    section.text = "Ownership"
    section.add_theme_font_size_override("font_size", 13)
    _vbox.add_child(section)

    var row := HBoxContainer.new()
    _vbox.add_child(row)

    var label := Label.new()
    label.text = "Player:"
    row.add_child(label)

    var dropdown := OptionButton.new()
    dropdown.name = "PlayerDropdown"
    var current_player: int = _current_entry.get("player_id", 0)
    for i in 8:
        dropdown.add_item("Player %d" % i, i)
    dropdown.select(current_player)
    dropdown.item_selected.connect(_on_player_changed.bind(dropdown))
    row.add_child(dropdown)

    _add_separator()


func _build_component_fields() -> void:
    var entity_id: String = _current_entry.get("id", "")
    var entity_data := EntityFactory.get_entity_data(entity_id)
    if not entity_data:
        return
    var node: Node3D = _current_entry.get("node") as Node3D
    if not is_instance_valid(node):
        return

    _build_health_fields(node)
    _build_power_fields(node)
    _build_stats_fields(node, entity_data)
    _build_foundation_fields(entity_data)
    _build_factory_fields(node)
    _build_transport_fields(node, entity_data)
    _build_radar_fields(node)
    _build_select_fields(node)


func _build_health_fields(node: Node3D) -> void:
    var hp := node.get_node_or_null("HealthComponent") as HealthComponent
    if not hp:
        return
    var section := Label.new()
    section.text = "Health"
    section.add_theme_font_size_override("font_size", 13)
    _vbox.add_child(section)

    var row := HBoxContainer.new()
    _vbox.add_child(row)
    var lbl := Label.new()
    lbl.text = "HP:"
    row.add_child(lbl)
    var spin := SpinBox.new()
    spin.min_value = 0
    spin.max_value = hp.max_health
    spin.value = hp.current_health
    spin.value_changed.connect(_on_health_changed.bind(spin))
    row.add_child(spin)

    var max_row := HBoxContainer.new()
    _vbox.add_child(max_row)
    var max_lbl := Label.new()
    max_lbl.text = "Max:"
    max_row.add_child(max_lbl)
    var max_spin := SpinBox.new()
    max_spin.min_value = 1
    max_spin.max_value = 65535
    max_spin.value = hp.max_health
    max_spin.value_changed.connect(_on_max_health_changed.bind(max_spin))
    max_row.add_child(max_spin)

    _add_separator()


func _build_power_fields(node: Node3D) -> void:
    var power := node.get_node_or_null("PowerComponent") as PowerComponent
    if not power:
        return
    if power.power == 0 and not power.powered:
        return
    var section := Label.new()
    section.text = "Power"
    section.add_theme_font_size_override("font_size", 13)
    _vbox.add_child(section)

    if power.power != 0:
        var row := HBoxContainer.new()
        _vbox.add_child(row)
        var lbl := Label.new()
        lbl.text = "Output:"
        row.add_child(lbl)
        var spin := SpinBox.new()
        spin.min_value = -9999
        spin.max_value = 9999
        spin.value = power.power
        spin.value_changed.connect(_on_power_changed.bind(spin))
        row.add_child(spin)

    if power.powered:
        var row2 := HBoxContainer.new()
        _vbox.add_child(row2)
        var cb := CheckBox.new()
        cb.text = "Powered"
        cb.button_pressed = power.is_powered()
        cb.toggled.connect(_on_powered_toggled)
        row2.add_child(cb)

    _add_separator()


func _build_stats_fields(node: Node3D, entity_data: EntityData) -> void:
    var stats := node.get_node_or_null("StatsComponent") as StatsComponent
    if not stats:
        return
    var section := Label.new()
    section.text = "Stats"
    section.add_theme_font_size_override("font_size", 13)
    _vbox.add_child(section)

    _add_read_only_row("Type", EntityData.EntityType.keys()[entity_data.entity_type])
    _add_read_only_row("Armor", stats.armor)
    _add_read_only_row("Sight", str(stats.sight))

    if stats.cost > 0:
        var row := HBoxContainer.new()
        _vbox.add_child(row)
        var lbl := Label.new()
        lbl.text = "Cost:"
        row.add_child(lbl)
        var spin := SpinBox.new()
        spin.min_value = 0
        spin.max_value = 999999
        spin.value = stats.cost
        spin.value_changed.connect(_on_cost_changed.bind(spin))
        row.add_child(spin)

    if stats.tech_level >= 0:
        var row2 := HBoxContainer.new()
        _vbox.add_child(row2)
        var lbl2 := Label.new()
        lbl2.text = "Tech Lvl:"
        row2.add_child(lbl2)
        var spin2 := SpinBox.new()
        spin2.min_value = 0
        spin2.max_value = 99
        spin2.value = stats.tech_level
        spin2.value_changed.connect(_on_tech_level_changed.bind(spin2))
        row2.add_child(spin2)

    _add_separator()


func _build_foundation_fields(entity_data: EntityData) -> void:
    var section := Label.new()
    section.text = "Foundation"
    section.add_theme_font_size_override("font_size", 13)
    _vbox.add_child(section)
    _add_read_only_row("Size", "%d × %d" % [entity_data.foundation.x, entity_data.foundation.y])
    _add_separator()


func _build_factory_fields(node: Node3D) -> void:
    var factory := node.get_node_or_null("FactoryComponent") as FactoryComponent
    if not factory:
        return
    if factory.factory_type.is_empty():
        return
    var section := Label.new()
    section.text = "Factory"
    section.add_theme_font_size_override("font_size", 13)
    _vbox.add_child(section)
    _add_read_only_row("Type", factory.factory_type)
    if not factory.free_unit.is_empty():
        _add_read_only_row("Free Unit", factory.free_unit)
    _add_separator()


func _build_transport_fields(_node: Node3D, entity_data: EntityData) -> void:
    if entity_data.passengers == 0 and entity_data.dock.is_empty() and not entity_data.harvester:
        return
    var section := Label.new()
    section.text = "Transport"
    section.add_theme_font_size_override("font_size", 13)
    _vbox.add_child(section)
    if entity_data.passengers > 0:
        _add_read_only_row("Passengers", str(entity_data.passengers))
    if not entity_data.dock.is_empty():
        _add_read_only_row("Dock", entity_data.dock)
    if entity_data.harvester:
        _add_read_only_row("Harvester", "Yes")
        if entity_data.storage > 0:
            _add_read_only_row("Storage", str(entity_data.storage))
    _add_separator()


func _build_radar_fields(node: Node3D) -> void:
    var radar := node.get_node_or_null("RadarComponent") as RadarComponent
    if not radar:
        return
    if not radar.radar:
        return
    var section := Label.new()
    section.text = "Radar"
    section.add_theme_font_size_override("font_size", 13)
    _vbox.add_child(section)
    _add_read_only_row("Active", "Yes")
    _add_separator()


func _build_select_fields(node: Node3D) -> void:
    var select_comp := node.get_node_or_null("SelectComponent") as SelectComponent
    if not select_comp:
        return
    var section := Label.new()
    section.text = "Selection"
    section.add_theme_font_size_override("font_size", 13)
    _vbox.add_child(section)
    var box_type_name: String = SelectComponent.SelectBoxType.keys()[select_comp.select_box_type]
    _add_read_only_row("Box Type", box_type_name)
    _add_separator()


func _build_delete_button() -> void:
    var btn := Button.new()
    btn.text = "Delete Entity"
    btn.add_theme_color_override("font_color", Color.RED)
    btn.pressed.connect(_on_delete_pressed)
    _vbox.add_child(btn)


func _add_read_only_row(label_text: String, value_text: String) -> void:
    var row := HBoxContainer.new()
    _vbox.add_child(row)
    var lbl := Label.new()
    lbl.text = label_text + ":"
    row.add_child(lbl)
    var val := Label.new()
    val.text = value_text
    val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(val)


func _add_separator() -> void:
    var sep := HSeparator.new()
    _vbox.add_child(sep)


func _on_rotation_changed(index: int, _dropdown: OptionButton) -> void:
    if _current_entry.is_empty():
        return
    var new_rot: float = ROTATION_VALUES[index]
    _current_entry["rotation_y"] = new_rot
    var node: Node3D = _current_entry.get("node") as Node3D
    if is_instance_valid(node) and _entity_selector:
        _entity_selector._apply_rotation_with_slope(node, new_rot)


func _on_player_changed(index: int, _dropdown: OptionButton) -> void:
    if _current_entry.is_empty():
        return
    _current_entry["player_id"] = index


func _on_health_changed(value: float, _spin: SpinBox) -> void:
    var node: Node3D = _current_entry.get("node") as Node3D
    if not is_instance_valid(node):
        return
    var hp := node.get_node_or_null("HealthComponent") as HealthComponent
    if hp:
        hp.current_health = int(value)


func _on_max_health_changed(value: float, _spin: SpinBox) -> void:
    var node: Node3D = _current_entry.get("node") as Node3D
    if not is_instance_valid(node):
        return
    var hp := node.get_node_or_null("HealthComponent") as HealthComponent
    if hp:
        hp.max_health = int(value)


func _on_power_changed(value: float, _spin: SpinBox) -> void:
    var node: Node3D = _current_entry.get("node") as Node3D
    if not is_instance_valid(node):
        return
    var power := node.get_node_or_null("PowerComponent") as PowerComponent
    if power:
        power.power = int(value)


func _on_powered_toggled(pressed: bool) -> void:
    var node: Node3D = _current_entry.get("node") as Node3D
    if not is_instance_valid(node):
        return
    var power := node.get_node_or_null("PowerComponent") as PowerComponent
    if power:
        power.powered = pressed


func _on_cost_changed(value: float, _spin: SpinBox) -> void:
    var node: Node3D = _current_entry.get("node") as Node3D
    if not is_instance_valid(node):
        return
    var stats := node.get_node_or_null("StatsComponent") as StatsComponent
    if stats:
        stats.cost = int(value)


func _on_tech_level_changed(value: float, _spin: SpinBox) -> void:
    var node: Node3D = _current_entry.get("node") as Node3D
    if not is_instance_valid(node):
        return
    var stats := node.get_node_or_null("StatsComponent") as StatsComponent
    if stats:
        stats.tech_level = int(value)


func _on_delete_pressed() -> void:
    if _entity_selector:
        _entity_selector.delete_selected()
    hide_panel()
