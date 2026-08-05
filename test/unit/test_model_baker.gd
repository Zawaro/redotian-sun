extends Node

# ModelBaker must collapse a GLB's subnode tree into one multi-surface
# ArrayMesh without losing surfaces, materials, vertices, or bounds — and the
# bake must be cached per model path.

const MODEL_PATH := "res://assets/models/nod_buggy01.glb"


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


func _finish() -> void:
    pass
