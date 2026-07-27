extends Node

# ArtComponent unit tests — model cache, async-load guards, and model_loaded signal.
# Async completion is polled in _process(), which the headless runner does not step,
# and model_loaded is emitted deferred, so these tests exercise the synchronous
# mesh-present guarantee and the request/gating setup rather than signal delivery.

const ART_COMPONENT_SCRIPT: GDScript = preload("res://scripts/components/ArtComponent.gd")

var _test_passed := 0
var _test_failed := 0
var _signal_fired := false


func _make_component(entity: Node3D) -> ArtComponent:
    var comp := Node3D.new()
    comp.name = "ArtComponent"
    comp.set_script(ART_COMPONENT_SCRIPT)
    entity.add_child(comp)
    return comp as ArtComponent


func _make_data(model_path: String) -> EntityData:
    var data := EntityData.new()
    data.id = "TEST_ART"
    var art := ArtData.new()
    art.id = "TEST_ART"
    art.model_path = model_path
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


func test_cache_hit_instantiates_synchronously():
    var path := "res://__test_cache_hit__.tscn"
    ArtComponent._model_cache[path] = _make_scene()

    var entity := Node3D.new()
    var comp := _make_component(entity)
    _signal_fired = false
    comp.model_loaded.connect(_on_model_loaded)
    comp.configure(_make_data(path))

    var has_child := comp.get_child_count() > 0
    TestHelper.assert_true(has_child, "cache hit adds the model as a child synchronously")
    TestHelper.assert_true(
        not _signal_fired, "cache hit defers model_loaded until after configure() returns"
    )
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()

    ArtComponent._model_cache.erase(path)
    entity.free()


func test_cache_miss_starts_threaded_load():
    # Valid, uncached model: configure() must issue a threaded request and enable polling.
    # Completion can't be polled headless, so we only assert the request started.
    var path := "res://assets/models/gdi_conyard01.glb"
    ArtComponent._model_cache.erase(path)
    TestHelper.assert_true(ResourceLoader.exists(path), "test model resource exists")

    var entity := Node3D.new()
    var comp := _make_component(entity)
    comp.configure(_make_data(path))

    TestHelper.assert_true(comp._loading_path == path, "cache miss issues a threaded load request")
    TestHelper.assert_true(comp.is_processing(), "cache miss enables _process polling")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()

    ArtComponent._model_cache.erase(path)
    entity.free()


func test_missing_model_starts_no_load():
    var entity := Node3D.new()
    var comp := _make_component(entity)
    comp.configure(_make_data("res://does_not_exist_model.glb"))

    var no_child := comp.get_child_count() == 0
    var not_loading := comp._loading_path == ""
    TestHelper.assert_true(no_child, "missing model adds no child")
    TestHelper.assert_true(not_loading, "missing model does not start a threaded load")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()

    entity.free()


func test_cache_shared_across_components():
    var path := "res://__test_shared_cache__.tscn"
    ArtComponent._model_cache[path] = _make_scene()

    var entity_a := Node3D.new()
    var comp_a := _make_component(entity_a)
    comp_a.configure(_make_data(path))

    var entity_b := Node3D.new()
    var comp_b := _make_component(entity_b)
    comp_b.configure(_make_data(path))

    var both_have_model := comp_a.get_child_count() > 0 and comp_b.get_child_count() > 0
    var neither_loading := comp_a._loading_path == "" and comp_b._loading_path == ""
    TestHelper.assert_true(both_have_model, "both components instantiate from the shared cache")
    TestHelper.assert_true(neither_loading, "cached path triggers no threaded load in either")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()

    ArtComponent._model_cache.erase(path)
    entity_a.free()
    entity_b.free()
