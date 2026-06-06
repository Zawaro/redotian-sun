@tool
extends Node3D

@export var map_size: Vector2 = Vector2(64.0, 64.0)
@export var visible_bounds_size: Vector2 = Vector2(54.0, 54.0)
@export var show_grid: bool = true

var grid_size: Vector2i:
    get: return Vector2i(ceili(map_size.x * sqrt(2)), ceili(map_size.y * sqrt(2)))

var _grid_overlay: MeshInstance3D
var _cell_highlight: MeshInstance3D
var _hovered_cell: Vector2i = Vector2i(-999, -999)
var _camera: Camera3D
var _height_painter: Node
var _height_label: Label
var _save_dialog: FileDialog
var _load_dialog: FileDialog
var _highlight_quad_mat: ORMMaterial3D
var _highlight_line_mat: ORMMaterial3D

func _ready() -> void:
    if Engine.is_editor_hint():
        return
    TerrainSystem.init_grid(ceili(map_size.x * sqrt(2)))
    _setup_camera()
    _setup_grid_overlay()
    _setup_height_painter()
    _height_painter.height_changed.connect(_on_height_changed)
    _prefill_terrain()
    _setup_ui()

func _exit_tree() -> void:
    if Engine.is_editor_hint():
        return
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
            var world_center := Pathfinder.cell_to_world(cell) - Vector3(center_world, 0, center_world)
            if half_extent > 0.0:
                if absf(world_center.x) / half_extent + absf(world_center.z) / half_extent >= 1.0:
                    continue
            if TerrainSystem.get_cell(cell).is_empty():
                TerrainSystem.compute_and_emit_cell(cell)

func _setup_ui() -> void:
    var ui := CanvasLayer.new()
    ui.name = "EditorUI"
    add_child(ui)
    var margin := MarginContainer.new()
    margin.name = "MarginContainer"
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 10)
    margin.add_theme_constant_override("margin_top", 10)
    ui.add_child(margin)
    var vbox := VBoxContainer.new()
    vbox.name = "VBoxContainer"
    vbox.add_theme_constant_override("separation", 5)
    margin.add_child(vbox)
    var save_btn := Button.new()
    save_btn.name = "SaveButton"
    save_btn.text = "Save"
    save_btn.pressed.connect(_on_save_pressed)
    vbox.add_child(save_btn)
    var load_btn := Button.new()
    load_btn.name = "LoadButton"
    load_btn.text = "Load"
    load_btn.pressed.connect(_on_load_pressed)
    vbox.add_child(load_btn)
    _height_label = Label.new()
    _height_label.name = "HeightLabel"
    _height_label.text = "Height: 0"
    vbox.add_child(_height_label)
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
        minimap.position = Vector2(10, 80)
        ui.add_child(minimap)

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
        Vector3(x0, y, z0), Vector3(x1, y, z0),
        Vector3(x1, y, z1), Vector3(x0, y, z1),
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

func _update_height_label() -> void:
    if not _height_label:
        return
    var cell_data: Dictionary = TerrainSystem.get_cell(_hovered_cell)
    var height: int = cell_data.get("height", 0)
    _height_label.text = "Height: %d" % height

func _on_save_pressed() -> void:
    _save_dialog.popup_centered(Vector2i(400, 300))

func _on_load_pressed() -> void:
    _load_dialog.popup_centered(Vector2i(400, 300))

func _on_save_file_selected(path: String) -> void:
    TerrainSystem.export_to_json(path)

func _on_load_file_selected(path: String) -> void:
    TerrainSystem.import_from_json(path)

func get_hovered_cell() -> Vector2i:
    return _hovered_cell

func _on_height_changed(cell: Vector2i, _new_height: int) -> void:
    if cell == _hovered_cell:
        _update_cell_highlight()
