extends Node

# UnitMeshRenderer must: register entities into per-region MultiMesh buckets
# (hiding the GLB tree), swap-remove slots on unregister, migrate buckets when
# units cross region boundaries, and eject preview/disabled entities back to
# node-tree rendering. Instance transforms aren't readable in headless (dummy
# rasterizer), so assertions target registry bookkeeping, visible counts, and
# the MultiMesh custom_aabb.

const MODEL_PATH := "res://assets/models/nod_buggy01.glb"

var _renderer: UnitMeshRenderer
var _container: Node3D


func _tree() -> SceneTree:
    return Engine.get_main_loop() as SceneTree


func _setup() -> void:
    _renderer = _tree().root.get_node_or_null("UnitMeshRenderer") as UnitMeshRenderer
    TestHelper.assert_true(_renderer != null, "UnitMeshRenderer autoload present")
    _renderer.clear_all()
    _container = Node3D.new()
    _container.name = "UMRTestContainer"
    _tree().root.add_child(_container)


func _teardown() -> void:
    _renderer.clear_all()
    if is_instance_valid(_container):
        _tree().root.remove_child(_container)
        _container.queue_free()


func _make_unit(pos: Vector3) -> Node3D:
    var entity := Node3D.new()
    entity.position = pos
    var model_root := Node3D.new()
    model_root.name = "ModelRoot"
    entity.add_child(model_root)
    _container.add_child(entity)
    return entity


func _register(entity: Node3D) -> bool:
    return _renderer.register(
        entity, MODEL_PATH, entity.get_node("ModelRoot") as Node3D, Transform3D.IDENTITY, false
    )


func _bucket(region: Vector2i) -> Dictionary:
    var region_map: Dictionary = _renderer._buckets.get(region, {})
    return region_map.get(MODEL_PATH, {})


func test_register_hides_model_and_allocates_slot():
    _setup()
    var entity := _make_unit(Vector3(10.0, 0.0, 10.0))
    var model_root := entity.get_node("ModelRoot") as Node3D
    TestHelper.assert_true(_register(entity), "register succeeds")
    TestHelper.assert_true(_renderer._registry.has(entity), "entity registered")
    TestHelper.assert_true(not model_root.visible, "GLB node tree hidden")
    var entry: Dictionary = _renderer._registry[entity]
    TestHelper.assert_eq(entry["slot"], 0, "first slot allocated")
    var region := _renderer._region_key(entity.global_position)
    TestHelper.assert_eq(entry["region"], region, "region matches")
    var bucket := _bucket(region)
    TestHelper.assert_true(not bucket.is_empty(), "bucket created")
    TestHelper.assert_eq(int(bucket["active_count"]), 1, "one active instance")
    var mm_bucket: MultiMesh = bucket["multimesh"]
    TestHelper.assert_eq(mm_bucket.visible_instance_count, 1, "visible count 1")
    TestHelper.assert_true(_renderer.is_physics_processing(), "physics processing enabled")
    _teardown()
    _finish()


func test_register_rejects_preview_and_disabled_entities():
    _setup()
    var preview_entity := _make_unit(Vector3(5.0, 0.0, 5.0))
    preview_entity.set_meta("_preview", true)
    TestHelper.assert_true(not _register(preview_entity), "preview-meta entity rejected")
    var disabled_entity := _make_unit(Vector3(6.0, 0.0, 6.0))
    disabled_entity.process_mode = Node.PROCESS_MODE_DISABLED
    TestHelper.assert_true(not _register(disabled_entity), "PROCESS_MODE_DISABLED entity rejected")
    TestHelper.assert_eq(_renderer._active_count, 0, "nothing registered")
    _teardown()
    _finish()


func test_swap_remove_compacts_slots():
    _setup()
    var a := _make_unit(Vector3(2.0, 0.0, 2.0))
    var b := _make_unit(Vector3(4.0, 0.0, 4.0))
    var c := _make_unit(Vector3(6.0, 0.0, 6.0))
    TestHelper.assert_true(_register(a), "register a")
    TestHelper.assert_true(_register(b), "register b")
    TestHelper.assert_true(_register(c), "register c")
    TestHelper.assert_eq(_renderer._active_count, 3, "three registered")
    TestHelper.assert_eq(_renderer._registry[b]["slot"], 1, "b in middle slot")
    _renderer.unregister(b)
    TestHelper.assert_true(not _renderer._registry.has(b), "b removed")
    TestHelper.assert_eq(_renderer._active_count, 2, "two remain")
    TestHelper.assert_eq(_renderer._registry[a]["slot"], 0, "first slot unchanged")
    TestHelper.assert_eq(_renderer._registry[c]["slot"], 1, "last slot moved into freed slot")
    var region := _renderer._region_key(a.global_position)
    var bucket := _bucket(region)
    TestHelper.assert_eq(int(bucket["active_count"]), 2, "active count compacted")
    var mm_compacted: MultiMesh = bucket["multimesh"]
    TestHelper.assert_eq(mm_compacted.visible_instance_count, 2, "visible count 2")
    _teardown()
    _finish()


func test_migration_across_region_boundary():
    _setup()
    var entity := _make_unit(Vector3(2.0, 0.0, 2.0))
    var old_region := _renderer._region_key(entity.global_position)
    TestHelper.assert_true(_register(entity), "register in region %s" % old_region)
    TestHelper.assert_true(_renderer._buckets.has(old_region), "old region bucket exists")
    entity.global_position = Vector3(1000.0, 0.0, 1000.0)
    var new_region := _renderer._region_key(entity.global_position)
    TestHelper.assert_true(new_region != old_region, "position crosses region boundary")
    _renderer._physics_process(0.0)
    var entry: Dictionary = _renderer._registry[entity]
    TestHelper.assert_eq(entry["region"], new_region, "entry migrated")
    TestHelper.assert_true(_renderer._buckets.has(new_region), "new region bucket exists")
    TestHelper.assert_true(not _renderer._buckets.has(old_region), "empty old bucket removed")
    var new_bucket := _bucket(new_region)
    TestHelper.assert_eq(int(new_bucket["active_count"]), 1, "one instance in new region")
    var mm_migrated: MultiMesh = new_bucket["multimesh"]
    TestHelper.assert_eq(mm_migrated.visible_instance_count, 1, "one visible in new region")
    _teardown()
    _finish()


func test_preview_ejects_and_restores_model():
    _setup()
    var entity := _make_unit(Vector3(2.0, 0.0, 2.0))
    var model_root := entity.get_node("ModelRoot") as Node3D
    TestHelper.assert_true(_register(entity), "register")
    TestHelper.assert_true(not model_root.visible, "hidden after register")
    entity.process_mode = Node.PROCESS_MODE_DISABLED
    _renderer._physics_process(0.0)
    TestHelper.assert_true(model_root.visible, "GLB shown while previewing")
    entity.process_mode = Node.PROCESS_MODE_INHERIT
    _renderer._physics_process(0.0)
    TestHelper.assert_true(not model_root.visible, "GLB hidden after finalize")
    _teardown()
    _finish()


func test_bucket_sets_aabb_and_disables_interpolation():
    _setup()
    var entity := _make_unit(Vector3(2.0, 0.0, 2.0))
    TestHelper.assert_true(_register(entity), "register")
    var region := _renderer._region_key(entity.global_position)
    var bucket := _bucket(region)
    var multimesh: MultiMesh = bucket["multimesh"]
    var expected := _renderer._region_aabb(region)
    (
        TestHelper
        . assert_true(
            (
                multimesh.custom_aabb.position.is_equal_approx(expected.position)
                and multimesh.custom_aabb.size.is_equal_approx(expected.size)
            ),
            "custom_aabb set to region box",
        )
    )
    var mmi: MultiMeshInstance3D = bucket["mmi"]
    TestHelper.assert_eq(
        mmi.physics_interpolation_mode, Node.PHYSICS_INTERPOLATION_MODE_OFF, "interpolation off"
    )
    _teardown()
    _finish()


func test_migration_into_full_region_keeps_entity_visible():
    _setup()
    # Fill region (0,0) with MAX_INSTANCES entities.
    var max_instances := UnitMeshRenderer.MAX_INSTANCES_PER_REGION
    var fill_a: Array[Node3D] = []
    for i in max_instances:
        var e := _make_unit(Vector3(float(i % 32), 0.0, float(i / 32)))
        fill_a.append(e)
        TestHelper.assert_true(_register(e), "register a %d" % i)
    TestHelper.assert_eq(_renderer._active_count, max_instances, "region A full")
    # Fill region (1,1) with MAX_INSTANCES entities (x,z within [32,64)).
    var fill_b: Array[Node3D] = []
    for i in max_instances:
        var e := _make_unit(Vector3(32.0 + float(i % 32), 0.0, 32.0 + float(i / 32)))
        fill_b.append(e)
        TestHelper.assert_true(_register(e), "register b %d" % i)
    TestHelper.assert_eq(_renderer._active_count, max_instances * 2, "both regions full")
    # Move one entity from region A into the full region B.
    var mover := fill_a[0]
    var model_root := mover.get_node("ModelRoot") as Node3D
    mover.global_position = Vector3(50.0, 0.0, 50.0)
    _renderer._physics_process(0.0)
    var entry: Dictionary = _renderer._registry[mover]
    TestHelper.assert_eq(entry["slot"], -1, "no slot in full target region")
    TestHelper.assert_true(model_root.visible, "GLB shown when no MultiMesh slot available")
    _teardown()
    _finish()


func _finish() -> void:
    pass
