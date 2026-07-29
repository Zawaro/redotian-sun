## Why

The existing `ArtComponent` async loading (PR #151) fires one `ResourceLoader.load_threaded_request()` per entity — uncoordinated, with no prioritization. When a map loads with 50+ entities, that's 50+ concurrent thread requests fired in a single frame. The build menu doesn't preload models at all — they only load when the player places a building. The MapEditor has no pre-warming. This creates unnecessary frame hitches on map load and delays model availability in the build menu.

## What Changes

- **New `BatchLoader` autoload** — centralized batch async model loading. Owns a queue of model paths, fires `load_threaded_request()` in controlled batch sizes, polls completion, and signals when each model is ready.
- **`ArtComponent` simplified** — checks `BatchLoader._cache` first. If cached → instant. If BatchLoader is loading it → waits for signal. If neither → falls back to its own threaded request. Removes static `_model_cache`, `_process` polling, and `_loading_path` state.
- **`MapLoader` pre-warms** — collects unique model paths from all entities in the map JSON, calls `BatchLoader.preload_batch()` before the entity creation loop.
- **`MapEditor` pre-warms** — on `_ready()`, collects all entity model paths from `EntityFactory._entity_cache` and calls `BatchLoader.preload_batch()`.
- **`Sidebar` pre-warms** — when `prerequisites_changed` fires, pre-warms models for newly-available build menu items.

## Capabilities

### New Capabilities
- `batch-model-loading`: Centralized batch async model loading via `BatchLoader` autoload, with coordinated pre-warming at map load, editor startup, and prerequisite changes.

### Modified Capabilities
- `async-model-loading`: `ArtComponent` delegates to `BatchLoader` cache instead of managing its own static cache and per-entity threading. The `model_loaded` signal and fallback threaded path are preserved.

## Impact

- `scripts/core/BatchLoader.gd` — new autoload singleton
- `scripts/components/ArtComponent.gd` — remove static cache, `_process` polling, `_loading_path`; add BatchLoader cache check + signal wait + fallback
- `scripts/maps/MapLoader.gd` — add model path collection + `BatchLoader.preload_batch()` call
- `scripts/editor/MapEditor.gd` — add `BatchLoader.preload_batch()` on `_ready()`
- `scripts/ui/Sidebar.gd` — add `_prewarm_available_models()` on prerequisite change
- `project.godot` — register `BatchLoader` autoload
- `openspec/specs/async-model-loading/spec.md` — update to reflect BatchLoader delegation
