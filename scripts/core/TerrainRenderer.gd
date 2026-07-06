extends Node

const TERRAIN_GLB_PATH: String = "res://assets/models/terrain/placeholder_terrain01.glb"
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

func _ready() -> void:
    _terrain_scene = load(TERRAIN_GLB_PATH) as PackedScene
    _terrain_parent = Node3D.new()
    _terrain_parent.name = "Terrain"
    add_child(_terrain_parent)
    _extract_meshes()
    _setup_multimesh_nodes()
    TerrainSystem.cell_changed.connect(_on_cell_changed)
    var existing := TerrainSystem.get_all_cells()
    print("[TerrainRenderer] _ready: mesh_names=", _multimesh_meshes.keys(), " existing_cells=", existing.size())
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
            _mesh_cache[clean_name] = { "mesh": mesh_dupe, "materials": mats }
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
    var key := _cell_key(cell)
    if _instance_data.has(key):
        remove_cell(cell)
    var terrain_type: String = data.get("type", "clear")
    var variant: int = data.get("variant", 1)
    var mesh_name := _get_mesh_name(terrain_type, variant)
    if not _multimesh_meshes.has(mesh_name):
        print("[TerrainRenderer] No mesh for ", mesh_name, " (type=", terrain_type, " variant=", variant, ")")
        return
    var multimesh: MultiMesh = _multimesh_meshes[mesh_name]
    var idx: int = _active_counts[mesh_name]
    if idx >= MAX_INSTANCES_PER_MESH:
        return
    _active_counts[mesh_name] = idx + 1
    multimesh.visible_instance_count = idx + 1
    var grid_half: float = float(TerrainSystem.grid_cells) * Pathfinder.CELL_SIZE * 0.5
    var world_pos := Pathfinder.cell_to_world(cell) - Vector3(grid_half, 0, grid_half)
    var height: int = data.get("height", 0)
    world_pos.y = height * TerrainSystem.HEIGHT_STEP
    var rotation: float = data.get("rotation", 0.0)
    var transform := Transform3D(Basis(), world_pos)
    transform.basis = Basis(Vector3.UP, deg_to_rad(rotation))
    multimesh.set_instance_transform(idx, transform)
    _instance_data[key] = { "mesh_name": mesh_name, "index": idx }
    _index_to_key[mesh_name + ":" + str(idx)] = key
    _update_multimesh_aabb(mesh_name, multimesh, world_pos)

func _update_multimesh_aabb(mesh_name: String, multimesh: MultiMesh, world_pos: Vector3) -> void:
    var half_size := Pathfinder.CELL_SIZE * 0.5
    var cell_min := world_pos - Vector3(half_size, 0.0, half_size)
    var cell_size := Vector3(Pathfinder.CELL_SIZE, maxf(TerrainSystem.HEIGHT_STEP, 0.1), Pathfinder.CELL_SIZE)
    var cell_aabb := AABB(cell_min, cell_size)
    if not _multimesh_aabb.has(mesh_name):
        _multimesh_aabb[mesh_name] = cell_aabb
        multimesh.custom_aabb = cell_aabb
    else:
        var merged: AABB = _multimesh_aabb[mesh_name].merge(cell_aabb)
        _multimesh_aabb[mesh_name] = merged
        multimesh.custom_aabb = merged

func remove_cell(cell: Vector2i) -> void:
    var key := _cell_key(cell)
    var entry: Dictionary = _instance_data.get(key, {})
    if entry.is_empty():
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
    _instance_data.clear()
    _index_to_key.clear()
    _multimesh_aabb.clear()

func _on_cell_changed(cell_key: String, cell_data: Dictionary) -> void:
    _on_cell_changed_count += 1
    if _on_cell_changed_count <= 3 or _on_cell_changed_count % 200 == 0:
        print("[TerrainRenderer] _on_cell_changed #", _on_cell_changed_count, " key=", cell_key, " empty=", cell_data.is_empty())
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

func _cell_key(cell: Vector2i) -> String:
    return str(cell.x) + "," + str(cell.y)

func _get_mesh_name(terrain_type: String, variant: int) -> String:
    var prefix := ""
    match terrain_type:
        "clear":
            prefix = "clear"
        "slope":
            prefix = "slope"
        "cliff":
            prefix = "cliff"
        _:
            prefix = "clear"
    return prefix + str(variant).pad_zeros(2)
