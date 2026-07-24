extends SubViewportContainer

@export var minimap_size: Vector2i = Vector2i(200, 200)
@export var terrain_color: Color = Color(0.3, 0.6, 0.3)
@export var slope_color: Color = Color(0.5, 0.4, 0.3)
@export var water_color: Color = Color(0.2, 0.4, 0.8)

var _sub_viewport: SubViewport
var _camera: Camera3D
var _terrain_mesh: MeshInstance3D
var _needs_rebuild: bool = false


func _ready() -> void:
    _setup_container()
    _setup_viewport()
    _setup_camera()
    _setup_terrain_visualization()
    TerrainSystem.cell_changed.connect(_on_cell_changed)


func _process(_delta: float) -> void:
    if _needs_rebuild:
        _needs_rebuild = false
        _update_visualization()


func _setup_container() -> void:
    custom_minimum_size = minimap_size
    size = minimap_size
    stretch = false
    size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _setup_viewport() -> void:
    _sub_viewport = SubViewport.new()
    _sub_viewport.name = "MinimapViewport"
    _sub_viewport.size = minimap_size
    _sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    _sub_viewport.own_world_3d = true
    add_child(_sub_viewport)


func _setup_camera() -> void:
    _camera = Camera3D.new()
    _camera.name = "MinimapCamera"
    _camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    _camera.rotation_degrees = Vector3(-90, 45, 0)
    _camera.position = Vector3(0, 100, 0)
    _camera.size = 50.0
    _sub_viewport.add_child(_camera)


func _setup_terrain_visualization() -> void:
    _terrain_mesh = MeshInstance3D.new()
    _terrain_mesh.name = "TerrainVisualization"
    _sub_viewport.add_child(_terrain_mesh)
    _update_visualization()


func _update_visualization() -> void:
    var cells: Dictionary = TerrainSystem.get_all_cells()
    if cells.is_empty():
        return
    var mesh := ImmediateMesh.new()
    var terrain_material := ORMMaterial3D.new()
    terrain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, terrain_material)
    for key in cells:
        var parts: PackedStringArray = key.split(",")
        if parts.size() != 2:
            continue
        var cell := Vector2i(int(parts[0]), int(parts[1]))
        var data: Dictionary = cells[key]
        var height: int = data.get("height", 0)
        var terrain_type: String = data.get("type", "clear")
        var color := terrain_color
        if terrain_type == "slope":
            color = slope_color
        elif terrain_type == "water":
            color = water_color
        terrain_material.albedo_color = color
        var grid_half: float = TerrainSystem.get_grid_half_size()
        var world_pos := CellUtil.cell_to_world(cell) - Vector3(grid_half, 0, grid_half)
        var half_size := CellUtil.CELL_SIZE * 0.5
        var y: float = float(height) * TerrainSystem.HEIGHT_STEP + 0.1
        mesh.surface_add_vertex(Vector3(world_pos.x - half_size, y, world_pos.z - half_size))
        mesh.surface_add_vertex(Vector3(world_pos.x + half_size, y, world_pos.z - half_size))
        mesh.surface_add_vertex(Vector3(world_pos.x + half_size, y, world_pos.z + half_size))
        mesh.surface_add_vertex(Vector3(world_pos.x - half_size, y, world_pos.z - half_size))
        mesh.surface_add_vertex(Vector3(world_pos.x + half_size, y, world_pos.z + half_size))
        mesh.surface_add_vertex(Vector3(world_pos.x - half_size, y, world_pos.z + half_size))
    mesh.surface_end()
    _terrain_mesh.mesh = mesh


func _on_cell_changed(_cell_key: String, _cell_data: Dictionary) -> void:
    _needs_rebuild = true


func get_clicked_world_pos(click_pos: Vector2) -> Vector3:
    var viewport_click: Vector2 = click_pos * Vector2(size) / Vector2(minimap_size)
    var ray_origin := _camera.project_ray_origin(viewport_click)
    var ray_direction := _camera.project_ray_normal(viewport_click)
    var plane := Plane(Vector3.UP, 0.0)
    var intersection: Variant = plane.intersects_ray(ray_origin, ray_direction)
    return intersection if intersection else Vector3.ZERO
