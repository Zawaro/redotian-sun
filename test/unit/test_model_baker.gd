extends Node

# ModelBaker must collapse a GLB's subnode tree into one multi-surface
# ArrayMesh without losing surfaces, materials, vertices, or bounds — and the
# bake must be cached per model path.

const MODEL_PATH := "res://games/ts/assets/models/nod_buggy01.glb"


func _tree() -> SceneTree:
    return Engine.get_main_loop() as SceneTree


func _count_surfaces(node: Node) -> int:
    var count := 0
    if node is MeshInstance3D:
        var mi := node as MeshInstance3D
        if mi.mesh:
            count += mi.mesh.get_surface_count()
    for child in node.get_children():
        count += _count_surfaces(child)
    return count


func test_bake_preserves_surface_count():
    var result := ModelBaker.bake_model(MODEL_PATH, false)
    var mesh: ArrayMesh = result.get("mesh")
    TestHelper.assert_true(mesh != null, "baked mesh exists")
    TestHelper.assert_true(mesh.get_surface_count() > 0, "baked mesh has surfaces")
    var scene := load(MODEL_PATH) as PackedScene
    var instance := scene.instantiate()
    var expected := _count_surfaces(instance)
    instance.free()
    TestHelper.assert_eq(mesh.get_surface_count(), expected, "surface count preserved")
    _finish()


func test_bake_preserves_materials():
    var result := ModelBaker.bake_model(MODEL_PATH, false)
    var mesh: ArrayMesh = result.get("mesh")
    var missing := 0
    for s in mesh.get_surface_count():
        if mesh.surface_get_material(s) == null:
            missing += 1
    TestHelper.assert_true(missing == 0, "all surfaces keep a material (missing=%d)" % missing)
    _finish()


func test_bake_has_nonempty_vertices_and_aabb():
    var result := ModelBaker.bake_model(MODEL_PATH, false)
    var mesh: ArrayMesh = result.get("mesh")
    var aabb := mesh.get_aabb()
    TestHelper.assert_true(
        aabb.size.x > 0.0 and aabb.size.y > 0.0 and aabb.size.z > 0.0, "non-zero AABB"
    )
    TestHelper.assert_true(mesh.surface_get_array_len(0) > 0, "vertex array non-empty")
    _finish()


func test_bake_cache_reuse():
    var first := ModelBaker.bake_model(MODEL_PATH, false)
    var second := ModelBaker.bake_model(MODEL_PATH, false)
    TestHelper.assert_true(
        first.get("mesh") == second.get("mesh"), "second bake reuses cached mesh"
    )
    _finish()


func test_bake_records_remappable_surfaces():
    var scene := load(MODEL_PATH) as PackedScene
    var instance := scene.instantiate() as Node3D
    var result := ModelBaker.bake_merged_mesh(instance, true)
    var surfaces: PackedInt32Array = result.get("remappable_surfaces")
    var mesh: ArrayMesh = result.get("mesh")
    instance.free()
    TestHelper.assert_eq(
        surfaces.size(), mesh.get_surface_count(), "remappable flag records every surface"
    )
    _finish()


func test_bake_transforms_subnode_offsets():
    # A subnode offset by (2,0,0) must bake its vertices to +2 on x.
    var root := Node3D.new()
    var mi := MeshInstance3D.new()
    mi.mesh = BoxMesh.new()
    mi.position = Vector3(2.0, 0.0, 0.0)
    root.add_child(mi)
    var result := ModelBaker.bake_merged_mesh(root, false)
    var mesh: ArrayMesh = result.get("mesh")
    var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var min_x := INF
    var max_x := -INF
    for v in verts:
        min_x = minf(min_x, v.x)
        max_x = maxf(max_x, v.x)
    TestHelper.assert_true(
        absf((min_x + max_x) / 2.0 - 2.0) < 0.01, "vertices shifted by subnode offset"
    )
    mi.free()
    root.free()
    _finish()


func test_bake_rotates_subnode_normals():
    # A 90-degree Z rotation maps the +X face normal to +Y.
    var root := Node3D.new()
    var mi := MeshInstance3D.new()
    mi.mesh = BoxMesh.new()
    mi.rotation_degrees = Vector3(0.0, 0.0, 90.0)
    root.add_child(mi)
    var result := ModelBaker.bake_merged_mesh(root, false)
    var mesh: ArrayMesh = result.get("mesh")
    var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
    var found := false
    for n in normals:
        if n.distance_to(Vector3(0.0, 1.0, 0.0)) < 0.01:
            found = true
            break
    TestHelper.assert_true(found, "subnode rotation transforms normals")
    mi.free()
    root.free()
    _finish()


func test_bake_surface_without_normals_or_tangents():
    # A surface with only vertices+indices must bake without crashing.
    var src := ArrayMesh.new()
    var arr: Array = []
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(
        [Vector3.ZERO, Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)]
    )
    arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
    src.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
    var root := Node3D.new()
    var mi := MeshInstance3D.new()
    mi.mesh = src
    mi.position = Vector3(1.0, 2.0, 3.0)
    root.add_child(mi)
    var result := ModelBaker.bake_merged_mesh(root, false)
    var mesh: ArrayMesh = result.get("mesh")
    TestHelper.assert_eq(mesh.get_surface_count(), 1, "surface baked without normals/tangents")
    var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    TestHelper.assert_true(
        verts[0].is_equal_approx(Vector3(1.0, 2.0, 3.0)), "vertex transformed with no normals"
    )
    mi.free()
    root.free()
    _finish()


func _finish() -> void:
    pass
