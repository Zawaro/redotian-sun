extends Node

@export var enabled: bool = true

var _meshes: Dictionary = {}
var _cached_immeshes: Dictionary = {}
var _cached_materials: Dictionary = {}


func _get_or_create_material(material_name: String, color: Color) -> ORMMaterial3D:
    var key: String = material_name
    if _cached_materials.has(key):
        return _cached_materials[key]
    var mat := ORMMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = color
    _cached_materials[key] = mat
    return mat


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

    var h: float = Pathfinder.CELL_SIZE * 0.5
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


func clear_all() -> void:
    for entity_id in _meshes.keys():
        clear_path(entity_id)
