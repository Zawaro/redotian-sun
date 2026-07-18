@tool
extends Node3D

enum Tool { NONE, PAINT_HEIGHT, PAINT_RESOURCE, PLACE_TREE, ERASE, PLACE_ENTITY }

@export var map_size: Vector2 = Vector2(64.0, 64.0)
@export var visible_bounds_size: Vector2 = Vector2(54.0, 54.0)
@export var show_grid: bool = true

var _hovered_cell: Vector2i = Vector2i(-999, -999)
var _camera: Camera3D
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


func _ready() -> void:
    if Engine.is_editor_hint():
        return
    TerrainSystem.init_grid(ceili(map_size.x * sqrt(2)))
    _setup_camera()
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
    var bounds := BoundsSystem.new()
    bounds.name = "BoundsSystem"
    bounds.map_size = map_size
    bounds.visible_bounds_size = visible_bounds_size
    add_child(bounds)
    camera_instance.bounds_system = bounds


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
    var cells := TerrainSystem.grid_cells
    var center_world: float = float(cells) * 0.5 * Pathfinder.CELL_SIZE
    var half_extent: float = center_world
    for x in range(cells):
        for z in range(cells):
            var cell := Vector2i(x, z)
            var world_center := (
                Pathfinder.cell_to_world(cell) - Vector3(center_world, 0, center_world)
            )
            if half_extent > 0.0:
                if absf(world_center.x) / half_extent + absf(world_center.z) / half_extent >= 1.0:
                    continue
            if TerrainSystem.get_cell(cell).is_empty():
                TerrainSystem.compute_and_emit_cell(cell)


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

    var save_btn := Button.new()
    save_btn.text = "Save"
    save_btn.pressed.connect(_save_load.on_save_pressed)
    tool_bar.add_child(save_btn)
    var load_btn := Button.new()
    load_btn.text = "Load"
    load_btn.pressed.connect(_save_load.on_load_pressed)
    tool_bar.add_child(load_btn)

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

    var grid_cb := CheckBox.new()
    grid_cb.text = "Grid"
    grid_cb.button_pressed = true
    grid_cb.toggled.connect(func(pressed: bool) -> void: _grid.set_grid_visible(pressed))
    tool_bar.add_child(grid_cb)

    var h_label := Label.new()
    h_label.text = "Height: 0"
    _grid._height_label = h_label
    tool_bar.add_child(h_label)

    var minimap_script = load("res://scripts/editor/Minimap.gd")
    if minimap_script:
        var minimap: SubViewportContainer = minimap_script.new()
        minimap.name = "Minimap"
        minimap.position = Vector2(get_viewport().size.x - 210, 10)
        ui.add_child(minimap)

    _entity_placer = preload("res://scripts/editor/EntityPlacer.gd").new()
    _entity_placer.name = "EntityPlacer"
    _entity_placer.editor = self
    add_child(_entity_placer)
    _entity_placer.setup(ui)

    _entity_selector = preload("res://scripts/editor/EntitySelector.gd").new()
    _entity_selector.name = "EntitySelector"
    _entity_selector.editor = self
    add_child(_entity_selector)
    _entity_selector.setup(_camera)
    _entity_selector.selection_changed.connect(_on_editor_selection_changed)

    _entity_properties = preload("res://scripts/editor/EntityProperties.gd").new()
    _entity_properties.name = "EntityProperties"
    _entity_properties.position = Vector2(get_viewport().size.x - 230, 220)
    ui.add_child(_entity_properties)
    _entity_properties.setup(_entity_selector)


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
    var grid_half: float = float(TerrainSystem.grid_cells) * Pathfinder.CELL_SIZE * 0.5
    var cell := Pathfinder.world_to_cell(hit_pos + Vector3(grid_half, 0, grid_half))
    if cell != _hovered_cell and not TerrainSystem.get_cell(cell).is_empty():
        _hovered_cell = cell
        _grid.update()
    _entity_placer.on_cell_changed()


func _cell_world_pos(cell: Vector2i) -> Vector3:
    var grid_half: float = float(TerrainSystem.grid_cells) * Pathfinder.CELL_SIZE * 0.5
    var pos := Pathfinder.cell_to_world(cell) - Vector3(grid_half, 0.0, grid_half)
    var cell_data: Dictionary = TerrainSystem.get_cell(cell)
    if not cell_data.is_empty():
        var h: int = cell_data.get("max_height", cell_data.get("height", 0))
        pos.y = float(h) * TerrainSystem.HEIGHT_STEP
    return pos


func _cell_origin_world_pos(origin: Vector2i, footprint: Vector2i) -> Vector3:
    var grid_half: float = float(TerrainSystem.grid_cells) * Pathfinder.CELL_SIZE * 0.5
    var center_x := (origin.x + footprint.x * 0.5) * Pathfinder.CELL_SIZE - grid_half
    var center_z := (origin.y + footprint.y * 0.5) * Pathfinder.CELL_SIZE - grid_half
    var max_h := 0
    for dx in footprint.x:
        for dz in footprint.y:
            var cell := origin + Vector2i(dx, dz)
            var cell_data: Dictionary = TerrainSystem.get_cell(cell)
            if not cell_data.is_empty():
                var h: int = cell_data.get("max_height", cell_data.get("height", 0))
                if h > max_h:
                    max_h = h
    return Vector3(center_x, float(max_h) * TerrainSystem.HEIGHT_STEP, center_z)


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
