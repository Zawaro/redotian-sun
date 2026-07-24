extends Node

## Pathfinding overlay
@export var enabled: bool = true

## Overlay toggles
@export var show_spatial_hash: bool = false
@export var show_entity_bounds: bool = false
@export var show_health_bars: bool = false
@export var show_entity_ids: bool = false
@export var show_occupied_cells: bool = false

var _meshes: Dictionary = {}
var _cached_immeshes: Dictionary = {}
var _cached_materials: Dictionary = {}

## Cached mesh instances for entity bounds
var _bounds_meshes: Dictionary = {}
var _bounds_immeshes: Dictionary = {}

## Pooled canvas items for entity IDs
var _entity_id_pool: Array[Label] = []
var _active_entity_ids: Dictionary = {}


func _process(_delta: float) -> void:
    if show_spatial_hash:
        _draw_spatial_hash()
    else:
        _clear_overlay_mesh("DebugSpatialHash")
    if show_entity_bounds:
        _draw_entity_bounds()
    else:
        _clear_bounds_meshes()
    if show_entity_ids:
        _draw_entity_ids()
    else:
        _hide_all_entity_ids()
    if show_occupied_cells:
        _draw_occupied_cells()
    else:
        _clear_overlay_mesh("DebugOccupiedCells")


func _get_or_create_material(material_name: String, color: Color) -> ORMMaterial3D:
    var key: String = material_name
    if _cached_materials.has(key):
        return _cached_materials[key]
    var mat := ORMMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = color
    _cached_materials[key] = mat
    return mat


func _clear_overlay_mesh(key: String) -> void:
    if _meshes.has(key):
        var mesh: MeshInstance3D = _meshes[key]
        if is_instance_valid(mesh):
            remove_child(mesh)
            mesh.queue_free()
        _meshes.erase(key)
        _cached_immeshes.erase(key)


func _clear_bounds_meshes() -> void:
    for key: String in _bounds_meshes:
        var mesh: MeshInstance3D = _bounds_meshes[key]
        if is_instance_valid(mesh):
            remove_child(mesh)
            mesh.queue_free()
    _bounds_meshes.clear()
    _bounds_immeshes.clear()


# --- Pathfinding overlay ---


func draw_path(
    entity_id: String, start_pos: Vector3, waypoints: PackedVector3Array, reached_index: int
) -> void:
    if not enabled:
        return

    var mesh_instance: MeshInstance3D
    if not _meshes.has(entity_id):
        mesh_instance = MeshInstance3D.new()
        mesh_instance.name = "DebugPath_" + entity_id
        mesh_instance.top_level = true
        add_child(mesh_instance)
        _meshes[entity_id] = mesh_instance
    else:
        mesh_instance = _meshes[entity_id]

    var immesh: ImmediateMesh
    if _cached_immeshes.has(entity_id):
        immesh = _cached_immeshes[entity_id]
        immesh.clear_surfaces()
    else:
        immesh = ImmediateMesh.new()
        _cached_immeshes[entity_id] = immesh
    mesh_instance.mesh = immesh

    var reached_material := _get_or_create_material("reached", Color(0.5, 0.5, 0.5, 0.6))
    var remaining_material := _get_or_create_material("remaining", Color(0.0, 1.0, 0.0, 0.8))

    var h: float = CellUtil.CELL_SIZE * 0.5
    var y_off: float = 0.05
    var n: int = waypoints.size()
    var start_y := TerrainSystem.get_height_at_world_smooth(start_pos) + y_off
    var start_local := mesh_instance.to_local(Vector3(start_pos.x, start_y, start_pos.z))

    for i in n:
        var wp := waypoints[i]
        var mat := reached_material if i < reached_index else remaining_material
        var cx: float = wp.x
        var cz: float = wp.z
        var y: float = TerrainSystem.get_height_at_world_smooth(wp) + y_off

        var center := mesh_instance.to_local(Vector3(cx, y, cz))

        var next_wp: Vector3 = waypoints[i] if i == n - 1 else waypoints[i + 1]
        var edge_xz := _edge_xz(cx, cz, next_wp.x, next_wp.z, h)
        var edge_y := (
            TerrainSystem.get_height_at_world_smooth(Vector3(edge_xz.x, 0.0, edge_xz.y)) + y_off
        )
        var exit_p := mesh_instance.to_local(Vector3(edge_xz.x, edge_y, edge_xz.y))

        immesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
        immesh.surface_add_vertex(start_local)
        immesh.surface_add_vertex(center)
        immesh.surface_add_vertex(center)
        immesh.surface_add_vertex(exit_p)
        immesh.surface_end()

        start_local = exit_p


func _edge_xz(cx: float, cz: float, ox: float, oz: float, h: float) -> Vector2:
    var dx: float = signf(ox - cx)
    var dz: float = signf(oz - cz)
    if dx == 0.0 and dz == 0.0:
        return Vector2(cx, cz)
    if dx != 0.0 and dz != 0.0:
        return Vector2(cx + dx * h, cz + dz * h)
    if dx != 0.0:
        return Vector2(cx + dx * h, cz)
    return Vector2(cx, cz + dz * h)


func clear_path(entity_id: String) -> void:
    if not _meshes.has(entity_id):
        return
    var mesh_instance: MeshInstance3D = _meshes[entity_id]
    if is_instance_valid(mesh_instance):
        remove_child(mesh_instance)
        mesh_instance.queue_free()
    _meshes.erase(entity_id)
    _cached_immeshes.erase(entity_id)


# --- Spatial hash grid overlay ---


func _draw_spatial_hash() -> void:
    var grid_mesh_name := "DebugSpatialHash"
    var mesh_instance: MeshInstance3D
    if not _meshes.has(grid_mesh_name):
        mesh_instance = MeshInstance3D.new()
        mesh_instance.name = grid_mesh_name
        mesh_instance.top_level = true
        add_child(mesh_instance)
        _meshes[grid_mesh_name] = mesh_instance
    else:
        mesh_instance = _meshes[grid_mesh_name]

    var immesh: ImmediateMesh
    if _cached_immeshes.has(grid_mesh_name):
        immesh = _cached_immeshes[grid_mesh_name]
        immesh.clear_surfaces()
    else:
        immesh = ImmediateMesh.new()
        _cached_immeshes[grid_mesh_name] = immesh
    mesh_instance.mesh = immesh

    var occupied_mat := _get_or_create_material("spatial_hash_occupied", Color(1.0, 0.5, 0.0, 0.6))

    var sh := SpatialHashSingleton
    if not sh:
        return
    var cell_size := CellUtil.CELL_SIZE
    var y_off := 0.02

    for key: int in sh._grid.keys():
        var entries: Array = sh._grid[key]
        if entries.is_empty():
            continue
        var cell_x: int = (key >> 16) - 512
        var cell_y: int = (key & 0xFFFF) - 512
        var world_x: float = (cell_x + 0.5) * cell_size
        var world_z: float = (cell_y + 0.5) * cell_size
        var y: float = (
            TerrainSystem.get_height_at_world_smooth(Vector3(world_x, 0.0, world_z)) + y_off
        )

        var half := cell_size * 0.5
        var corners := [
            Vector3(world_x - half, y, world_z - half),
            Vector3(world_x + half, y, world_z - half),
            Vector3(world_x + half, y, world_z + half),
            Vector3(world_x - half, y, world_z + half),
            Vector3(world_x - half, y, world_z - half),
        ]

        immesh.surface_begin(Mesh.PRIMITIVE_LINES, occupied_mat)
        for i in range(4):
            immesh.surface_add_vertex(corners[i])
            immesh.surface_add_vertex(corners[i + 1])
        immesh.surface_end()


# --- Entity bounds overlay ---


func _draw_entity_bounds() -> void:
    var entities := get_tree().get_nodes_in_group("entities")
    var active_keys: Dictionary = {}

    for entity: Node3D in entities:
        if not is_instance_valid(entity):
            continue
        var foundation := entity.get_node_or_null("FoundationComponent")
        var cell_size := Vector2i(1, 1)
        if foundation:
            cell_size = foundation.foundation

        var pos := entity.global_position
        var half_w := cell_size.x * CellUtil.CELL_SIZE * 0.5
        var half_h := cell_size.y * CellUtil.CELL_SIZE * 0.5
        var y := TerrainSystem.get_height_at_world_smooth(pos) + 0.1

        var key: String = entity.name
        active_keys[key] = true

        var mesh_instance: MeshInstance3D
        if not _bounds_meshes.has(key):
            mesh_instance = MeshInstance3D.new()
            mesh_instance.name = "DebugBounds_" + key
            mesh_instance.top_level = true
            add_child(mesh_instance)
            _bounds_meshes[key] = mesh_instance
            var immesh := ImmediateMesh.new()
            _bounds_immeshes[key] = immesh
            mesh_instance.mesh = immesh
        else:
            mesh_instance = _bounds_meshes[key]

        var active_immesh: ImmediateMesh = _bounds_immeshes[key]
        active_immesh.clear_surfaces()

        var mat := _get_or_create_material("bounds", Color(1.0, 1.0, 0.0, 0.8))
        var corners := [
            Vector3(pos.x - half_w, y, pos.z - half_h),
            Vector3(pos.x + half_w, y, pos.z - half_h),
            Vector3(pos.x + half_w, y, pos.z + half_h),
            Vector3(pos.x - half_w, y, pos.z + half_h),
            Vector3(pos.x - half_w, y, pos.z - half_h),
        ]

        active_immesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
        for i in range(4):
            active_immesh.surface_add_vertex(corners[i])
            active_immesh.surface_add_vertex(corners[i + 1])
        active_immesh.surface_end()

    var to_remove: Array[String] = []
    for key: String in _bounds_meshes:
        if not active_keys.has(key):
            to_remove.append(key)
    for key: String in to_remove:
        var mesh: MeshInstance3D = _bounds_meshes[key]
        if is_instance_valid(mesh):
            remove_child(mesh)
            mesh.queue_free()
        _bounds_meshes.erase(key)
        _bounds_immeshes.erase(key)


# --- Occupied cells overlay ---


func _draw_occupied_cells() -> void:
    var mesh_name := "DebugOccupiedCells"
    var mesh_instance: MeshInstance3D
    if not _meshes.has(mesh_name):
        mesh_instance = MeshInstance3D.new()
        mesh_instance.name = mesh_name
        mesh_instance.top_level = true
        add_child(mesh_instance)
        _meshes[mesh_name] = mesh_instance
    else:
        mesh_instance = _meshes[mesh_name]

    var immesh: ImmediateMesh
    if _cached_immeshes.has(mesh_name):
        immesh = _cached_immeshes[mesh_name]
        immesh.clear_surfaces()
    else:
        immesh = ImmediateMesh.new()
        _cached_immeshes[mesh_name] = immesh
    mesh_instance.mesh = immesh

    var sh := SpatialHashSingleton
    if not sh:
        return

    var cell_size := CellUtil.CELL_SIZE
    var y_off := 0.03
    var building_mat := _get_or_create_material("occupied_building", Color(0.0, 1.0, 0.0, 0.4))
    var blocked_mat := _get_or_create_material("occupied_blocked", Color(1.0, 0.0, 0.0, 0.4))

    for key: int in sh._building_cells.keys():
        var cell_x: int = (key >> 16) - 512
        var cell_y: int = (key & 0xFFFF) - 512
        var world_x: float = (cell_x + 0.5) * cell_size
        var world_z: float = (cell_y + 0.5) * cell_size
        var y: float = (
            TerrainSystem.get_height_at_world_smooth(Vector3(world_x, 0.0, world_z)) + y_off
        )
        _draw_cell_square(immesh, building_mat, world_x, world_z, y, cell_size)

    for key: int in sh._blocked_cells.keys():
        if sh._building_cells.has(key):
            continue
        var cell_x: int = (key >> 16) - 512
        var cell_y: int = (key & 0xFFFF) - 512
        var world_x: float = (cell_x + 0.5) * cell_size
        var world_z: float = (cell_y + 0.5) * cell_size
        var y: float = (
            TerrainSystem.get_height_at_world_smooth(Vector3(world_x, 0.0, world_z)) + y_off
        )
        _draw_cell_square(immesh, blocked_mat, world_x, world_z, y, cell_size)


func _draw_cell_square(
    immesh: ImmediateMesh,
    mat: ORMMaterial3D,
    world_x: float,
    world_z: float,
    y: float,
    cell_size: float,
) -> void:
    var half := cell_size * 0.5
    var corners := [
        Vector3(world_x - half, y, world_z - half),
        Vector3(world_x + half, y, world_z - half),
        Vector3(world_x + half, y, world_z + half),
        Vector3(world_x - half, y, world_z + half),
        Vector3(world_x - half, y, world_z - half),
    ]
    immesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
    for i in range(4):
        immesh.surface_add_vertex(corners[i])
        immesh.surface_add_vertex(corners[i + 1])
    immesh.surface_end()


# --- Entity IDs overlay ---


func _get_camera() -> Camera3D:
    var cam := get_viewport().get_camera_3d()
    return cam


func _world_to_screen(world_pos: Vector3) -> Vector2:
    var cam := _get_camera()
    if not cam:
        return Vector2.INF
    var screen_pos := cam.unproject_position(world_pos)
    if cam.is_position_behind(world_pos):
        return Vector2.INF
    return screen_pos


func _draw_entity_ids() -> void:
    var entities := get_tree().get_nodes_in_group("entities")
    var active_keys: Dictionary = {}

    for entity: Node3D in entities:
        if not is_instance_valid(entity):
            continue
        var stats := entity.get_node_or_null("StatsComponent")
        if not stats:
            continue
        var display_name: String = stats.get("display_name") if stats.get("display_name") else ""
        var id: String = stats.get("id") if stats.get("id") else ""
        if display_name.is_empty() and id.is_empty():
            continue

        var key: String = entity.name
        active_keys[key] = true

        var world_pos: Vector3 = entity.global_position
        world_pos.y += 4.0
        var screen_pos := _world_to_screen(world_pos)
        if screen_pos == Vector2.INF:
            continue

        var label: Label
        if _active_entity_ids.has(key):
            label = _active_entity_ids[key]
        else:
            if not _entity_id_pool.is_empty():
                label = _entity_id_pool.pop_back()
            else:
                label = Label.new()
                label.add_theme_font_size_override("font_size", 10)
                add_child(label)
            _active_entity_ids[key] = label

        var health_text := ""
        var health := entity.get_node_or_null("HealthComponent")
        if health:
            var current: int = health.get("current_health") if health.get("current_health") else 0
            var max_h: int = health.get("max_health") if health.get("max_health") else 0
            health_text = " [%d/%d]" % [current, max_h]

        label.name = "entity_id_" + key
        label.text = display_name + " (" + id + ")" + health_text
        label.position = screen_pos + Vector2(-50.0, -30.0)
        label.z_index = 100
        label.visible = true

    var to_pool: Array[String] = []
    for key: String in _active_entity_ids:
        if not active_keys.has(key):
            to_pool.append(key)
    for key: String in to_pool:
        var label: Label = _active_entity_ids[key]
        label.visible = false
        _entity_id_pool.append(label)
        _active_entity_ids.erase(key)


func _hide_all_entity_ids() -> void:
    for key: String in _active_entity_ids:
        var label: Label = _active_entity_ids[key]
        label.visible = false
        _entity_id_pool.append(label)
    _active_entity_ids.clear()


# --- Cleanup ---


func reset_overlays() -> void:
    enabled = true
    show_spatial_hash = false
    show_entity_bounds = false
    show_health_bars = false
    show_entity_ids = false
    show_occupied_cells = false
    _clear_overlay_mesh("DebugSpatialHash")
    _clear_bounds_meshes()
    _clear_overlay_mesh("DebugOccupiedCells")
    _hide_all_entity_ids()


func clear_all() -> void:
    for entity_id in _meshes.keys():
        clear_path(entity_id)
    _clear_bounds_meshes()
    _entity_id_pool.clear()
    _active_entity_ids.clear()
