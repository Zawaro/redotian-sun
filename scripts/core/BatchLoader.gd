extends Node

## Centralized batch async model loading.
## Fires ResourceLoader.load_threaded_request() in controlled batches,
## polls completion, and signals when each model is available.

## Emitted when a model path finishes loading and is cached.
signal model_loaded(path: String)
## Emitted when all queued and in-flight requests are resolved.
signal batch_complete

## Max concurrent load_threaded_request() calls.
const BATCH_SIZE: int = 4

## Loaded model scenes (model_path -> PackedScene).
var _cache: Dictionary = {}
## Paths waiting to fire a load request.
var _queue: Array[String] = []
## Paths with active load_threaded_request() calls.
var _in_flight: Dictionary = {}


func _ready() -> void:
    set_process(false)


func preload_batch(paths: Array) -> void:
    for path in paths:
        if path.is_empty():
            continue
        if _cache.has(path) or _in_flight.has(path) or path in _queue:
            continue
        _queue.append(path)
    _tick()


func preload_path(path: String) -> void:
    preload_batch([path])


func is_loaded(path: String) -> bool:
    return _cache.has(path)


func get_scene(path: String) -> PackedScene:
    return _cache.get(path) as PackedScene


func is_in_flight(path: String) -> bool:
    return _in_flight.has(path)


func _tick() -> void:
    # Fire requests up to BATCH_SIZE.
    while _in_flight.size() < BATCH_SIZE and not _queue.is_empty():
        var path: String = _queue.pop_front()
        if _cache.has(path) or _in_flight.has(path):
            continue
        var err := ResourceLoader.load_threaded_request(path)
        if err != OK:
            push_warning("BatchLoader: failed to request model: %s" % path)
            continue
        _in_flight[path] = true

    if _in_flight.is_empty() and _queue.is_empty():
        batch_complete.emit()
        set_process(false)
        return

    set_process(true)


func _process(_delta: float) -> void:
    var completed: Array[String] = []
    for path in _in_flight:
        var status := ResourceLoader.load_threaded_get_status(path)
        if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            continue
        completed.append(path)
        if status != ResourceLoader.THREAD_LOAD_LOADED:
            push_warning("BatchLoader: failed to load model: %s" % path)
            continue
        var scene := ResourceLoader.load_threaded_get(path) as PackedScene
        if scene == null:
            push_warning("BatchLoader: loaded resource is not a PackedScene: %s" % path)
            continue
        _cache[path] = scene
        model_loaded.emit(path)

    for path in completed:
        _in_flight.erase(path)

    _tick()
