@tool
extends Node3D

## Gameplay API — cell units
var grid_cells: Vector2i = Vector2i(64, 64)

## Visible bounds offset (cell units)
@export var visible_offset_x: int = 10:
    set = _set_visible_offset_x
@export var visible_offset_z: int = 8:
    set = _set_visible_offset_z

## Visual properties
@export var line_color: Color = Color.RED:
    set = _set_line_color
@export var map_line_width: float = 8.0:
    set = _set_map_line_width
@export var visible_line_width: float = 8.0:
    set = _set_visible_line_width
@export var visible_bounds_color: Color = Color.BLUE:
    set = _set_visible_bounds_color

## Visibility toggle
var show_bounds: bool = false:
    set = _set_show_bounds

## Camera node whose position will be clamped to visible bounds every frame.
@export var camera_pivot: Node3D

var map_bounds_mesh_instance: MeshInstance3D
var visible_bounds_mesh_instance: MeshInstance3D
var immediate_map_mesh: ImmediateMesh
var immediate_visible_mesh: ImmediateMesh


func _ready():
    create_bounds_nodes()
    create_bounds_edges()
    map_bounds_mesh_instance.visible = show_bounds
    visible_bounds_mesh_instance.visible = show_bounds
    if not Engine.is_editor_hint():
        var ts = get_node_or_null("/root/TerrainSystem")
        if ts:
            grid_cells = ts.grid_cells
            ts.grid_initialized.connect(_on_grid_initialized)


func _process(_delta):
    clamp_camera_position()


func _on_grid_initialized() -> void:
    var ts = get_node_or_null("/root/TerrainSystem")
    if ts:
        grid_cells = ts.grid_cells
    create_bounds_edges()


# ========================================
# Setters
# ========================================


func _set_visible_offset_x(value: int) -> void:
    visible_offset_x = maxi(value, 0)
    if is_inside_tree():
        create_bounds_edges()


func _set_visible_offset_z(value: int) -> void:
    visible_offset_z = maxi(value, 0)
    if is_inside_tree():
        create_bounds_edges()


func _set_line_color(value: Color) -> void:
    line_color = value
    if is_inside_tree():
        create_bounds_edges()


func _set_map_line_width(value: float) -> void:
    map_line_width = value
    if is_inside_tree():
        create_bounds_edges()


func _set_visible_line_width(value: float) -> void:
    visible_line_width = value
    if is_inside_tree():
        create_bounds_edges()


func _set_visible_bounds_color(value: Color) -> void:
    visible_bounds_color = value
    if is_inside_tree():
        create_bounds_edges()


func _set_show_bounds(value: bool) -> void:
    show_bounds = value
    if map_bounds_mesh_instance:
        map_bounds_mesh_instance.visible = show_bounds
    if visible_bounds_mesh_instance:
        visible_bounds_mesh_instance.visible = show_bounds


# ========================================
# Gameplay API (cell units)
# ========================================


func get_map_half_extents() -> Vector2:
    return Vector2(float(grid_cells.x) / 2.0, float(grid_cells.y) / 2.0)


func get_play_area_extents() -> Vector2:
    var map_extents := get_map_half_extents()
    var offset: float = float(mini(visible_offset_x, visible_offset_z))
    return Vector2(map_extents.x - offset, map_extents.y - offset)


func is_in_map_bounds(cell: Vector2i) -> bool:
    var extents := get_map_half_extents()
    if extents.x <= 0.0 or extents.y <= 0.0:
        return false
    var cx := absf(float(cell.x) + 0.5)
    var cz := absf(float(cell.y) + 0.5)
    return cx / extents.x + cz / extents.y <= 1.0


func is_in_play_area(cell: Vector2i) -> bool:
    var extents := get_play_area_extents()
    if extents.x <= 0.0 or extents.y <= 0.0:
        return false
    var cx := absf(float(cell.x) + 0.5)
    var cz := absf(float(cell.y) + 0.5)
    return cx / extents.x + cz / extents.y <= 1.0


func get_play_area_margin_extents() -> Vector2:
    var extents := get_play_area_extents()
    return Vector2(extents.x - 1.0, extents.y - 1.0)


func is_in_play_area_with_margin(cell: Vector2i) -> bool:
    var extents := get_play_area_margin_extents()
    if extents.x <= 0.0 or extents.y <= 0.0:
        return false
    var cx := absf(float(cell.x) + 0.5)
    var cz := absf(float(cell.y) + 0.5)
    return cx / extents.x + cz / extents.y <= 1.0


# ========================================
# Camera clamping (outer bounds)
# ========================================


func clamp_camera_position():
    if not camera_pivot:
        return

    var camera = camera_pivot.get_node("Camera3D") as Camera3D
    if not camera:
        return

    var extents := get_map_half_extents()
    var half_x: float = extents.x * CellUtil.CELL_SIZE
    var half_z: float = extents.y * CellUtil.CELL_SIZE
    var new_pos = camera.global_position
    new_pos.x = clamp(new_pos.x, -half_x, half_x)
    new_pos.z = clamp(new_pos.z, -half_z, half_z)

    if camera.global_position != new_pos:
        camera.global_position = new_pos


func get_bounds_rect() -> Rect2:
    var extents := get_play_area_extents()
    var half_x: float = extents.x * CellUtil.CELL_SIZE
    var half_z: float = extents.y * CellUtil.CELL_SIZE
    return Rect2(-half_x, -half_z, half_x * 2.0, half_z * 2.0)


# ========================================
# Mesh creation
# ========================================


func create_bounds_nodes():
    for child in get_children():
        if child.name == "MapSize" or child.name == "VisibleBounds":
            remove_child(child)

    map_bounds_mesh_instance = MeshInstance3D.new()
    map_bounds_mesh_instance.name = "MapSize"
    add_child(map_bounds_mesh_instance)

    visible_bounds_mesh_instance = MeshInstance3D.new()
    visible_bounds_mesh_instance.name = "VisibleBounds"
    add_child(visible_bounds_mesh_instance)


func create_bounds_edges():
    var map_visual := Vector2(get_map_half_extents().x - 1.0, get_map_half_extents().y - 1.0)
    var half_grid_x: float = map_visual.x * CellUtil.CELL_SIZE
    var half_grid_z: float = map_visual.y * CellUtil.CELL_SIZE
    var play_extents := get_play_area_extents()
    var half_visible_x: float = play_extents.x * CellUtil.CELL_SIZE
    var half_visible_z: float = play_extents.y * CellUtil.CELL_SIZE

    immediate_map_mesh = ImmediateMesh.new()
    map_bounds_mesh_instance.mesh = immediate_map_mesh

    immediate_visible_mesh = ImmediateMesh.new()
    visible_bounds_mesh_instance.mesh = immediate_visible_mesh

    if not immediate_map_mesh or not immediate_visible_mesh:
        return

    # Outer bounds (red) — terrain-following mesh
    _draw_rotated_rect_mesh(immediate_map_mesh, Vector2(half_grid_x, half_grid_z), line_color)

    # Visible bounds (blue) — terrain-following mesh
    _draw_rotated_rect_mesh(
        immediate_visible_mesh, Vector2(half_visible_x, half_visible_z), visible_bounds_color
    )


func _draw_rotated_rect_mesh(mesh: ImmediateMesh, half_diag: Vector2, color: Color) -> void:
    var mat := ORMMaterial3D.new()
    mat.albedo_color = color
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.render_priority = 2
    mat.no_depth_test = true

    mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)

    var hw: float = half_diag.x
    var hh: float = half_diag.y
    var corners: Array[Vector3] = [
        Vector3(0.0, 0.0, -hh),
        Vector3(hw, 0.0, 0.0),
        Vector3(0.0, 0.0, hh),
        Vector3(-hw, 0.0, 0.0),
    ]

    for i in 4:
        var from: Vector3 = corners[i]
        var to: Vector3 = corners[(i + 1) % 4]
        var edge_len: float = from.distance_to(to)
        var steps: int = maxi(ceili(edge_len / CellUtil.CELL_SIZE), 1)
        for step in steps + 1:
            var t: float = float(step) / float(steps)
            var pos: Vector3 = from.lerp(to, t)
            var terrain_h: float = _sample_terrain_height(pos)
            mesh.surface_add_vertex(Vector3(pos.x, terrain_h + 0.02, pos.z))

    mesh.surface_end()


func _sample_terrain_height(world_pos: Vector3) -> float:
    if Engine.is_editor_hint():
        return 0.0
    var ts = get_node_or_null("/root/TerrainSystem")
    if ts:
        return ts.get_height_at_world_smooth(world_pos)
    return 0.0
