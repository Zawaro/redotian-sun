extends Node

const MAX_INSTANCES_PER_MESH: int = 10000

var _terrain_scene: PackedScene
var _mesh_cache: Dictionary = {}
var _multimesh_nodes: Dictionary = {}
var _multimesh_meshes: Dictionary = {}
var _multimesh_aabb: Dictionary = {}
var _active_counts: Dictionary = {}
var _instance_data: Dictionary = {}
var _index_to_key: Dictionary = {}
var _terrain_parent: Node3D
var _glb_instance: Node = null
var _on_cell_changed_count: int = 0
var _pink_multimesh: MultiMesh = null
var _pink_mmi: MultiMeshInstance3D = null
var _pink_counts: int = 0
var _pink_data: Dictionary = {}


func _ready() -> void:
    _terrain_scene = TerrainCatalog.load_terrain_scene()
    _terrain_parent = Node3D.new()
    _terrain_parent.name = "Terrain"
    add_child(_terrain_parent)
    _extract_meshes()
    _setup_multimesh_nodes()
    TerrainSystem.cell_changed.connect(_on_cell_changed)
    var existing := TerrainSystem.get_all_cells()
    var mesh_keys := _multimesh_meshes.keys()
    if OS.is_stdout_verbose():
        print(
            "[TerrainRenderer] _ready: mesh_names=", mesh_keys, " existing_cells=", existing.size()
        )
    for key in existing:
        _on_cell_changed(key, existing[key])


func _exit_tree() -> void:
    if TerrainSystem.cell_changed.is_connected(_on_cell_changed):
        TerrainSystem.cell_changed.disconnect(_on_cell_changed)
    clear_all()
    if _glb_instance:
        _glb_instance.queue_free()
        _glb_instance = null


func _extract_meshes() -> void:
    var instance := _terrain_scene.instantiate()
    _find_all_meshes(instance)
    instance.visible = false
    _glb_instance = instance


func _find_all_meshes(node: Node) -> void:
    if node is MeshInstance3D:
        var raw_name := node.name
        var clean_name := raw_name.trim_suffix("_3D")
        if not _mesh_cache.has(clean_name):
            var mesh_dupe: ArrayMesh = node.mesh.duplicate()
            var mats: Array = []
            for i in mesh_dupe.get_surface_count():
                var mat: Material = node.mesh.surface_get_material(i)
                if not mat:
                    mat = node.get_surface_override_material(i)
                if mat:
                    mat = mat.duplicate()
                    mesh_dupe.surface_set_material(i, mat)
                mats.append(mat)
            # Corner-pivot convention: the mesh origin is a footprint corner, so
            # the horizontal half-size is the pivot -> foundation-center vector.
            var aabb := mesh_dupe.get_aabb()
            _mesh_cache[clean_name] = {
                "mesh": mesh_dupe,
                "materials": mats,
                "half": Vector3(aabb.size.x * 0.5, 0.0, aabb.size.z * 0.5),
            }
    for child in node.get_children():
        _find_all_meshes(child)


func _setup_multimesh_nodes() -> void:
    for mesh_name in _mesh_cache:
        var entry: Dictionary = _mesh_cache[mesh_name]
        var multimesh := MultiMesh.new()
        multimesh.mesh = entry["mesh"]
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.instance_count = MAX_INSTANCES_PER_MESH
        multimesh.visible_instance_count = 0
        var mmi := MultiMeshInstance3D.new()
        mmi.multimesh = multimesh
        var mats: Array = entry["materials"]
        for i in mats.size():
            if mats[i]:
                multimesh.mesh.surface_set_material(i, mats[i])
        mmi.name = "MM_" + mesh_name
        _terrain_parent.add_child(mmi)
        _multimesh_nodes[mesh_name] = mmi
        _multimesh_meshes[mesh_name] = multimesh
        _active_counts[mesh_name] = 0


func render_cell(cell: Vector2i, data: Dictionary) -> void:
    var key := CellUtil.cell_key_str(cell)
    if _instance_data.has(key) or _pink_data.has(key):
        remove_cell(cell)
    var resolution: TerrainArtData.ArtResolution = TerrainCatalog.resolve_cell_art(data)
    var object_id: String = data.get("object_id", "")
    if not resolution.valid or not _multimesh_meshes.has(resolution.submesh_id):
        _render_pink_placeholder(cell, data, object_id)
        return
    var mesh_name: String = resolution.submesh_id
    var multimesh: MultiMesh = _multimesh_meshes[mesh_name]
    var idx: int = _active_counts[mesh_name]
    if idx >= MAX_INSTANCES_PER_MESH:
        return
    _active_counts[mesh_name] = idx + 1
    multimesh.visible_instance_count = idx + 1
    var center := CellUtil.cell_to_world(cell)
    var height: int = data.get("height", 0)
    center.y = height * TerrainSystem.HEIGHT_STEP
    var rotation: float = data.get("rotation", resolution.rotation)
    # Corner-pivot tiles rotate about the foundation center: the pivot (mesh
    # origin) is a footprint corner, so offset the instance by the rotated
    # pivot -> foundation-center vector to keep the footprint centered.
    var half: Vector3 = _mesh_cache[mesh_name]["half"]
    multimesh.set_instance_transform(idx, CellUtil.tile_transform(center, rotation, half))
    _instance_data[key] = {"mesh_name": mesh_name, "index": idx}
    _index_to_key[mesh_name + ":" + str(idx)] = key
    _update_multimesh_aabb(mesh_name, multimesh, center, half)


func _update_multimesh_aabb(
    mesh_name: String, multimesh: MultiMesh, world_pos: Vector3, half: Vector3
) -> void:
    var step := maxf(TerrainSystem.HEIGHT_STEP, 0.1)
    var cell_min := world_pos - half
    var cell_size := Vector3(half.x * 2.0, step, half.z * 2.0)
    var cell_aabb := AABB(cell_min, cell_size)
    if not _multimesh_aabb.has(mesh_name):
        _multimesh_aabb[mesh_name] = cell_aabb
        multimesh.custom_aabb = cell_aabb
    else:
        var merged: AABB = _multimesh_aabb[mesh_name].merge(cell_aabb)
        _multimesh_aabb[mesh_name] = merged
        multimesh.custom_aabb = merged


func remove_cell(cell: Vector2i) -> void:
    var key := CellUtil.cell_key_str(cell)
    var entry: Dictionary = _instance_data.get(key, {})
    if entry.is_empty():
        _remove_pink(key)
        return
    var mesh_name: String = entry["mesh_name"]
    var idx: int = entry["index"]
    var multimesh: MultiMesh = _multimesh_meshes.get(mesh_name)
    if not multimesh:
        _instance_data.erase(key)
        _index_to_key.erase(mesh_name + ":" + str(idx))
        return
    var last_idx: int = _active_counts[mesh_name] - 1
    _index_to_key.erase(mesh_name + ":" + str(idx))
    if idx != last_idx:
        var last_transform: Transform3D = multimesh.get_instance_transform(last_idx)
        multimesh.set_instance_transform(idx, last_transform)
        var last_key: String = _index_to_key.get(mesh_name + ":" + str(last_idx), "")
        if not last_key.is_empty():
            _instance_data[last_key]["index"] = idx
            _index_to_key[mesh_name + ":" + str(idx)] = last_key
            _index_to_key.erase(mesh_name + ":" + str(last_idx))
    _active_counts[mesh_name] = last_idx
    multimesh.visible_instance_count = last_idx
    multimesh.set_instance_transform(last_idx, Transform3D(Basis(), Vector3(-9999, -9999, -9999)))
    _instance_data.erase(key)


func clear_all() -> void:
    for mesh_name in _multimesh_meshes:
        _active_counts[mesh_name] = 0
        var multimesh: MultiMesh = _multimesh_meshes[mesh_name]
        multimesh.visible_instance_count = 0
    _pink_counts = 0
    if _pink_multimesh:
        _pink_multimesh.visible_instance_count = 0
    _instance_data.clear()
    _pink_data.clear()
    _index_to_key.clear()
    _multimesh_aabb.clear()


func _on_cell_changed(cell_key: String, cell_data: Dictionary) -> void:
    _on_cell_changed_count += 1
    if (
        OS.is_stdout_verbose()
        and (_on_cell_changed_count <= 3 or _on_cell_changed_count % 200 == 0)
    ):
        var empty := cell_data.is_empty()
        print(
            "[TerrainRenderer] _on_cell_changed #",
            _on_cell_changed_count,
            " key=",
            cell_key,
            " empty=",
            empty
        )
    var parts := cell_key.split(",")
    if parts.size() == 2:
        var cell := Vector2i(int(parts[0]), int(parts[1]))
        if cell_data.is_empty():
            remove_cell(cell)
        else:
            var mesh_data := cell_data
            if not mesh_data.has("type"):
                mesh_data = TerrainSystem.calculate_cell_mesh(cell)
            render_cell(cell, mesh_data)


func _ensure_pink_mesh() -> void:
    if _pink_mmi:
        return
    var box := BoxMesh.new()
    box.size = Vector3(CellUtil.CELL_SIZE, TerrainSystem.HEIGHT_STEP, CellUtil.CELL_SIZE)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(1.0, 0.0, 1.0)
    var multimesh := MultiMesh.new()
    multimesh.mesh = box
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.instance_count = MAX_INSTANCES_PER_MESH
    multimesh.visible_instance_count = 0
    multimesh.mesh.surface_set_material(0, mat)
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = multimesh
    mmi.name = "MM_PINK"
    _terrain_parent.add_child(mmi)
    _pink_multimesh = multimesh
    _pink_mmi = mmi


func _render_pink_placeholder(cell: Vector2i, data: Dictionary, family: String) -> void:
    push_warning(
        "TerrainRenderer: no art for family '%s' at %s" % [family, CellUtil.cell_key_str(cell)]
    )
    _ensure_pink_mesh()
    var idx := _pink_counts
    if idx >= MAX_INSTANCES_PER_MESH:
        return
    _pink_counts = idx + 1
    _pink_multimesh.visible_instance_count = idx + 1
    var world_pos := CellUtil.cell_to_world(cell)
    world_pos.y = int(data.get("height", 0)) * TerrainSystem.HEIGHT_STEP
    _pink_multimesh.set_instance_transform(idx, Transform3D(Basis(), world_pos))
    _pink_data[CellUtil.cell_key_str(cell)] = idx


func _remove_pink(key: String) -> void:
    if not _pink_data.has(key) or _pink_multimesh == null:
        return
    var idx: int = _pink_data[key]
    var last_idx := _pink_counts - 1
    if idx != last_idx:
        var last_transform: Transform3D = _pink_multimesh.get_instance_transform(last_idx)
        _pink_multimesh.set_instance_transform(idx, last_transform)
        for k in _pink_data:
            if int(_pink_data[k]) == last_idx:
                _pink_data[k] = idx
                break
    _pink_counts = last_idx
    _pink_multimesh.visible_instance_count = last_idx
    _pink_multimesh.set_instance_transform(
        last_idx, Transform3D(Basis(), Vector3(-9999, -9999, -9999))
    )
    _pink_data.erase(key)
