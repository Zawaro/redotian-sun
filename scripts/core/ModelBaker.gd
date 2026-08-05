class_name ModelBaker

## Bakes a model's GLB subnode tree into a single multi-surface ArrayMesh so a
## whole unit renders as one MultiMesh instance. Subnode local transforms are
## baked into vertex positions; per-surface materials are preserved so future
## team-color hue-shifts can target specific surfaces.

static var _bake_cache: Dictionary = {}


## Loads, bakes, and caches a model by path. Returns `{}` on failure and the
## same Dictionary on cache hits regardless of the `is_remappable` flag of a
## later call (the mesh itself is identical; the flag only fills
## `remappable_surfaces` on first bake).
static func bake_model(model_path: String, is_remappable: bool) -> Dictionary:
    if _bake_cache.has(model_path):
        return _bake_cache[model_path]
    if not ResourceLoader.exists(model_path):
        push_warning("ModelBaker: model not found: %s" % model_path)
        return {}
    var scene := load(model_path) as PackedScene
    if scene == null:
        push_warning("ModelBaker: cannot load scene: %s" % model_path)
        return {}
    var instance := scene.instantiate() as Node3D
    if instance == null:
        push_warning("ModelBaker: scene root is not Node3D: %s" % model_path)
        return {}
    var result := bake_merged_mesh(instance, is_remappable)
    instance.free()
    _bake_cache[model_path] = result
    return result


## Bakes an already-instantiated model root. Returns
## `{"mesh": ArrayMesh, "remappable_surfaces": PackedInt32Array}`. Vertices are
## relative to `model_root`'s origin (its own transform is NOT baked in — the
## caller composes it as the per-instance model offset).
static func bake_merged_mesh(model_root: Node3D, is_remappable: bool) -> Dictionary:
    var mesh := ArrayMesh.new()
    var remappable := PackedInt32Array()
    if model_root is MeshInstance3D:
        _append_mesh_instance(
            model_root as MeshInstance3D, Transform3D.IDENTITY, mesh, remappable, is_remappable
        )
    for child in model_root.get_children():
        _append_meshes(child, Transform3D.IDENTITY, mesh, remappable, is_remappable)
    return {"mesh": mesh, "remappable_surfaces": remappable}


static func _append_meshes(
    node: Node,
    parent_xform: Transform3D,
    mesh: ArrayMesh,
    remappable: PackedInt32Array,
    is_remappable: bool,
) -> void:
    var xform := parent_xform
    if node is Node3D:
        xform = parent_xform * (node as Node3D).transform
    if node is MeshInstance3D:
        _append_mesh_instance(node as MeshInstance3D, xform, mesh, remappable, is_remappable)
    for child in node.get_children():
        _append_meshes(child, xform, mesh, remappable, is_remappable)


static func _append_mesh_instance(
    mi: MeshInstance3D,
    xform: Transform3D,
    mesh: ArrayMesh,
    remappable: PackedInt32Array,
    is_remappable: bool,
) -> void:
    var src := mi.mesh as Mesh
    if src == null:
        return
    var basis := xform.basis
    for s in src.get_surface_count():
        var arrays := src.surface_get_arrays(s)
        var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        if verts.is_empty():
            continue
        for i in verts.size():
            verts[i] = xform * verts[i]
        var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
        for i in normals.size():
            normals[i] = (basis * normals[i]).normalized()
        var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
        if tangents.size() % 4 == 0:
            for i in range(0, tangents.size(), 4):
                var t_vec := Vector3(tangents[i], tangents[i + 1], tangents[i + 2])
                t_vec = (basis * t_vec).normalized()
                tangents[i] = t_vec.x
                tangents[i + 1] = t_vec.y
                tangents[i + 2] = t_vec.z
        arrays[Mesh.ARRAY_VERTEX] = verts
        arrays[Mesh.ARRAY_NORMAL] = normals
        arrays[Mesh.ARRAY_TANGENT] = tangents
        var new_surface := mesh.get_surface_count()
        mesh.add_surface_from_arrays(src.surface_get_primitive_type(s), arrays)
        var mat := mi.get_active_material(s)
        if mat == null:
            mat = src.surface_get_material(s)
        if mat:
            mesh.surface_set_material(new_surface, mat)
        if is_remappable:
            remappable.append(new_surface)
