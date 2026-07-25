@tool
class_name BoundsSystem extends Node3D

@export_group("Map Bounds")
@export var map_size: Vector2 = Vector2(512.0, 512.0):
    set = _set_map_size
@export var visible_bounds_size: Vector2 = Vector2(512.0, 512.0):
    set = _set_visible_bounds_size
@export var line_color: Color = Color.RED:
    set = _set_line_color
@export var map_line_width: float = 8.0:
    set = _set_map_line_width
@export var visible_line_width: float = 8.0:
    set = _set_visible_line_width
@export var visible_bounds_color: Color = Color.BLUE:
    set = _set_visible_bounds_color
## Camera node whose position will be clamped to map bounds every frame.
## Leave null to disable clamping (e.g. in editor scenes or scenes with
## orthographic cameras whose default position is outside the map).
@export var camera_pivot: Node3D

var map_bounds_mesh_instance: MeshInstance3D
var visible_bounds_mesh_instance: MeshInstance3D
var immediate_map_mesh: ImmediateMesh
var immediate_visible_mesh: ImmediateMesh


func _ready():
    create_bounds_nodes()
    create_bounds_edges()
    TerrainSystem.grid_initialized.connect(create_bounds_edges)


func _process(_delta):
    clamp_camera_position()


func _set_map_size(value: Vector2) -> void:
    map_size = value
    if is_inside_tree():
        create_bounds_edges()


func _set_visible_bounds_size(value: Vector2) -> void:
    visible_bounds_size = value
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


func clamp_camera_position():
    var GODOT_CELL_SCALE = 2.0
    var half_map = map_size.x * GODOT_CELL_SCALE / 2.0

    if not camera_pivot:
        return

    var camera = camera_pivot.get_node("Camera3D") as Camera3D
    if not camera:
        return

    var new_pos = camera.global_position
    new_pos.x = clamp(new_pos.x, -half_map, half_map)
    new_pos.z = clamp(new_pos.z, -half_map, half_map)

    if camera.global_position != new_pos:
        camera.global_position = new_pos


func get_bounds_rect() -> Rect2:
    var GODOT_CELL_SCALE = 2.0
    var half_map_x = map_size.x * GODOT_CELL_SCALE / 2.0
    var half_map_y = map_size.y * GODOT_CELL_SCALE / 2.0
    return Rect2(
        -half_map_x, -half_map_y, map_size.x * GODOT_CELL_SCALE, map_size.y * GODOT_CELL_SCALE
    )


func create_bounds_nodes():
    # Remove existing bounds nodes if any
    for child in get_children():
        if child.name == "MapSize" or child.name == "VisibleBounds":
            remove_child(child)

    # Create fresh mesh instances
    map_bounds_mesh_instance = MeshInstance3D.new()
    map_bounds_mesh_instance.name = "MapSize"
    add_child(map_bounds_mesh_instance)

    visible_bounds_mesh_instance = MeshInstance3D.new()
    visible_bounds_mesh_instance.name = "VisibleBounds"
    add_child(visible_bounds_mesh_instance)


func create_bounds_edges():
    # Both diamonds computed from actual grid
    var half_grid: float = float(TerrainSystem.grid_cells) * CellUtil.CELL_SIZE / 2.0
    var half_visible: float = float(TerrainSystem.grid_cells - 4) * CellUtil.CELL_SIZE / 2.0

    # Recreate meshes with fresh instances (this clears old data)
    immediate_map_mesh = ImmediateMesh.new()
    map_bounds_mesh_instance.mesh = immediate_map_mesh

    immediate_visible_mesh = ImmediateMesh.new()
    visible_bounds_mesh_instance.mesh = immediate_visible_mesh

    if not immediate_map_mesh or not immediate_visible_mesh:
        return

    # Create map bounds edges (outer) - RED — diamond drawn directly in world space
    if immediate_map_mesh:
        var map_material = ORMMaterial3D.new()
        map_material.albedo_color = line_color
        map_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        map_material.render_priority = 2

        immediate_map_mesh.surface_begin(Mesh.PRIMITIVE_LINES, map_material)

        var d: float = half_grid
        var top := Vector3(0.0, 0.02, -d)
        var right := Vector3(d, 0.02, 0.0)
        var bottom := Vector3(0.0, 0.02, d)
        var left := Vector3(-d, 0.02, 0.0)

        immediate_map_mesh.surface_add_vertex(top)
        immediate_map_mesh.surface_add_vertex(right)
        immediate_map_mesh.surface_add_vertex(right)
        immediate_map_mesh.surface_add_vertex(bottom)
        immediate_map_mesh.surface_add_vertex(bottom)
        immediate_map_mesh.surface_add_vertex(left)
        immediate_map_mesh.surface_add_vertex(left)
        immediate_map_mesh.surface_add_vertex(top)

        immediate_map_mesh.surface_end()

    # Create visible bounds edges (inner) - BLUE — diamond drawn directly in world space
    if immediate_visible_mesh:
        var visible_material = ORMMaterial3D.new()
        visible_material.albedo_color = visible_bounds_color
        visible_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        visible_material.render_priority = 2

        immediate_visible_mesh.surface_begin(Mesh.PRIMITIVE_LINES, visible_material)

        var vd: float = half_visible
        var vtop := Vector3(0.0, 0.02, -vd)
        var vright := Vector3(vd, 0.02, 0.0)
        var vbottom := Vector3(0.0, 0.02, vd)
        var vleft := Vector3(-vd, 0.02, 0.0)

        immediate_visible_mesh.surface_add_vertex(vtop)
        immediate_visible_mesh.surface_add_vertex(vright)
        immediate_visible_mesh.surface_add_vertex(vright)
        immediate_visible_mesh.surface_add_vertex(vbottom)
        immediate_visible_mesh.surface_add_vertex(vbottom)
        immediate_visible_mesh.surface_add_vertex(vleft)
        immediate_visible_mesh.surface_add_vertex(vleft)
        immediate_visible_mesh.surface_add_vertex(vtop)

        immediate_visible_mesh.surface_end()
