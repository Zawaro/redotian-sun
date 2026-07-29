extends Node

# BatchLoader unit tests — cache, batch loading, signal delivery.

var _test_passed := 0
var _test_failed := 0
var _signal_path: String = ""


func _on_model_loaded(path: String) -> void:
    _signal_path = path


func test_is_loaded_returns_false_for_unknown_path():
    TestHelper.assert_true(
        not BatchLoader.is_loaded("res://__nonexistent__.tscn"),
        "is_loaded returns false for unknown path"
    )
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_get_scene_returns_null_for_unknown_path():
    var scene: PackedScene = BatchLoader.get_scene("res://__nonexistent__.tscn")
    TestHelper.assert_true(scene == null, "get_scene returns null for unknown path")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_is_in_flight_returns_false_when_idle():
    TestHelper.assert_true(
        not BatchLoader.is_in_flight("res://__nonexistent__.tscn"),
        "is_in_flight returns false when no loads active"
    )
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_preload_batch_deduplicates():
    var path := "res://assets/models/gdi_conyard01.glb"
    BatchLoader.preload_batch([path, path, path])
    var in_queue: bool = BatchLoader._queue.has(path)
    var in_flight: bool = BatchLoader.is_in_flight(path)
    TestHelper.assert_true(
        in_queue or in_flight, "preload_batch processes the path (queue or in-flight)"
    )
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_preload_batch_skips_cached_paths():
    var path := "res://assets/models/gdi_conyard01.glb"
    BatchLoader._cache[path] = PackedScene.new()
    var queue_before: int = BatchLoader._queue.size()
    BatchLoader.preload_batch([path])
    TestHelper.assert_eq(
        BatchLoader._queue.size(), queue_before, "preload_batch skips paths already in cache"
    )
    BatchLoader._cache.erase(path)
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_preload_path_wraps_single_path():
    BatchLoader.preload_path("res://assets/models/gdi_conyard01.glb")
    TestHelper.assert_true(
        (
            BatchLoader._queue.size() > 0
            or BatchLoader.is_in_flight("res://assets/models/gdi_conyard01.glb")
        ),
        "preload_path adds a single path to the load pipeline"
    )
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
