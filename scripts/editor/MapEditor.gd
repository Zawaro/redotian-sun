@tool
extends Node3D

enum Tool { NONE, PAINT_HEIGHT, PAINT_TIBERIUM, PLACE_TREE, ERASE }

@export var map_size: Vector2 = Vector2(64.0, 64.0)
@export var visible_bounds_size: Vector2 = Vector2(54.0, 54.0)
@export var show_grid: bool = true

var _grid_overlay: MeshInstance3D
var _cell_highlight: MeshInstance3D
var _hovered_cell: Vector2i = Vector2i(-999, -999)
var _camera: Camera3D
var _height_painter: Node
var _tool_buttons: Dictionary = {}
var _active_tool: int = Tool.NONE
var _paint_strength: float = 50.0
var _paint_radius: int = 1
var _is_painting: bool = false
var _save_dialog: FileDialog
var _load_dialog: FileDialog
var _highlight_quad_mat: ORMMaterial3D
var _highlight_line_mat: ORMMaterial3D
var _height_label: Label
var _painted_entities: Dictionary = {}

const TIB_DEFAULT_AMOUNT: int = 300
const TIB_DEFAULT_MAX: int = 300
const OVERRIDE_KEYS: PackedStringArray = [
    "tiberium_amount",
    "tiberium_max_amount",
    "resource_type_id",
    "tiberium_regrowth_rate",
    "radius_cells",
    "node_count",
    "amount_per_node",
    "max_amount_per_node",
]


func _ready() -> void:
    if Engine.is_editor_hint():
        return
    TerrainSystem.init_grid(ceili(map_size.x * sqrt(2)))
    _setup_camera()
    _setup_grid_overlay()
    _setup_height_painter()
    _height_painter.height_changed.connect(_on_height_changed)
    TerrainSystem.cell_changed.connect(_on_terrain_cell_changed)
    _prefill_terrain()
    _setup_ui()


func _exit_tree() -> void:
    if Engine.is_editor_hint():
        return
    for key in _painted_entities:
        var node := _painted_entities[key].get("node") as Node3D
        if is_instance_valid(node):
            node.queue_free()
    _painted_entities.clear()
    TerrainSystem.clear()
    var renderer := get_node_or_null("TerrainRenderer")
    if renderer and renderer.has_method("clear_all"):
        renderer.clear_all()


func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        return
    _update_hovered_cell()
    _update_height_label()


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


func _setup_grid_overlay() -> void:
    _grid_overlay = MeshInstance3D.new()
    _grid_overlay.name = "GridOverlay"
    _grid_overlay.top_level = true
    add_child(_grid_overlay)
    _draw_grid()
    _cell_highlight = MeshInstance3D.new()
    _cell_highlight.name = "CellHighlight"
    _cell_highlight.top_level = true
    add_child(_cell_highlight)
    _highlight_quad_mat = ORMMaterial3D.new()
    _highlight_quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _highlight_quad_mat.albedo_color = Color(1, 1, 0, 0.3)
    _highlight_quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _highlight_quad_mat.render_priority = 1
    _highlight_line_mat = ORMMaterial3D.new()
    _highlight_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _highlight_line_mat.albedo_color = Color(0, 0, 0, 0.5)
    _highlight_line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _highlight_line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    _highlight_line_mat.render_priority = 1


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

    var save_btn := Button.new()
    save_btn.text = "Save"
    save_btn.pressed.connect(_on_save_pressed)
    tool_bar.add_child(save_btn)
    var load_btn := Button.new()
    load_btn.text = "Load"
    load_btn.pressed.connect(_on_load_pressed)
    tool_bar.add_child(load_btn)

    var sep1 := VSeparator.new()
    tool_bar.add_child(sep1)

    var tools := [
        {"name": "Paint Height", "tool": Tool.PAINT_HEIGHT},
        {"name": "Paint Tiberium", "tool": Tool.PAINT_TIBERIUM},
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

    var str_label := Label.new()
    str_label.text = "Strength:"
    tool_bar.add_child(str_label)
    var str_slider := HSlider.new()
    str_slider.name = "StrengthSlider"
    str_slider.min_value = 0.0
    str_slider.max_value = 100.0
    str_slider.value = _paint_strength
    str_slider.step = 1.0
    str_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    str_slider.custom_minimum_size = Vector2(100, 0)
    str_slider.value_changed.connect(_on_strength_changed)
    tool_bar.add_child(str_slider)

    var rad_label := Label.new()
    rad_label.text = "Radius:"
    tool_bar.add_child(rad_label)
    var rad_spin := SpinBox.new()
    rad_spin.name = "RadiusSpinBox"
    rad_spin.min_value = 1.0
    rad_spin.max_value = 20.0
    rad_spin.value = _paint_radius
    rad_spin.value_changed.connect(_on_radius_changed)
    tool_bar.add_child(rad_spin)

    var sep3 := VSeparator.new()
    tool_bar.add_child(sep3)
    var h_label := Label.new()
    h_label.text = "Height: 0"
    _height_label = h_label
    tool_bar.add_child(h_label)

    _save_dialog = FileDialog.new()
    _save_dialog.name = "SaveDialog"
    _save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
    _save_dialog.access = FileDialog.ACCESS_FILESYSTEM
    _save_dialog.filters = PackedStringArray(["*.json ; JSON Files"])
    _save_dialog.file_selected.connect(_on_save_file_selected)
    ui.add_child(_save_dialog)
    _load_dialog = FileDialog.new()
    _load_dialog.name = "LoadDialog"
    _load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    _load_dialog.access = FileDialog.ACCESS_FILESYSTEM
    _load_dialog.filters = PackedStringArray(["*.json ; JSON Files"])
    _load_dialog.file_selected.connect(_on_load_file_selected)
    ui.add_child(_load_dialog)

    var minimap_script = load("res://scripts/editor/Minimap.gd")
    if minimap_script:
        var minimap: SubViewportContainer = minimap_script.new()
        minimap.name = "Minimap"
        minimap.position = Vector2(get_viewport().size.x - 210, 10)
        ui.add_child(minimap)


func _on_tool_toggled(btn: Button, tool_id: int) -> void:
    if btn.button_pressed:
        _active_tool = tool_id
        for tid in _tool_buttons:
            _tool_buttons[tid].button_pressed = (tid == tool_id)
    else:
        _active_tool = Tool.NONE


func _on_strength_changed(value: float) -> void:
    _paint_strength = value


func _on_radius_changed(value: float) -> void:
    _paint_radius = ceili(value)


func _input(event: InputEvent) -> void:
    if Engine.is_editor_hint() or _camera == null:
        return
    if get_viewport().gui_get_hovered_control() != null:
        return

    if _active_tool == Tool.PAINT_HEIGHT:
        return

    if _active_tool == Tool.NONE:
        return

    if _active_tool == Tool.PLACE_TREE:
        if (
            event is InputEventMouseButton
            and event.pressed
            and event.button_index == MOUSE_BUTTON_LEFT
        ):
            _place_tree_on_cell(_hovered_cell)
        return

    if _active_tool in [Tool.PAINT_TIBERIUM, Tool.ERASE]:
        if event is InputEventMouseButton:
            if event.button_index == MOUSE_BUTTON_LEFT:
                _is_painting = event.pressed
                if _is_painting and _hovered_cell.x >= 0:
                    _apply_brush(_hovered_cell)
        elif event is InputEventMouseMotion and _is_painting and _hovered_cell.x >= 0:
            _apply_brush(_hovered_cell)


func _apply_brush(center: Vector2i) -> void:
    var extent := _paint_radius - 1
    for dx in range(-extent, extent + 1):
        for dz in range(-extent, extent + 1):
            var cell := center + Vector2i(dx, dz)
            var key := str(cell.x) + "," + str(cell.y)
            if _active_tool == Tool.PAINT_TIBERIUM:
                _paint_tiberium_cell(cell, key)
            elif _active_tool == Tool.ERASE:
                _erase_tiberium_cell(cell, key)


func _paint_tiberium_cell(cell: Vector2i, key: String) -> void:
    if _painted_entities.has(key):
        var entry: Dictionary = _painted_entities[key]
        var node := entry.get("node") as Node3D
        if is_instance_valid(node):
            var tib := node.get_node_or_null("TiberiumComponent") as TiberiumComponent
            if tib:
                var add_amount := ceili(_paint_strength / 100.0 * float(tib.max_amount))
                tib.amount = mini(tib.amount + add_amount, tib.max_amount)
                tib._update_visual()
                entry["data"]["tiberium_amount"] = tib.amount
            return

    var amount_val := ceili(_paint_strength / 100.0 * float(TIB_DEFAULT_MAX))
    var overrides: Dictionary = {
        "tiberium_amount": amount_val,
        "tiberium_max_amount": TIB_DEFAULT_MAX,
        "resource_type_id": "tiberium_green",
    }
    var entity := EntityFactory.create_entity("TIB", overrides)
    if not entity:
        return
    entity.position = _cell_world_pos(cell)
    var data: Dictionary = overrides.duplicate()
    data["id"] = "TIB"
    _painted_entities[key] = {"node": entity, "data": data}
    add_child(entity)


func _erase_tiberium_cell(_cell: Vector2i, key: String) -> void:
    if not _painted_entities.has(key):
        return
    var entry: Dictionary = _painted_entities[key]
    var node := entry.get("node") as Node3D
    if not is_instance_valid(node):
        _painted_entities.erase(key)
        return
    var tib := node.get_node_or_null("TiberiumComponent") as TiberiumComponent
    if not tib:
        _painted_entities.erase(key)
        return
    var reduce_amount := ceili(_paint_strength / 100.0 * float(tib.max_amount))
    tib.amount = maxi(0, tib.amount - reduce_amount)
    entry["data"]["tiberium_amount"] = tib.amount
    tib._update_visual()
    if tib.amount <= 0:
        node.queue_free()
        _painted_entities.erase(key)


func _place_tree_on_cell(cell: Vector2i) -> void:
    var key := str(cell.x) + "," + str(cell.y)
    if _painted_entities.has(key):
        var existing := _painted_entities[key].get("node") as Node3D
        if is_instance_valid(existing):
            existing.queue_free()
        _painted_entities.erase(key)
    var entity := EntityFactory.create_entity("TIBTREE")
    if not entity:
        return
    entity.position = _cell_world_pos(cell)
    var data: Dictionary = {"id": "TIBTREE"}
    _painted_entities[key] = {"node": entity, "data": data}
    add_child(entity)


func _draw_grid() -> void:
    var mesh := ImmediateMesh.new()
    var material := ORMMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(1, 1, 1, 0.3)
    mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)

    var cell_size := Pathfinder.CELL_SIZE
    var cells := TerrainSystem.grid_cells
    var center_world: float = float(cells) * 0.5 * cell_size
    var half_extent: float = center_world

    for i in range(cells + 1):
        var world_x: float = float(i) * cell_size - center_world
        var abs_x: float = absf(world_x)
        var z_limit: float = half_extent * (1.0 - abs_x / half_extent) if half_extent > 0.0 else 0.0
        if z_limit > 0.0:
            mesh.surface_add_vertex(Vector3(world_x, 0.01, -z_limit))
            mesh.surface_add_vertex(Vector3(world_x, 0.01, z_limit))

    for j in range(cells + 1):
        var world_z: float = float(j) * cell_size - center_world
        var abs_z: float = absf(world_z)
        var x_limit: float = half_extent * (1.0 - abs_z / half_extent) if half_extent > 0.0 else 0.0
        if x_limit > 0.0:
            mesh.surface_add_vertex(Vector3(-x_limit, 0.01, world_z))
            mesh.surface_add_vertex(Vector3(x_limit, 0.01, world_z))

    if half_extent > 0.0:
        var tip_left := Vector3(-half_extent, 0.01, 0.0)
        var tip_top := Vector3(0.0, 0.01, -half_extent)
        var tip_right := Vector3(half_extent, 0.01, 0.0)
        var tip_bottom := Vector3(0.0, 0.01, half_extent)
        mesh.surface_add_vertex(tip_left)
        mesh.surface_add_vertex(tip_top)
        mesh.surface_add_vertex(tip_top)
        mesh.surface_add_vertex(tip_right)
        mesh.surface_add_vertex(tip_right)
        mesh.surface_add_vertex(tip_bottom)
        mesh.surface_add_vertex(tip_bottom)
        mesh.surface_add_vertex(tip_left)

    mesh.surface_end()
    _grid_overlay.mesh = mesh
    _grid_overlay.material_override = material


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
        _update_cell_highlight()


func _update_cell_highlight() -> void:
    if not _cell_highlight:
        return
    var cell_data: Dictionary = TerrainSystem.get_cell(_hovered_cell)
    if cell_data.is_empty():
        _cell_highlight.visible = false
        return
    _cell_highlight.visible = true
    var mesh := ImmediateMesh.new()
    var grid_half: float = float(TerrainSystem.grid_cells) * Pathfinder.CELL_SIZE * 0.5
    var world_pos := Pathfinder.cell_to_world(_hovered_cell) - Vector3(grid_half, 0, grid_half)
    var height: int = cell_data.get("max_height", cell_data.get("height", 0))
    world_pos.y = float(height) * TerrainSystem.HEIGHT_STEP + 0.02
    var half: float = Pathfinder.CELL_SIZE * 0.475
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _highlight_quad_mat)
    var y: float = world_pos.y
    var x0: float = world_pos.x - half
    var x1: float = world_pos.x + half
    var z0: float = world_pos.z - half
    var z1: float = world_pos.z + half
    mesh.surface_add_vertex(Vector3(x0, y, z0))
    mesh.surface_add_vertex(Vector3(x1, y, z0))
    mesh.surface_add_vertex(Vector3(x1, y, z1))
    mesh.surface_add_vertex(Vector3(x0, y, z0))
    mesh.surface_add_vertex(Vector3(x1, y, z1))
    mesh.surface_add_vertex(Vector3(x0, y, z1))
    mesh.surface_end()
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _highlight_line_mat)
    var drop: float = 2.0
    var lw: float = 0.04
    var corners: Array[Vector3] = [
        Vector3(x0, y, z0),
        Vector3(x1, y, z0),
        Vector3(x1, y, z1),
        Vector3(x0, y, z1),
    ]
    for c in corners:
        var cx: float = c.x
        var cy: float = c.y
        var cz: float = c.z
        var by: float = cy - drop
        mesh.surface_add_vertex(Vector3(cx - lw, cy, cz))
        mesh.surface_add_vertex(Vector3(cx + lw, cy, cz))
        mesh.surface_add_vertex(Vector3(cx + lw, by, cz))
        mesh.surface_add_vertex(Vector3(cx - lw, cy, cz))
        mesh.surface_add_vertex(Vector3(cx + lw, by, cz))
        mesh.surface_add_vertex(Vector3(cx - lw, by, cz))
        mesh.surface_add_vertex(Vector3(cx, cy, cz - lw))
        mesh.surface_add_vertex(Vector3(cx, cy, cz + lw))
        mesh.surface_add_vertex(Vector3(cx, by, cz + lw))
        mesh.surface_add_vertex(Vector3(cx, cy, cz - lw))
        mesh.surface_add_vertex(Vector3(cx, by, cz + lw))
        mesh.surface_add_vertex(Vector3(cx, by, cz - lw))
    mesh.surface_end()
    _cell_highlight.mesh = mesh
    _cell_highlight.material_override = null
    _cell_highlight.position = Vector3.ZERO
    _update_height_label()


func _update_height_label() -> void:
    if not _height_label:
        return
    var cell_data: Dictionary = TerrainSystem.get_cell(_hovered_cell)
    var h: int = cell_data.get("height", 0)
    _height_label.text = "Height: %d" % h


func _cell_world_pos(cell: Vector2i) -> Vector3:
    var grid_half: float = float(TerrainSystem.grid_cells) * Pathfinder.CELL_SIZE * 0.5
    var pos := Pathfinder.cell_to_world(cell) - Vector3(grid_half, 0.0, grid_half)
    var cell_data: Dictionary = TerrainSystem.get_cell(cell)
    if not cell_data.is_empty():
        var h: int = cell_data.get("max_height", cell_data.get("height", 0))
        pos.y = float(h) * TerrainSystem.HEIGHT_STEP
    return pos


func get_hovered_cell() -> Vector2i:
    return _hovered_cell


func _on_save_pressed() -> void:
    _save_dialog.popup_centered(Vector2i(400, 300))


func _on_load_pressed() -> void:
    _load_dialog.popup_centered(Vector2i(400, 300))


func _on_save_file_selected(path: String) -> void:
    var entities_array: Array[Dictionary] = []
    for cell_key in _painted_entities:
        var entry: Dictionary = _painted_entities[cell_key]
        var data: Dictionary = entry.get("data", {})
        var entity_entry: Dictionary = {
            "id": data.get("id", ""),
            "cell": cell_key,
        }
        for key in OVERRIDE_KEYS:
            if data.has(key):
                entity_entry[key] = data[key]
        entities_array.append(entity_entry)
    if not entities_array.is_empty():
        TerrainSystem.export_to_json(path, {"entities": entities_array})


func _on_load_file_selected(path: String) -> void:
    for key in _painted_entities:
        var node := _painted_entities[key].get("node") as Node3D
        if is_instance_valid(node):
            node.queue_free()
    _painted_entities.clear()
    var loaded := MapLoader.load_map_into(path, self)
    for entry in loaded:
        var key: String = entry.get("key", "")
        if not key.is_empty():
            _painted_entities[key] = {"node": entry.get("node"), "data": entry.get("data")}


func _on_height_changed(cell: Vector2i, new_height: int) -> void:
    if cell == _hovered_cell:
        _update_cell_highlight()
    var key := str(cell.x) + "," + str(cell.y)
    var entry := _painted_entities.get(key, {}) as Dictionary
    var node := entry.get("node") as Node3D
    if is_instance_valid(node):
        node.position.y = float(new_height) * TerrainSystem.HEIGHT_STEP
        var tib := node.get_node_or_null("TiberiumComponent") as TiberiumComponent
        if tib:
            tib.update_slope_positions()


func _on_terrain_cell_changed(key: String, data: Dictionary) -> void:
    var entry := _painted_entities.get(key, {}) as Dictionary
    var node := entry.get("node") as Node3D
    if not is_instance_valid(node):
        return
    var h: int = data.get("max_height", data.get("height", 0))
    node.position.y = float(h) * TerrainSystem.HEIGHT_STEP
    var tib := node.get_node_or_null("TiberiumComponent") as TiberiumComponent
    if tib:
        tib.update_slope_positions()
