## ADDED Requirements

### Requirement: ArtComponent loads models without blocking the main thread
`ArtComponent` SHALL load a non-cached model via `ResourceLoader.load_threaded_request()` and poll for completion in `_process()`, rather than calling the blocking `load()`. When the background load completes, the component SHALL instantiate the scene, add it as a child, and store the `PackedScene` in a shared cache.

#### Scenario: First load of a model path
- **WHEN** `ArtComponent` is configured with an `art_data.model_path` that is not yet cached
- **THEN** it SHALL issue a threaded load request and SHALL NOT block the main thread waiting for the file

#### Scenario: Background load completes
- **WHEN** the threaded load for the model reports `THREAD_LOAD_LOADED`
- **THEN** `ArtComponent` SHALL instantiate the loaded scene, add it as a child, cache the `PackedScene`, and stop polling

#### Scenario: Missing model file
- **WHEN** `art_data.model_path` does not exist (`ResourceLoader.exists()` is false)
- **THEN** `ArtComponent` SHALL emit a warning and SHALL NOT start a threaded load

#### Scenario: Failed background load
- **WHEN** the threaded load reports `THREAD_LOAD_FAILED`
- **THEN** `ArtComponent` SHALL emit a warning, clear its loading state, and stop polling without crashing

### Requirement: ArtComponent caches loaded models across instances
`ArtComponent` SHALL maintain a process-wide static cache mapping model path to `PackedScene`. A configuration whose model path is already cached SHALL instantiate from the cache immediately without issuing a threaded load.

#### Scenario: Cache hit on repeated model
- **WHEN** a second `ArtComponent` is configured with a model path already present in the static cache
- **THEN** it SHALL instantiate the cached `PackedScene` synchronously and SHALL NOT issue a threaded load request

#### Scenario: Cache shared across instances
- **WHEN** two entities reference the same model path
- **THEN** the model is read from disk at most once for the lifetime of the process

### Requirement: ArtComponent signals model availability
`ArtComponent` SHALL declare a `model_loaded` signal and emit it once the model mesh has been added as a child — for both the cache-hit path and the completed background-load path.

#### Scenario: Signal on cache hit
- **WHEN** the model is instantiated from the cache
- **THEN** `ArtComponent` SHALL emit `model_loaded`

#### Scenario: Signal on background completion
- **WHEN** a background load completes and the model is added as a child
- **THEN** `ArtComponent` SHALL emit `model_loaded`

### Requirement: ArtComponent tolerates being freed mid-load
`ArtComponent` SHALL handle the case where its owning entity is freed while a background load is still in progress, without producing errors or leaked scene nodes.

#### Scenario: Entity freed before load completes
- **WHEN** the entity holding a still-loading `ArtComponent` is freed (e.g. build mode is cancelled)
- **THEN** the pending load completion SHALL NOT run against the freed node and SHALL NOT raise an error

#### Scenario: Editor guard
- **WHEN** the scene is opened in the editor (`Engine.is_editor_hint()`)
- **THEN** `_process()` SHALL early-return and perform no threaded loading

### Requirement: Building preview re-applies transparency when the model arrives
`BuildingManager` SHALL connect to the preview entity's `ArtComponent.model_loaded` signal and re-apply the preview transparency override to the full entity tree when the model becomes available, so a model that loads after the preview is shown still renders semi-transparent.

#### Scenario: Model arrives after preview shown
- **WHEN** the placement preview is created for a building whose model is not yet loaded
- **THEN** `BuildingManager` SHALL show the preview immediately and SHALL re-apply transparency once `model_loaded` fires

#### Scenario: Preview cancelled before model arrives
- **WHEN** build mode is exited and the preview entity is freed before its model finishes loading
- **THEN** no transparency callback SHALL run against the freed preview
