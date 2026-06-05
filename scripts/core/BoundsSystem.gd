@tool
class_name BoundsSystem extends Node3D

@export var map_size: Vector2 = Vector2(512.0, 512.0): set = _set_map_size
@export var visible_bounds_size: Vector2 = Vector2(512.0, 512.0): set = _set_visible_bounds_size
@export var line_color: Color = Color.RED: set = _set_line_color
@export var map_line_width: float = 8.0: set = _set_map_line_width
@export var visible_line_width: float = 8.0: set = _set_visible_line_width
@export var visible_bounds_color: Color = Color.BLUE: set = _set_visible_bounds_color

var map_bounds_mesh_instance: MeshInstance3D
var visible_bounds_mesh_instance: MeshInstance3D
var immediate_map_mesh: ImmediateMesh
var immediate_visible_mesh: ImmediateMesh

func _ready():
    create_bounds_nodes()
    create_bounds_edges()

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
    
    var camera_pivot = get_node_or_null("../MouseHandler/camera_pivot")
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
    return Rect2(-half_map_x, -half_map_y, map_size.x * GODOT_CELL_SCALE, map_size.y * GODOT_CELL_SCALE)

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
    var GODOT_CELL_SCALE = 2.0
    
    # Use both X and Y dimensions for bounds
    var half_map_x = map_size.x * GODOT_CELL_SCALE / 2.0
    var half_map_y = map_size.y * GODOT_CELL_SCALE / 2.0
    var half_visible_x = visible_bounds_size.x * GODOT_CELL_SCALE / 2.0
    var half_visible_y = visible_bounds_size.y * GODOT_CELL_SCALE / 2.0
    
    # Recreate meshes with fresh instances (this clears old data)
    immediate_map_mesh = ImmediateMesh.new()
    map_bounds_mesh_instance.mesh = immediate_map_mesh
    
    immediate_visible_mesh = ImmediateMesh.new()
    visible_bounds_mesh_instance.mesh = immediate_visible_mesh
    
    if not immediate_map_mesh or not immediate_visible_mesh:
        return
    
    # Create map bounds edges (outer) - RED
    if immediate_map_mesh:
        var map_material = ORMMaterial3D.new()
        map_material.albedo_color = line_color
        map_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        map_material.render_priority = 2
        
        immediate_map_mesh.surface_begin(Mesh.PRIMITIVE_LINES, map_material)
        
        # Draw rectangle edges using both x and y dimensions
        var min_x = -half_map_x
        var max_x = half_map_x
        var min_z = -half_map_y  # Y dimension becomes Z in world space
        var max_z = half_map_y
        
        immediate_map_mesh.surface_add_vertex(Vector3(min_x, 0.02, min_z))
        immediate_map_mesh.surface_add_vertex(Vector3(max_x, 0.02, min_z))  # Top edge
        
        immediate_map_mesh.surface_add_vertex(Vector3(min_x, 0.02, max_z))
        immediate_map_mesh.surface_add_vertex(Vector3(max_x, 0.02, max_z))  # Bottom edge
        
        immediate_map_mesh.surface_add_vertex(Vector3(min_x, 0.02, min_z))
        immediate_map_mesh.surface_add_vertex(Vector3(min_x, 0.02, max_z))  # Left edge
        
        immediate_map_mesh.surface_add_vertex(Vector3(max_x, 0.02, min_z))
        immediate_map_mesh.surface_add_vertex(Vector3(max_x, 0.02, max_z))  # Right edge
        
        immediate_map_mesh.surface_end()
    
    # Create visible bounds edges (inner) - BLUE
    if immediate_visible_mesh:
        var visible_material = ORMMaterial3D.new()
        visible_material.albedo_color = visible_bounds_color
        visible_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        visible_material.render_priority = 2
        
        immediate_visible_mesh.surface_begin(Mesh.PRIMITIVE_LINES, visible_material)
        
        # Draw rectangle edges using both x and y dimensions
        var min_x_vis = -half_visible_x
        var max_x_vis = half_visible_x
        var min_z_vis = -half_visible_y  # Y dimension becomes Z in world space
        var max_z_vis = half_visible_y
        
        immediate_visible_mesh.surface_add_vertex(Vector3(min_x_vis, 0.02, min_z_vis))
        immediate_visible_mesh.surface_add_vertex(Vector3(max_x_vis, 0.02, min_z_vis))  # Top edge
        
        immediate_visible_mesh.surface_add_vertex(Vector3(min_x_vis, 0.02, max_z_vis))
        immediate_visible_mesh.surface_add_vertex(Vector3(max_x_vis, 0.02, max_z_vis))  # Bottom edge
        
        immediate_visible_mesh.surface_add_vertex(Vector3(min_x_vis, 0.02, min_z_vis))
        immediate_visible_mesh.surface_add_vertex(Vector3(min_x_vis, 0.02, max_z_vis))  # Left edge
        
        immediate_visible_mesh.surface_add_vertex(Vector3(max_x_vis, 0.02, min_z_vis))
        immediate_visible_mesh.surface_add_vertex(Vector3(max_x_vis, 0.02, max_z_vis))  # Right edge
        
        immediate_visible_mesh.surface_end()
    
    # Rotate both meshes 45 degrees around Y axis (set rotation instead of accumulate)
    map_bounds_mesh_instance.rotation.y = deg_to_rad(45.0)
    visible_bounds_mesh_instance.rotation.y = deg_to_rad(45.0)
