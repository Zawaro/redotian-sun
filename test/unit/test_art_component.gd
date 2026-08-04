extends Node

# ArtComponent unit tests — BatchLoader integration, cache hits, fallback loading.

const ART_COMPONENT_SCRIPT: GDScript = preload("res://scripts/components/ArtComponent.gd")

var _signal_fired := false


func _make_component(entity: Node3D) -> ArtComponent:
    var comp := Node3D.new()
    comp.name = "ArtComponent"
    comp.set_script(ART_COMPONENT_SCRIPT)
    entity.add_child(comp)
    return comp as ArtComponent


func _make_data(path: String) -> EntityData:
    var data := EntityData.new()
    data.id = "TEST_ART"
    var art := ArtData.new()
    art.id = "TEST_ART"
    art.model_path = path
    data.art_data = art
    data.foundation = Vector2i(1, 1)
    return data


func _make_scene() -> PackedScene:
    var root := Node3D.new()
    root.name = "TestModel"
    var ps := PackedScene.new()
    ps.pack(root)
    root.free()
    return ps


func _on_model_loaded() -> void:
    _signal_fired = true


func test_batch_loader_cache_hit_instantiates_synchronously():
    var path := "res://__test_batch_cache_hit__.tscn"
    BatchLoader._cache[path] = _make_scene()

    var entity := Node3D.new()
    var comp := _make_component(entity)
    _signal_fired = false
    comp.model_loaded.connect(_on_model_loaded)
    comp.configure(_make_data(path))

    var has_child: bool = comp.get_child_count() > 0
    TestHelper.assert_true(has_child, "BatchLoader cache hit adds model as child synchronously")
    TestHelper.assert_true(
        not _signal_fired, "cache hit defers model_loaded until after configure() returns"
    )

    BatchLoader._cache.erase(path)
    entity.free()


func test_fallback_starts_threaded_load():
    var path := "res://assets/models/gdi_conyard01.glb"
    BatchLoader._cache.erase(path)
    TestHelper.assert_true(ResourceLoader.exists(path), "test model resource exists")

    var entity := Node3D.new()
    var comp := _make_component(entity)
    comp.configure(_make_data(path))

    TestHelper.assert_true(
        comp._waiting_for_path == path, "fallback sets _waiting_for_path to the model path"
    )

    BatchLoader._cache.erase(path)
    entity.free()


func test_missing_model_starts_no_load():
    var entity := Node3D.new()
    var comp := _make_component(entity)
    comp.configure(_make_data("res://does_not_exist_model.glb"))

    var no_child: bool = comp.get_child_count() == 0
    var not_waiting: bool = comp._waiting_for_path == ""
    TestHelper.assert_true(no_child, "missing model adds no child")
    TestHelper.assert_true(not_waiting, "missing model does not start a load")

    entity.free()


func test_cache_shared_across_components():
    var path := "res://__test_shared_batch_cache__.tscn"
    BatchLoader._cache[path] = _make_scene()

    var entity_a := Node3D.new()
    var comp_a := _make_component(entity_a)
    comp_a.configure(_make_data(path))

    var entity_b := Node3D.new()
    var comp_b := _make_component(entity_b)
    comp_b.configure(_make_data(path))

    var both_have_model: bool = comp_a.get_child_count() > 0 and comp_b.get_child_count() > 0
    var neither_waiting: bool = comp_a._waiting_for_path == "" and comp_b._waiting_for_path == ""
    TestHelper.assert_true(
        both_have_model, "both components instantiate from the shared BatchLoader cache"
    )
    TestHelper.assert_true(neither_waiting, "cached path triggers no threaded load in either")

    BatchLoader._cache.erase(path)
    entity_a.free()
    entity_b.free()
