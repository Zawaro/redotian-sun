@tool
extends Node3D

## Gameplay API — cell units
var grid_cells: Vector2i = Vector2i(64, 64)

const DEFAULT_VISIBLE_BOUNDS_REDUCTION: Vector2i = Vector2i(10, 8)

## Inner (visible) bounds inset from the map edge, in cells.
@export var visible_offset_x: int = 5:
    set = _set_visible_offset_x
@export var visible_offset_z: int = 4:
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

var _syncing_visible_bounds: bool = false


func _ready() -> void:
    create_bounds_nodes()
    if not Engine.is_editor_hint():
        var ts: Node = get_node_or_null("/root/TerrainSystem")
        if ts:
            grid_cells = ts.grid_cells
            ts.grid_initialized.connect(_on_grid_initialized)
        if not camera_pivot:
            camera_pivot = _find_camera_pivot()
        if camera_pivot:
            _center_camera_on_diamond()
        call_deferred("_position_cloud_overlay")
    create_bounds_edges()
    map_bounds_mesh_instance.visible = show_bounds
    visible_bounds_mesh_instance.visible = show_bounds


func _on_grid_initialized() -> void:
    var ts: Node = get_node_or_null("/root/TerrainSystem")
    if ts:
        grid_cells = ts.grid_cells
    visible_bounds_size = Vector2i(
        maxi(grid_cells.x - visible_offset_x * 2, 1), maxi(grid_cells.y - visible_offset_z * 2, 1)
    )
    create_bounds_edges()
    if camera_pivot:
        _center_camera_on_diamond()
    call_deferred("_position_cloud_overlay")


func _find_camera_pivot() -> Node3D:
    var root: Window = get_tree().root
    for child in root.get_children():
        if child.get_node_or_null("Camera3D"):
            return child
    return null


func _center_camera_on_diamond() -> void:
    if not camera_pivot:
        return
    camera_pivot.global_position = Vector3(0.0, camera_pivot.global_position.y, 0.0)


## Restore visible-bounds insets from loaded map data (JSON v4), with a v3 fallback.
func apply_saved_bounds(data: Dictionary) -> void:
    var vbs: Variant = data.get("visible_bounds_size")
    if vbs is Array and vbs.size() == 2:
        # Lossless round-trip is guaranteed only for app-authored (even) sizes; a
        # hand-authored odd visible_bounds_size may re-quantize by 1 cell here.
        visible_offset_x = maxi((grid_cells.x - int(vbs[0])) / 2, 0)
        visible_offset_z = maxi((grid_cells.y - int(vbs[1])) / 2, 0)
        return
    # v3 fallback: no persisted bounds — use the standard default insets.
    visible_offset_x = 10
    visible_offset_z = 8


# ========================================
# Setters
# ========================================


func _set_visible_offset_x(value: int) -> void:
    visible_offset_x = maxi(value, 0)
    if _syncing_visible_bounds:
        return
    visible_bounds_size.x = maxi(grid_cells.x - visible_offset_x * 2, 1)
    if is_inside_tree():
        create_bounds_edges()


func _set_visible_offset_z(value: int) -> void:
    visible_offset_z = maxi(value, 0)
    if _syncing_visible_bounds:
        return
    visible_bounds_size.y = maxi(grid_cells.y - visible_offset_z * 2, 1)
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
    return Vector2i(
        maxi(grid_cells.x - DEFAULT_VISIBLE_BOUNDS_REDUCTION.x, 1),
        maxi(grid_cells.y - DEFAULT_VISIBLE_BOUNDS_REDUCTION.y, 1)
    )


func set_visible_bounds_size(value: Vector2i) -> void:
    var clamped_size: Vector2i = Vector2i(
        clampi(value.x, 1, grid_cells.x), clampi(value.y, 1, grid_cells.y)
    )
    _syncing_visible_bounds = true
    visible_offset_x = floori(float(grid_cells.x - clamped_size.x) * 0.5)
    visible_offset_z = floori(float(grid_cells.y - clamped_size.y) * 0.5)
    _syncing_visible_bounds = false
    visible_bounds_size = Vector2i(
        grid_cells.x - visible_offset_x * 2, grid_cells.y - visible_offset_z * 2
    )
    if is_inside_tree():
        create_bounds_edges()


# Uses the same half-open raster ownership as CellUtil.is_in_diamond.
func _in_play_diamond(cell: Vector2i, extra_inset: float) -> bool:
    var w: float = float(grid_cells.x)
    var h: float = float(grid_cells.y)
    if w <= 0.0 or h <= 0.0:
        return false
    var ox: float = float(visible_offset_x) + extra_inset
    var oz: float = float(visible_offset_z) + extra_inset
    var center: float = (w + h) * 0.5
    var cx: float = float(cell.x) + 0.5 - center
    var cz: float = float(cell.y) + 0.5 - center
    var sum_axis: float = cx + cz
    var difference_axis: float = cx - cz
    return (
        sum_axis >= -h + oz
        and sum_axis < h - oz
        and difference_axis >= -w + ox
        and difference_axis < w - ox
    )


# ========================================
# Camera bounds (map diamond)
# ========================================


# Clamp a world point into the red map diamond using centered constraints:
# a ∈ [-H, H], b ∈ [-W, W], a = ux+uz, b = ux-uz
func clamp_to_map_diamond(p: Vector3) -> Vector3:
    return _clamp_to_diamond(p, grid_cells)


func clamp_to_visible_diamond(p: Vector3) -> Vector3:
    var cells: Vector2 = _get_visible_draw_cells()
    return _clamp_to_diamond(p, Vector2i(int(cells.x), int(cells.y)))


func _clamp_to_diamond(p: Vector3, cells: Vector2i) -> Vector3:
    var cs: float = CellUtil.CELL_SIZE
    var w: float = float(cells.x)
    var h: float = float(cells.y)
    if w <= 0.0 or h <= 0.0:
        return p
    # Cell diamond uses half-open [-N, N). Clamp to these bounds.
    var ux: float = p.x / cs
    var uz: float = p.z / cs
    var a: float = clampf(ux + uz, -h, h)
    var b: float = clampf(ux - uz, -w, w)
    ux = (a + b) * 0.5
    uz = (a - b) * 0.5
    return Vector3(ux * cs, p.y, uz * cs)


func get_bounds_rect() -> Rect2:
    var half: float = float(grid_cells.x + grid_cells.y) * CellUtil.CELL_SIZE * 0.5
    return Rect2(-half, -half, half * 2.0, half * 2.0)


# ========================================
# Mesh creation
# ========================================


func create_bounds_nodes() -> void:
    for child in get_children():
        if child.name == "MapSize" or child.name == "VisibleBounds":
            remove_child(child)

    map_bounds_mesh_instance = MeshInstance3D.new()
    map_bounds_mesh_instance.name = "MapSize"
    add_child(map_bounds_mesh_instance)

    visible_bounds_mesh_instance = MeshInstance3D.new()
    visible_bounds_mesh_instance.name = "VisibleBounds"
    add_child(visible_bounds_mesh_instance)


func create_bounds_edges() -> void:
    immediate_map_mesh = ImmediateMesh.new()
    map_bounds_mesh_instance.mesh = immediate_map_mesh

    immediate_visible_mesh = ImmediateMesh.new()
    visible_bounds_mesh_instance.mesh = immediate_visible_mesh

    if not immediate_map_mesh or not immediate_visible_mesh:
        return

    # Red outer bounds: (W-0.5, H-0.5) — inside the cell diamond
    var outer_cells := Vector2(grid_cells.x - 0.5, grid_cells.y - 0.5)
    _draw_diamond_mesh(immediate_map_mesh, outer_cells, line_color)

    # Blue visible bounds: red shrunk by visible offset
    var play_cells := Vector2(
        grid_cells.x - visible_offset_x - 0.5, grid_cells.y - visible_offset_z - 0.5
    )
    _draw_diamond_mesh(immediate_visible_mesh, play_cells, visible_bounds_color)


func _get_visible_draw_cells() -> Vector2:
    return Vector2(
        maxi(grid_cells.x - visible_offset_x, 1), maxi(grid_cells.y - visible_offset_z, 1)
    )


func _position_cloud_overlay() -> void:
    var scene: Node = get_tree().current_scene
    if not is_instance_valid(scene):
        return
    var cloud_overlay: Node3D = scene.get_node_or_null("CloudShadowOverlay") as Node3D
    var camera: Camera3D = get_viewport().get_camera_3d()
    if not is_instance_valid(cloud_overlay) or not is_instance_valid(camera):
        return
    cloud_overlay.global_position.x = camera.global_position.x * 0.5
    cloud_overlay.global_position.z = camera.global_position.z * 0.5


func _draw_diamond_mesh(mesh: ImmediateMesh, cells: Vector2, color: Color) -> void:
    var mat: ORMMaterial3D = ORMMaterial3D.new()
    mat.albedo_color = color
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.render_priority = 2
    mat.no_depth_test = true

    mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)

    var vertices: Array[Vector3] = _compute_diamond_vertices(cells)
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


# Diamond vertices centered on the cell diamond.
# The cell diamond uses half-open [-N, N) intervals whose center is at -0.5
# in the sum/diff frame. Converting to world coords: offset = (-CS/2, 0, 0).
func _compute_diamond_vertices(cells: Vector2) -> Array[Vector3]:
    var w: float = cells.x
    var h: float = cells.y
    var cs: float = CellUtil.CELL_SIZE
    var long: float = (w + h) * cs * 0.5
    var small: float = (h - w) * cs * 0.5
    var offset_x: float = -cs * 0.5
    var north: Vector3 = Vector3(-small + offset_x, 0.0, -long)
    var east: Vector3 = Vector3(long + offset_x, 0.0, small)
    var south: Vector3 = Vector3(small + offset_x, 0.0, long)
    var west: Vector3 = Vector3(-long + offset_x, 0.0, -small)
    return [north, east, south, west]


func _sample_terrain_height(world_pos: Vector3) -> float:
    if Engine.is_editor_hint():
        return 0.0
    var ts: Node = get_node_or_null("/root/TerrainSystem")
    if ts:
        return ts.get_height_at_world_smooth(world_pos)
    return 0.0
