@tool
extends Node3D

enum Tool { NONE, PAINT_HEIGHT, PAINT_RESOURCE, PLACE_TREE, ERASE, PLACE_ENTITY }

@export var map_size: Vector2 = Vector2(50.0, 50.0)
@export var show_grid: bool = true

var _hovered_cell: Vector2i = Vector2i(-999, -999)
var _camera: Camera3D
var _camera_pivot: Node3D
var _height_painter: Node
var _tool_buttons: Dictionary = {}
var _active_tool: int = Tool.NONE
var _painted_entities: Dictionary = {}

var _grid: Node
var _entity_placer: Node
var _resource_painter: Node
var _save_load: Node
var _entity_selector: Node
var _entity_properties: Node
var _settings_popup: PopupMenu


func _ready() -> void:
    if Engine.is_editor_hint():
        return
    set_meta("is_map_editor", true)
    _setup_camera()
    TerrainSystem.init_grid(ceili(map_size.x), ceili(map_size.y))
    BoundsSystem.camera_pivot = _camera_pivot
    BoundsSystem._center_camera_on_diamond()
    _setup_grid()
    _setup_height_painter()
    _height_painter.height_changed.connect(_on_height_changed)
    TerrainSystem.cell_changed.connect(_on_terrain_cell_changed)
    _prefill_terrain()
    _setup_ui()


func _exit_tree() -> void:
    if Engine.is_editor_hint():
        return
    _entity_placer.cleanup()
    _entity_selector.cleanup()
    _painted_entities.clear()
    TerrainSystem.clear()
    var renderer := get_node_or_null("TerrainRenderer")
    if renderer and renderer.has_method("clear_all"):
        renderer.clear_all()


func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        return
    _update_hovered_cell()
    _grid.update()


func _input(event: InputEvent) -> void:
    if Engine.is_editor_hint() or _camera == null:
        return
    if get_viewport().gui_get_hovered_control() != null:
        return

    if _active_tool == Tool.PAINT_HEIGHT:
        return

    if _active_tool == Tool.NONE:
        _entity_selector.handle_input(event)
        return

    if _active_tool == Tool.PLACE_TREE:
        _entity_placer.handle_tree_input(event)
        return

    if _active_tool == Tool.PLACE_ENTITY:
        _entity_placer.handle_input(event)
        return

    if _active_tool in [Tool.PAINT_RESOURCE, Tool.ERASE]:
        _resource_painter.handle_input(event)


func _setup_camera() -> void:
    var camera_scene := preload("res://scenes/hud/Camera01.tscn")
    var camera_instance := camera_scene.instantiate()
    add_child(camera_instance)
    _camera = camera_instance.get_node("Camera3D")
    _camera_pivot = camera_instance
    BoundsSystem.show_bounds = true


func _setup_grid() -> void:
    _grid = preload("res://scripts/editor/EditorGrid.gd").new()
    _grid.name = "EditorGrid"
    _grid.editor = self
    add_child(_grid)
    _grid.setup()


func _setup_height_painter() -> void:
    _height_painter = preload("res://scripts/editor/HeightPainter.gd").new()
    _height_painter.name = "HeightPainter"
    _height_painter.editor = self
    add_child(_height_painter)


func _prefill_terrain() -> void:
    var extent: Vector2i = CellUtil.get_diamond_extent(TerrainSystem.grid_cells)
    var cells_x: int = extent.x
    var cells_z: int = extent.y
    for x in range(cells_x):
        for z in range(cells_z):
            var cell := Vector2i(x, z)
            if not CellUtil.is_in_diamond(cell, TerrainSystem.grid_cells):
                continue
            if TerrainSystem.get_cell(cell).is_empty():
                TerrainSystem.compute_and_emit_cell(cell)


func _clear_terrain_renderer() -> void:
    var renderer := get_node_or_null("TerrainRenderer")
    if renderer and renderer.has_method("clear_all"):
        renderer.clear_all()


func _setup_ui() -> void:
    var ui := CanvasLayer.new()
    ui.name = "EditorUI"
    add_child(ui)

    var tool_bar := HBoxContainer.new()
    tool_bar.name = "ToolBar"
    tool_bar.position = Vector2(10, 10)
    ui.add_child(tool_bar)

    _save_load = preload("res://scripts/editor/EditorSaveLoad.gd").new()
    _save_load.name = "EditorSaveLoad"
    _save_load.editor = self
    add_child(_save_load)
    _save_load.setup(ui)

    # File menu
    var file_menu_btn := MenuButton.new()
    file_menu_btn.text = "File"
    var file_popup: PopupMenu = file_menu_btn.get_popup()
    file_popup.add_item("New", 0)
    file_popup.add_item("Load", 1)
    file_popup.add_item("Save", 2)
    file_popup.id_pressed.connect(_on_file_menu_pressed)
    tool_bar.add_child(file_menu_btn)

    # Settings menu
    var settings_menu_btn := MenuButton.new()
    settings_menu_btn.text = "Settings"
    _settings_popup = settings_menu_btn.get_popup()
    _settings_popup.add_item("Map Settings", 0)
    _settings_popup.add_check_item("Show Grid", 1)
    _settings_popup.set_item_checked(1, false)
    _settings_popup.id_pressed.connect(_on_settings_menu_pressed)
    tool_bar.add_child(settings_menu_btn)

    var sep1 := VSeparator.new()
    tool_bar.add_child(sep1)

    var tools := [
        {"name": "Paint Height", "tool": Tool.PAINT_HEIGHT},
        {"name": "Paint Resource", "tool": Tool.PAINT_RESOURCE},
        {"name": "Place Tree", "tool": Tool.PLACE_TREE},
        {"name": "Erase", "tool": Tool.ERASE},
    ]
    for t in tools:
        var btn := Button.new()
        btn.text = t.name
        btn.toggle_mode = true
        var tool_id: int = t.tool
        btn.pressed.connect(_on_tool_toggled.bind(btn, tool_id))
        _tool_buttons[tool_id] = btn
        tool_bar.add_child(btn)

    var sep2 := VSeparator.new()
    tool_bar.add_child(sep2)

    _resource_painter = preload("res://scripts/editor/ResourcePainter.gd").new()
    _resource_painter.name = "ResourcePainter"
    _resource_painter.editor = self
    add_child(_resource_painter)

    var str_label := Label.new()
    str_label.text = "Strength:"
    tool_bar.add_child(str_label)
    var str_slider := HSlider.new()
    str_slider.name = "StrengthSlider"
    str_slider.min_value = 0.0
    str_slider.max_value = 100.0
    str_slider.value = _resource_painter._paint_strength
    str_slider.step = 1.0
    str_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    str_slider.custom_minimum_size = Vector2(100, 0)
    str_slider.value_changed.connect(_resource_painter.set_strength)
    tool_bar.add_child(str_slider)

    var rad_label := Label.new()
    rad_label.text = "Radius:"
    tool_bar.add_child(rad_label)
    var rad_spin := SpinBox.new()
    rad_spin.name = "RadiusSpinBox"
    rad_spin.min_value = 1.0
    rad_spin.max_value = 20.0
    rad_spin.value = _resource_painter._paint_radius
    rad_spin.value_changed.connect(_resource_painter.set_radius)
    tool_bar.add_child(rad_spin)

    var sep3 := VSeparator.new()
    tool_bar.add_child(sep3)

    var h_label := Label.new()
    h_label.text = "Height: 0"
    _grid._height_label = h_label
    tool_bar.add_child(h_label)

    # Grid defaults to off
    _grid.set_grid_visible(false)

    var minimap_script = load("res://scripts/editor/Minimap.gd")
    if minimap_script:
        var minimap: SubViewportContainer = minimap_script.new()
        minimap.name = "Minimap"
        minimap.position = Vector2(get_viewport().size.x - 210, 10)
        ui.add_child(minimap)
        minimap.set_game_camera(_camera, _camera_pivot)

    _entity_placer = preload("res://scripts/editor/EntityPlacer.gd").new()
    _entity_placer.name = "EntityPlacer"
    _entity_placer.editor = self
    add_child(_entity_placer)
    _entity_placer.setup(ui)

    _entity_selector = preload("res://scripts/editor/EntitySelector.gd").new()
    _entity_selector.name = "EntitySelector"
    _entity_selector.editor = self
    add_child(_entity_selector)
    _entity_selector.setup(_camera, ui)
    _entity_selector.selection_changed.connect(_on_editor_selection_changed)

    _entity_properties = preload("res://scripts/editor/EntityProperties.gd").new()
    _entity_properties.name = "EntityProperties"
    _entity_properties.position = Vector2(get_viewport().size.x - 230, 220)
    ui.add_child(_entity_properties)
    _entity_properties.setup(_entity_selector)


func _on_file_menu_pressed(id: int) -> void:
    match id:
        0:
            _show_new_map_dialog()
        1:
            _save_load.on_load_pressed()
        2:
            _save_load.on_save_pressed()


func _on_settings_menu_pressed(id: int) -> void:
    match id:
        0:
            _show_map_settings_dialog()
        1:
            var checked: bool = _settings_popup.is_item_checked(1)
            _settings_popup.set_item_checked(1, not checked)
            _grid.set_grid_visible(not checked)


# ========================================
# New Map Dialog
# ========================================


func _show_new_map_dialog() -> void:
    var dialog := PopupPanel.new()
    dialog.name = "NewMapDialog"
    dialog.title = "New Map"
    dialog.size = Vector2i(400, 520)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 8)
    dialog.add_child(vbox)

    var name_label := Label.new()
    name_label.text = "Map Name:"
    vbox.add_child(name_label)
    var name_edit := LineEdit.new()
    name_edit.text = "Untitled"
    name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_child(name_edit)

    var width_label := Label.new()
    width_label.text = "Width (X):"
    vbox.add_child(width_label)
    var width_spin := SpinBox.new()
    width_spin.min_value = 20.0
    width_spin.max_value = 512.0
    width_spin.step = 1.0
    width_spin.value = 50.0
    width_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_child(width_spin)

    var height_label := Label.new()
    height_label.text = "Height (Z):"
    vbox.add_child(height_label)
    var height_spin := SpinBox.new()
    height_spin.min_value = 20.0
    height_spin.max_value = 512.0
    height_spin.step = 1.0
    height_spin.value = 50.0
    height_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_child(height_spin)

    var start_h_label := Label.new()
    start_h_label.text = "Starting Height:"
    vbox.add_child(start_h_label)
    var start_h_spin := SpinBox.new()
    start_h_spin.min_value = 0.0
    start_h_spin.max_value = 12.0
    start_h_spin.step = 4.0
    start_h_spin.value = 0.0
    start_h_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_child(start_h_spin)

    var players_label := Label.new()
    players_label.text = "Player Count:"
    vbox.add_child(players_label)
    var players_spin := SpinBox.new()
    players_spin.min_value = 2.0
    players_spin.max_value = 8.0
    players_spin.step = 1.0
    players_spin.value = 2.0
    players_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_child(players_spin)

    var offset_x_label := Label.new()
    offset_x_label.text = "Visible Bounds Width:"
    vbox.add_child(offset_x_label)
    var offset_x_spin := SpinBox.new()
    offset_x_spin.min_value = 0.0
    offset_x_spin.max_value = 512.0
    offset_x_spin.step = 1.0
    offset_x_spin.value = width_spin.value - 10.0
    offset_x_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_child(offset_x_spin)

    var offset_z_label := Label.new()
    offset_z_label.text = "Visible Bounds Height:"
    vbox.add_child(offset_z_label)
    var offset_z_spin := SpinBox.new()
    offset_z_spin.min_value = 0.0
    offset_z_spin.max_value = 512.0
    offset_z_spin.step = 1.0
    offset_z_spin.value = height_spin.value - 8.0
    offset_z_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_child(offset_z_spin)

    var bounds_label := Label.new()
    vbox.add_child(bounds_label)

    var update_bounds := func() -> void:
        var w: int = int(width_spin.value)
        var h: int = int(height_spin.value)
        var ox: int = int(offset_x_spin.value)
        var oz: int = int(offset_z_spin.value)
        bounds_label.text = "Visible Bounds: %d × %d" % [ox, oz]

    width_spin.value_changed.connect(
        func(_v: float) -> void:
            offset_x_spin.value = width_spin.value - 10.0
            update_bounds.call()
    )
    height_spin.value_changed.connect(
        func(_v: float) -> void:
            offset_z_spin.value = height_spin.value - 8.0
            update_bounds.call()
    )
    offset_x_spin.value_changed.connect(func(_v: float) -> void: update_bounds.call())
    offset_z_spin.value_changed.connect(func(_v: float) -> void: update_bounds.call())
    update_bounds.call()

    var btn_row := HBoxContainer.new()
    btn_row.alignment = BoxContainer.ALIGNMENT_END
    btn_row.add_theme_constant_override("separation", 8)
    vbox.add_child(btn_row)

    var cancel_btn := Button.new()
    cancel_btn.text = "Cancel"
    cancel_btn.pressed.connect(func() -> void: dialog.queue_free())
    btn_row.add_child(cancel_btn)

    var create_btn := Button.new()
    create_btn.text = "Create"
    create_btn.pressed.connect(
        func() -> void:
            var w: int = int(width_spin.value)
            var h: int = int(height_spin.value)
            var start_h: int = int(start_h_spin.value)
            var players: int = int(players_spin.value)
            var ox: int = int(offset_x_spin.value)
            var oz: int = int(offset_z_spin.value)
            _apply_new_map(w, h, start_h, players, ox, oz)
            dialog.queue_free()
    )
    btn_row.add_child(create_btn)

    get_node("EditorUI").add_child(dialog)
    dialog.popup_centered(Vector2i(400, 520))


func _apply_new_map(
    width: int,
    height: int,
    _start_height: int,
    _player_count: int,
    offset_x: int = 0,
    offset_z: int = 0
) -> void:
    _clear_terrain_renderer()
    TerrainSystem.clear()
    TerrainSystem.init_grid(width, height)
    BoundsSystem.set_visible_bounds_size(Vector2i(offset_x, offset_z))
    _prefill_terrain()
    _grid._draw_grid()


# ========================================
# Map Settings Dialog
# ========================================


func _show_map_settings_dialog() -> void:
    var dialog := PopupPanel.new()
    dialog.name = "MapSettingsDialog"
    dialog.title = "Map Settings"
    dialog.size = Vector2i(400, 480)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 8)
    dialog.add_child(vbox)

    var width_label := Label.new()
    width_label.text = "Width (X):"
    vbox.add_child(width_label)
    var width_spin := SpinBox.new()
    width_spin.min_value = 20.0
    width_spin.max_value = 512.0
    width_spin.step = 1.0
    width_spin.value = float(TerrainSystem.grid_cells.x)
    width_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_child(width_spin)

    var height_label := Label.new()
    height_label.text = "Height (Z):"
    vbox.add_child(height_label)
    var height_spin := SpinBox.new()
    height_spin.min_value = 20.0
    height_spin.max_value = 512.0
    height_spin.step = 1.0
    height_spin.value = float(TerrainSystem.grid_cells.y)
    height_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_child(height_spin)

    var offset_x_label := Label.new()
    offset_x_label.text = "Visible Bounds Width:"
    vbox.add_child(offset_x_label)
    var offset_x_spin := SpinBox.new()
    offset_x_spin.min_value = 0.0
    offset_x_spin.max_value = 512.0
    offset_x_spin.step = 1.0
    offset_x_spin.value = float(BoundsSystem.visible_bounds_size.x)
    offset_x_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_child(offset_x_spin)

    var offset_z_label := Label.new()
    offset_z_label.text = "Visible Bounds Height:"
    vbox.add_child(offset_z_label)
    var offset_z_spin := SpinBox.new()
    offset_z_spin.min_value = 0.0
    offset_z_spin.max_value = 512.0
    offset_z_spin.step = 1.0
    offset_z_spin.value = float(BoundsSystem.visible_bounds_size.y)
    offset_z_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_child(offset_z_spin)

    var bounds_label := Label.new()
    vbox.add_child(bounds_label)

    var update_bounds := func() -> void:
        var w: int = int(width_spin.value)
        var h: int = int(height_spin.value)
        var ox: int = int(offset_x_spin.value)
        var oz: int = int(offset_z_spin.value)
        bounds_label.text = "Visible Bounds: %d × %d" % [ox, oz]

    width_spin.value_changed.connect(
        func(_v: float) -> void:
            offset_x_spin.value = width_spin.value - 10.0
            update_bounds.call()
    )
    height_spin.value_changed.connect(
        func(_v: float) -> void:
            offset_z_spin.value = height_spin.value - 8.0
            update_bounds.call()
    )
    offset_x_spin.value_changed.connect(func(_v: float) -> void: update_bounds.call())
    offset_z_spin.value_changed.connect(func(_v: float) -> void: update_bounds.call())
    update_bounds.call()

    var btn_row := HBoxContainer.new()
    btn_row.alignment = BoxContainer.ALIGNMENT_END
    btn_row.add_theme_constant_override("separation", 8)
    vbox.add_child(btn_row)

    var cancel_btn := Button.new()
    cancel_btn.text = "Cancel"
    cancel_btn.pressed.connect(func() -> void: dialog.queue_free())
    btn_row.add_child(cancel_btn)

    var apply_btn := Button.new()
    apply_btn.text = "Apply"
    apply_btn.pressed.connect(
        func() -> void:
            var w: int = int(width_spin.value)
            var h: int = int(height_spin.value)
            var ox: int = int(offset_x_spin.value)
            var oz: int = int(offset_z_spin.value)
            _apply_map_settings(w, h, ox, oz)
            dialog.queue_free()
    )
    btn_row.add_child(apply_btn)

    get_node("EditorUI").add_child(dialog)
    dialog.popup_centered(Vector2i(400, 480))


func _apply_map_settings(width: int, height: int, offset_x: int = 0, offset_z: int = 0) -> void:
    _clear_terrain_renderer()
    TerrainSystem.clear()
    TerrainSystem.init_grid(width, height)
    BoundsSystem.set_visible_bounds_size(Vector2i(offset_x, offset_z))
    _prefill_terrain()
    _grid._draw_grid()


func _on_tool_toggled(btn: Button, tool_id: int) -> void:
    if btn.button_pressed:
        _active_tool = tool_id
        for tid in _tool_buttons:
            _tool_buttons[tid].button_pressed = (tid == tool_id)
        _entity_placer.on_tool_toggled()
        if tool_id != Tool.NONE:
            _entity_selector.deselect_all()
            _entity_properties.hide_panel()
    else:
        _active_tool = Tool.NONE
        _entity_placer.on_tool_toggled()


func _update_hovered_cell() -> void:
    if not _camera:
        return
    var mouse_pos := get_viewport().get_mouse_position()
    var ray_origin := _camera.project_ray_origin(mouse_pos)
    var ray_direction := _camera.project_ray_normal(mouse_pos)
    var ground_plane := Plane(Vector3.UP, 0.0)
    var intersection = ground_plane.intersects_ray(ray_origin, ray_direction)
    if not intersection:
        return
    var hit_pos := intersection as Vector3
    var terrain_y := TerrainSystem.get_height_at_world_smooth(hit_pos)
    if terrain_y > 0.01:
        var t := (terrain_y - ray_origin.y) / ray_direction.y
        hit_pos = ray_origin + ray_direction * t
    var cell := CellUtil.world_to_cell(hit_pos)
    if cell != _hovered_cell and not TerrainSystem.get_cell(cell).is_empty():
        _hovered_cell = cell
        _grid.update()
    _entity_placer.on_cell_changed()


func _cell_world_pos(cell: Vector2i) -> Vector3:
    var pos := CellUtil.cell_to_world(cell)
    var cell_data: Dictionary = TerrainSystem.get_cell(cell)
    if not cell_data.is_empty():
        var h: int = cell_data.get("max_height", cell_data.get("height", 0))
        pos.y = float(h) * TerrainSystem.HEIGHT_STEP
    return pos


func _cell_origin_world_pos(origin: Vector2i, footprint: Vector2i) -> Vector3:
    var pos := CellUtil.cell_origin_to_world(origin, footprint)
    var max_h := 0
    for dx in footprint.x:
        for dz in footprint.y:
            var cell := origin + Vector2i(dx, dz)
            var cell_data: Dictionary = TerrainSystem.get_cell(cell)
            if not cell_data.is_empty():
                var h: int = cell_data.get("max_height", cell_data.get("height", 0))
                if h > max_h:
                    max_h = h
    pos.y = float(max_h) * TerrainSystem.HEIGHT_STEP
    return pos


func get_hovered_cell() -> Vector2i:
    return _hovered_cell


func _on_height_changed(cell: Vector2i, new_height: int) -> void:
    if cell == _hovered_cell:
        _grid.update()
    var key := str(cell.x) + "," + str(cell.y)
    var entry := _painted_entities.get(key, {}) as Dictionary
    var node := entry.get("node") as Node3D
    if is_instance_valid(node):
        node.position.y = float(new_height) * TerrainSystem.HEIGHT_STEP
        var tib := node.get_node_or_null("ResourceComponent") as ResourceComponent
        if tib:
            tib.update_slope_positions()
    if _entity_selector.is_entity_selected(key):
        _entity_selector.refresh_slope_tilt()


func _on_terrain_cell_changed(key: String, data: Dictionary) -> void:
    var entry := _painted_entities.get(key, {}) as Dictionary
    var node := entry.get("node") as Node3D
    if not is_instance_valid(node):
        return
    var h: int = data.get("max_height", data.get("height", 0))
    node.position.y = float(h) * TerrainSystem.HEIGHT_STEP
    var tib := node.get_node_or_null("ResourceComponent") as ResourceComponent
    if tib:
        tib.update_slope_positions()
    if _entity_selector.is_entity_selected(key):
        _entity_selector.refresh_slope_tilt()


func _on_editor_selection_changed(selected_count: int) -> void:
    if selected_count == 0:
        _entity_properties.hide_panel()
        return
    var entries: Array[Dictionary] = _entity_selector.get_selected_entries()
    if entries.is_empty():
        _entity_properties.hide_panel()
        return
    var first: Dictionary = entries[0]
    _entity_properties.rebuild(first.get("cell_key", ""), first.get("data", {}))
