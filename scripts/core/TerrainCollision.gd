extends Node

var _collision_bodies: Dictionary = {}
var _collision_parent: Node3D
var _terrain_scene: PackedScene
var _mesh_cache: Dictionary = {}


func _ready() -> void:
    _terrain_scene = TerrainCatalog.load_terrain_scene()
    _build_mesh_cache()
    _collision_parent = Node3D.new()
    _collision_parent.name = "TerrainCollision"
    add_child(_collision_parent)
    TerrainSystem.cell_changed.connect(_on_cell_changed)
    for key in TerrainSystem.get_all_cells():
        _on_cell_changed(key, TerrainSystem.get_all_cells()[key])


func _build_mesh_cache() -> void:
    var instance := _terrain_scene.instantiate()
    _collect_meshes(instance)
    instance.queue_free()


func _collect_meshes(node: Node) -> void:
    if node is MeshInstance3D:
        var clean_name := node.name.trim_suffix("_3D")
        if not _mesh_cache.has(clean_name):
            _mesh_cache[clean_name] = node.mesh.duplicate()
    for child in node.get_children():
        _collect_meshes(child)


func _exit_tree() -> void:
    if TerrainSystem.cell_changed.is_connected(_on_cell_changed):
        TerrainSystem.cell_changed.disconnect(_on_cell_changed)
    clear_all()


func create_collision(cell: Vector2i, data: Dictionary, mesh: Mesh, rotation: float = 0.0) -> void:
    var key := CellUtil.cell_key_str(cell)
    remove_collision(cell)
    var static_body := StaticBody3D.new()
    static_body.name = "Collision_" + key
    static_body.collision_layer = 1
    static_body.collision_mask = 0
    var collision_shape_node := CollisionShape3D.new()
    collision_shape_node.shape = mesh.create_trimesh_shape()
    static_body.add_child(collision_shape_node)
    var center := CellUtil.cell_to_world(cell)
    var height: int = data.get("height", 0)
    center.y = height * TerrainSystem.HEIGHT_STEP
    var body_rotation: float = data.get("rotation", rotation)
    # Mirror the renderer: corner-pivot tiles rotate about the foundation center,
    # so offset the body by the rotated pivot -> foundation-center vector.
    var aabb := mesh.get_aabb()
    var half := Vector3(aabb.size.x * 0.5, 0.0, aabb.size.z * 0.5)
    static_body.position = CellUtil.tile_transform(center, body_rotation, half).origin
    static_body.rotation.y = deg_to_rad(body_rotation)
    _collision_parent.add_child(static_body)
    _collision_bodies[key] = static_body


func remove_collision(cell: Vector2i) -> void:
    var key := CellUtil.cell_key_str(cell)
    var body: StaticBody3D = _collision_bodies.get(key)
    if body:
        _collision_parent.remove_child(body)
        body.queue_free()
        _collision_bodies.erase(key)


func clear_all() -> void:
    for key in _collision_bodies:
        var body: StaticBody3D = _collision_bodies[key]
        if is_instance_valid(body):
            _collision_parent.remove_child(body)
            body.queue_free()
    _collision_bodies.clear()


func _on_cell_changed(cell_key: String, cell_data: Dictionary) -> void:
    var parts := cell_key.split(",")
    if parts.size() == 2:
        var cell := Vector2i(int(parts[0]), int(parts[1]))
        if cell_data.is_empty():
            remove_collision(cell)
        else:
            var mesh_data := cell_data
            if not mesh_data.has("type"):
                mesh_data = TerrainSystem.calculate_cell_mesh(cell)
            var resolution: TerrainArtData.ArtResolution = TerrainCatalog.resolve_cell_art(
                mesh_data
            )
            if not resolution.valid:
                push_warning(
                    (
                        "TerrainCollision: no art for family '%s' at %s; skipping body"
                        % [mesh_data.get("object_id", ""), cell_key]
                    )
                )
                remove_collision(cell)
                return
            var mesh := _get_cached_mesh(resolution.submesh_id)
            if mesh:
                create_collision(cell, mesh_data, mesh, resolution.rotation)


func _get_cached_mesh(mesh_name: String) -> Mesh:
    return _mesh_cache.get(mesh_name, null)
