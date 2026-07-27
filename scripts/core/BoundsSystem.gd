@tool
extends Node3D

## Gameplay API — cell units
var grid_cells: Vector2i = Vector2i(64, 64)

## Half-cell world-space nudge (-XZ) so the map diamond hugs the terrain tiles.
const MAP_OFFSET := Vector3(-CellUtil.CELL_SIZE * 0.5, 0.0, -CellUtil.CELL_SIZE * 0.5)
const DEFAULT_VISIBLE_BOUNDS_REDUCTION := Vector2i(10, 8)

## Inner (visible) bounds inset from the map edge, in cells.
@export var visible_offset_x: int = 0:
    set = _set_visible_offset_x
@export var visible_offset_z: int = 0:
    set = _set_visible_offset_z
var visible_bounds_size: Vector2i = Vector2i.ZERO

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

## Camera pivot used to center the camera when a map is initialized.
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
        if not camera_pivot:
            camera_pivot = _find_camera_pivot()
        if camera_pivot:
            _center_camera_on_diamond()
        call_deferred("_position_cloud_overlay")


func _on_grid_initialized() -> void:
    var ts = get_node_or_null("/root/TerrainSystem")
    if ts:
        grid_cells = ts.grid_cells
    if visible_bounds_size == Vector2i.ZERO:
        visible_bounds_size = get_default_visible_bounds_size()
    create_bounds_edges()
    if camera_pivot:
        _center_camera_on_diamond()
    call_deferred("_position_cloud_overlay")


func _find_camera_pivot() -> Node3D:
    var root := get_tree().root
    for child in root.get_children():
        if child.get_node_or_null("Camera3D"):
            return child
    return null


func _center_camera_on_diamond() -> void:
    if not camera_pivot:
        return
    var s: float = _get_map_center_coordinate()
    camera_pivot.global_position = Vector3(s, camera_pivot.global_position.y, s)


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


func is_in_map_bounds(cell: Vector2i) -> bool:
    return CellUtil.is_in_diamond(cell, grid_cells)


func is_in_play_area(cell: Vector2i) -> bool:
    return _in_play_diamond(cell, 0.0)


func is_in_play_area_with_margin(cell: Vector2i) -> bool:
    return _in_play_diamond(cell, 1.0)


func get_default_visible_bounds_size() -> Vector2i:
    return grid_cells - DEFAULT_VISIBLE_BOUNDS_REDUCTION


func set_visible_bounds_size(value: Vector2i) -> void:
    visible_bounds_size = Vector2i(
        clampi(value.x, 1, grid_cells.x), clampi(value.y, 1, grid_cells.y)
    )
    if is_inside_tree():
        create_bounds_edges()


# Centered inset of the map diamond: offset_x insets the side edges, offset_z the
# near/far edges. extra_inset shrinks uniformly by that many cells (the margin).
func _in_play_diamond(cell: Vector2i, extra_inset: float) -> bool:
    var w := float(grid_cells.x)
    var h := float(grid_cells.y)
    if w <= 0.0 or h <= 0.0:
        return false
    var ox := float(visible_offset_x) + extra_inset
    var oz := float(visible_offset_z) + extra_inset
    var a := float(cell.x) + float(cell.y) + 1.0  # (cx+0.5)+(cz+0.5)
    var b := float(cell.x) - float(cell.y)  # (cx+0.5)-(cz+0.5)
    return a >= w + oz and a <= w + 2.0 * h - oz and b <= w - ox and b >= -w + ox


# ========================================
# Camera bounds (map diamond)
# ========================================


# Clamp a world point into the red map diamond by clamping in its rotated
# (sum/diff) axes — the region a∈[W,W+2H], b∈[-W,W] is exactly the diamond.
func clamp_to_map_diamond(p: Vector3) -> Vector3:
    return _clamp_to_diamond(p, grid_cells, MAP_OFFSET)


func clamp_to_visible_diamond(p: Vector3) -> Vector3:
    var cells := _get_visible_draw_cells()
    return _clamp_to_diamond(p, cells, _get_visible_draw_offset(cells))


func _clamp_to_diamond(p: Vector3, cells: Vector2i, translate: Vector3) -> Vector3:
    var cs := CellUtil.CELL_SIZE
    var w := float(cells.x)
    var h := float(cells.y)
    if w <= 0.0 or h <= 0.0:
        return p
    var ux := (p.x - translate.x) / cs - 1.0
    var uz := (p.z - translate.z) / cs - 1.0
    var a := clampf(ux + uz, w, w + 2.0 * h)
    var b := clampf(ux - uz, -w, w)
    ux = (a + b) * 0.5
    uz = (a - b) * 0.5
    return Vector3((ux + 1.0) * cs + translate.x, p.y, (uz + 1.0) * cs + translate.z)


func get_bounds_rect() -> Rect2:
    var total: float = float(grid_cells.x + grid_cells.y) * CellUtil.CELL_SIZE
    return Rect2(0.0, 0.0, total, total)


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
    immediate_map_mesh = ImmediateMesh.new()
    map_bounds_mesh_instance.mesh = immediate_map_mesh

    immediate_visible_mesh = ImmediateMesh.new()
    visible_bounds_mesh_instance.mesh = immediate_visible_mesh

    if not immediate_map_mesh or not immediate_visible_mesh:
        return

    _draw_diamond_mesh(immediate_map_mesh, grid_cells, MAP_OFFSET, line_color)

    # The displayed size is reduced by 10×8 cells in total: 5×4 cells at each opposing edge.
    var play_cells := _get_visible_draw_cells()
    var play_offset := _get_visible_draw_offset(play_cells)
    _draw_diamond_mesh(immediate_visible_mesh, play_cells, play_offset, visible_bounds_color)


func _get_visible_draw_cells() -> Vector2i:
    var target_size := visible_bounds_size
    if target_size == Vector2i.ZERO:
        target_size = get_default_visible_bounds_size()
    var edge_inset := Vector2i(
        floori(float(grid_cells.x - target_size.x) * 0.5),
        floori(float(grid_cells.y - target_size.y) * 0.5)
    )
    return grid_cells - edge_inset


func _get_visible_draw_offset(cells: Vector2i) -> Vector3:
    var total_inset: int = grid_cells.x - cells.x + grid_cells.y - cells.y
    var recenter: float = float(total_inset) * CellUtil.CELL_SIZE * 0.5
    return MAP_OFFSET + Vector3(recenter, 0.0, recenter)


func _get_map_center_coordinate() -> float:
    var map_extent: float = float(grid_cells.x + grid_cells.y) * CellUtil.CELL_SIZE * 0.5
    return map_extent + CellUtil.CELL_SIZE + MAP_OFFSET.x


func _position_cloud_overlay() -> void:
    var scene: Node = get_tree().current_scene
    if not is_instance_valid(scene):
        return
    var cloud_overlay: Node3D = scene.get_node_or_null("CloudShadowOverlay") as Node3D
    var camera: Camera3D = get_viewport().get_camera_3d()
    if not is_instance_valid(cloud_overlay) or not is_instance_valid(camera):
        return
    var map_center: float = _get_map_center_coordinate()
    cloud_overlay.global_position.x = (map_center + camera.global_position.x) * 0.5
    cloud_overlay.global_position.z = (map_center + camera.global_position.z) * 0.5


func _draw_diamond_mesh(
    mesh: ImmediateMesh, cells: Vector2i, translate: Vector3, color: Color
) -> void:
    var mat := ORMMaterial3D.new()
    mat.albedo_color = color
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.render_priority = 2
    mat.no_depth_test = true

    mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)

    var vertices := _compute_diamond_vertices(cells, translate)
    var count: int = vertices.size()

    for i in count:
        var from: Vector3 = vertices[i]
        var to: Vector3 = vertices[(i + 1) % count]
        var edge_len: float = from.distance_to(to)
        var steps: int = maxi(ceili(edge_len / CellUtil.CELL_SIZE), 1)
        for step in steps + 1:
            var t: float = float(step) / float(steps)
            var pos: Vector3 = from.lerp(to, t)
            var terrain_h: float = _sample_terrain_height(pos)
            mesh.surface_add_vertex(Vector3(pos.x, terrain_h + 0.02, pos.z))

    mesh.surface_end()


func _compute_diamond_vertices(cells: Vector2i, translate: Vector3) -> Array[Vector3]:
    var w: float = float(cells.x)
    var h: float = float(cells.y)
    var cs: float = CellUtil.CELL_SIZE
    var vertices: Array[Vector3] = []
    # Diamond inscribed in (W+H)*CS square, translated by +cs into the world frame
    # (CellUtil's 1-cell origin shift) plus `translate` so the outline hugs the tiles.
    # Clockwise order: top → right → bottom → left
    vertices.append(Vector3(w * cs + cs, 0.0, cs) + translate)
    vertices.append(Vector3((w + h) * cs + cs, 0.0, h * cs + cs) + translate)
    vertices.append(Vector3(h * cs + cs, 0.0, (w + h) * cs + cs) + translate)
    vertices.append(Vector3(cs, 0.0, w * cs + cs) + translate)
    return vertices


func _sample_terrain_height(world_pos: Vector3) -> float:
    if Engine.is_editor_hint():
        return 0.0
    var ts = get_node_or_null("/root/TerrainSystem")
    if ts:
        return ts.get_height_at_world_smooth(world_pos)
    return 0.0
