## 1. ArtComponent async loading + cache

- [x] 1.1 Add `signal model_loaded` and a `static var _model_cache: Dictionary` (path → PackedScene) to `ArtComponent`.
- [x] 1.2 Add loading state (`_loading_path: String`) and initialise `set_process(false)`.
- [x] 1.3 Rewrite `_load_model()`: keep null/empty/`ResourceLoader.exists()` guards; on cache hit call a shared finalize helper synchronously; on cache miss call `ResourceLoader.load_threaded_request()`, store `_loading_path`, and `set_process(true)`.
- [x] 1.4 Extract a `_finalize_model(scene: PackedScene)` helper that instantiates, `add_child`, sets `owner`, applies the optional `texture_path` override (reusing `_apply_material`), and emits `model_loaded`.
- [x] 1.5 Implement `_process()`: early-return on `Engine.is_editor_hint()` or empty `_loading_path`; poll `ResourceLoader.load_threaded_get_status()`; on `THREAD_LOAD_LOADED` fetch the scene, cache it, finalize (guarded by `is_instance_valid(self)`), clear state and `set_process(false)`; on `THREAD_LOAD_FAILED` warn, clear state, `set_process(false)`.

## 2. BuildingManager preview integration

- [x] 2.1 In `_create_building_preview()`, after applying transparency, connect the preview `ArtComponent.model_loaded` to a new `_on_preview_model_loaded()` callback.
- [x] 2.2 Implement `_on_preview_model_loaded()` to re-apply `_set_node_transparency(_building_preview, 0.33)` to the full preview tree, guarded so it no-ops if the preview was freed.

## 3. Tests

- [x] 3.1 Add `test/unit/test_art_component.gd` covering: cache-hit synchronous instantiate + `model_loaded` emission, missing-path guard (no load, warning path), and cache sharing across two components.
- [x] 3.2 Ensure the test uses `TestHelper` assertions and the `_test_passed`/`_test_failed` counter bridge, and commit its `.uid`.

## 4. Quality gate

- [x] 4.1 `gdformat` + `gdformat --check` clean; no tabs introduced into multiline strings.
- [x] 4.2 `gdlint` clean on changed scripts and tests.
- [x] 4.3 Headless test suite passes ("N passed, 0 failed").
