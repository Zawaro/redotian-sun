## 1. BatchLoader Autoload

- [x] 1.1 Create `scripts/core/BatchLoader.gd` with `model_loaded(path)` and `batch_complete` signals
- [x] 1.2 Implement `_cache: Dictionary`, `_queue: Array[String]`, `_in_flight: Dictionary`, `BATCH_SIZE: int = 4`
- [x] 1.3 Implement `preload_batch(paths)` — deduplicate against cache and in-flight, append to queue, enable `_process()`
- [x] 1.4 Implement `preload_path(path)` — convenience wrapper for single path
- [x] 1.5 Implement `is_loaded(path)`, `get_scene(path)`, `is_in_flight(path)` accessors
- [x] 1.6 Implement `_process()` — fire requests from queue up to BATCH_SIZE, poll in-flight for completion, cache loaded scenes, emit `model_loaded`, emit `batch_complete` when idle
- [x] 1.7 Register `BatchLoader` autoload in `project.godot` after `EntityFactory`

## 2. ArtComponent Refactor

- [x] 2.1 Remove `static var _model_cache: Dictionary` from ArtComponent
- [x] 2.2 Remove `_loading_path: String` and `_init()` from ArtComponent
- [x] 2.3 Remove `_process()` polling from ArtComponent
- [x] 2.4 Add `var _waiting_for_path: String = ""` state to ArtComponent
- [x] 2.5 Rewrite `_load_model()` → `_try_load_model()`: check BatchLoader cache → check BatchLoader in-flight → fallback to own threaded request
- [x] 2.6 Implement `_wait_for_model(path)` — connect to `BatchLoader.model_loaded`, filter by path
- [x] 2.7 Implement `_on_batch_model_loaded(path)` — disconnect, get scene from BatchLoader, call `_finalize_model()`
- [x] 2.8 Implement `_load_model_fallback(path)` — fallback threaded request (same logic as current `_load_model` minus cache check)
- [x] 2.9 Add `_exit_tree()` cleanup — disconnect from BatchLoader signal if waiting
- [x] 2.10 Update `_ready()` to remove `set_process` gating (no longer needed)

## 3. MapLoader Integration

- [x] 3.1 In `MapLoader.load_map_into()`, before entity loop: iterate JSON entities, collect unique `model_path` values from `EntityFactory.get_entity_data(id).art_data.model_path`
- [x] 3.2 Call `BatchLoader.preload_batch(Array(model_paths))` before entity creation loop
- [x] 3.3 Guard against empty model paths (skip entities without art_data or model_path)
- [x] 3.4 In `MapLoader.load_map_into()` model path collection loop: resolve `data.deploys_into` and `data.undeploys_into` via `EntityFactory.get_entity_data()`, collect their `art_data.model_path` values into the preload batch

## 4. MapEditor Integration

- [x] 4.1 In `MapEditor._ready()`, after initialization: iterate `EntityFactory._entity_cache.values()`, collect unique `model_path` values
- [x] 4.2 Call `BatchLoader.preload_batch(Array(all_model_paths))`

## 5. Sidebar Integration

- [x] 5.1 Add `_prewarm_available_models()` method to Sidebar — iterate `_get_current_entities()`, collect unique `model_path` values, call `BatchLoader.preload_batch()`
- [x] 5.2 Call `_prewarm_available_models()` in `_on_prerequisites_changed()`
- [x] 5.3 Call `_prewarm_available_models()` in `_ready()` for initially available items
- [x] 5.4 In `_prewarm_available_models()`: resolve `entity_data.deploys_into` and `entity_data.undeploys_into` via `EntityFactory.get_entity_data()`, collect their `art_data.model_path` values into the preload batch

## 6. Tests

- [x] 6.1 Add `test/unit/test_batch_loader.gd` — test `preload_batch` fires requests, `is_loaded` returns true after completion, `model_loaded` signal fires
- [x] 6.2 Test `BatchLoader` cache hit — prewarm a known model path, verify `is_loaded` and `get_scene` return valid data
- [x] 6.3 Test `BatchLoader` batch size — verify no more than BATCH_SIZE concurrent requests are in-flight
- [x] 6.4 Update `test/unit/test_art_component.gd` — verify ArtComponent uses BatchLoader cache on configure()
- [x] 6.5 Test ArtComponent fallback — configure with uncached path, verify fallback threaded request starts

## 7. Quality Gate

- [x] 7.1 `gdformat` + `gdformat --check` clean on all changed scripts
- [x] 7.2 `gdlint` clean on all changed scripts and tests
- [x] 7.3 No tabs introduced in multiline strings
- [x] 7.4 Headless test suite passes with 0 failures
