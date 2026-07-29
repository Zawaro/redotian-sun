## Why

Placing a building loads its `.glb` model with a synchronous `load()` call on the main thread — once for the placement preview and again for the placed entity. Files up to ~1.4 MB block the main thread for ~10–50 ms each, producing a visible frame hitch every time a building is selected or placed. The same model is loaded from disk repeatedly with no caching.

## What Changes

- `ArtComponent` loads models off the main thread via `ResourceLoader.load_threaded_request()`, polling completion in `_process()` instead of blocking on `load()`.
- A process-wide static `PackedScene` cache (keyed by model path) makes every load after the first for a given model instant and avoids re-reading from disk.
- `ArtComponent` emits a new `model_loaded` signal when the mesh becomes available (whether from cache or a completed background load).
- `BuildingManager` connects to `model_loaded` on the placement preview and re-applies preview transparency once the model arrives, so a model that loads a frame later still renders semi-transparent.
- Robust handling for the async lifecycle: missing files, failed loads, and entities freed mid-load (e.g. cancelling build mode) are all handled without errors.

## Capabilities

### New Capabilities
- `async-model-loading`: Non-blocking, cached loading of entity 3D models in `ArtComponent`, with a completion signal and preview-transparency integration in `BuildingManager`.

### Modified Capabilities
<!-- No existing spec-level requirements change; placeholder/preview behaviour is preserved. -->

## Impact

- `scripts/components/ArtComponent.gd` — threaded load path, static model cache, `model_loaded` signal, `_process()` poller.
- `scripts/buildings/BuildingManager.gd` — connect `model_loaded` on the preview entity and re-apply transparency on arrival.
- No `.tscn` changes required; `ArtComponent.tscn` and existing `EntityData`/`ArtData` resources are unaffected. Behaviour is backward compatible: entities with no `model_path` still show their placeholder, and consumers reading `art_data` (e.g. `SelectionOverlay`) are unchanged.
