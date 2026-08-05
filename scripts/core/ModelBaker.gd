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
        var verts: Variant = arrays[Mesh.ARRAY_VERTEX]
        if not (verts is PackedVector3Array and not (verts as PackedVector3Array).is_empty()):
            continue
        var v_arr := verts as PackedVector3Array
        for i in v_arr.size():
            v_arr[i] = xform * v_arr[i]
        arrays[Mesh.ARRAY_VERTEX] = v_arr

        var normals: Variant = arrays[Mesh.ARRAY_NORMAL]
        if normals is PackedVector3Array and not (normals as PackedVector3Array).is_empty():
            var n_arr := normals as PackedVector3Array
            for i in n_arr.size():
                n_arr[i] = (basis * n_arr[i]).normalized()
            arrays[Mesh.ARRAY_NORMAL] = n_arr

        var tangents: Variant = arrays[Mesh.ARRAY_TANGENT]
        if tangents is PackedFloat32Array and (tangents as PackedFloat32Array).size() % 4 == 0:
            var t_arr := tangents as PackedFloat32Array
            for i in range(0, t_arr.size(), 4):
                var t_vec := Vector3(t_arr[i], t_arr[i + 1], t_arr[i + 2])
                t_vec = (basis * t_vec).normalized()
                t_arr[i] = t_vec.x
                t_arr[i + 1] = t_vec.y
                t_arr[i + 2] = t_vec.z
            arrays[Mesh.ARRAY_TANGENT] = t_arr
        var new_surface := mesh.get_surface_count()
        # PrimitiveMesh (BoxMesh etc.) surfaces are always triangles; only
        # ArrayMesh exposes a per-surface primitive type getter.
        var primitive := Mesh.PRIMITIVE_TRIANGLES
        if src is ArrayMesh:
            primitive = (src as ArrayMesh).surface_get_primitive_type(s)
        mesh.add_surface_from_arrays(primitive, arrays)
        var mat := mi.get_active_material(s)
        if mat == null:
            mat = src.surface_get_material(s)
        if mat:
            mesh.surface_set_material(new_surface, mat)
        if is_remappable:
            remappable.append(new_surface)
