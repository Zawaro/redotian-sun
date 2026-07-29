## ADDED Requirements

### Requirement: BatchLoader manages batched async model loading
`BatchLoader` SHALL be an autoload singleton that coordinates model loading across the application. It SHALL maintain a queue of model paths, fire `ResourceLoader.load_threaded_request()` in controlled batches, poll for completion, and signal when each model is available.

#### Scenario: Batch preload fires requests in controlled batch size
- **WHEN** `BatchLoader.preload_batch(paths)` is called with N paths
- **THEN** it SHALL fire up to `BATCH_SIZE` concurrent `load_threaded_request()` calls and hold the remaining paths in a queue until prior requests complete

#### Scenario: Model becomes available after batch load completes
- **WHEN** a threaded load for a model path reports `THREAD_LOAD_LOADED`
- **THEN** `BatchLoader` SHALL store the `PackedScene` in its cache, emit `model_loaded(path)`, and fire the next queued request

#### Scenario: Batch load fails for a path
- **WHEN** a threaded load reports `THREAD_LOAD_FAILED`
- **THEN** `BatchLoader` SHALL emit a warning, remove the path from in-flight tracking, and continue with the next queued request

#### Scenario: Batch completes all paths
- **WHEN** all queued and in-flight requests are resolved
- **THEN** `BatchLoader` SHALL emit `batch_complete` and stop `_process()` polling

#### Scenario: Idle cost when no loads are in flight
- **WHEN** `BatchLoader` has no queued or in-flight requests
- **THEN** `_process()` SHALL NOT be called (disabled via `set_process(false)`)

### Requirement: BatchLoader provides cache access for consumers
`BatchLoader` SHALL expose its loaded model cache to other components via `is_loaded(path)` and `get_scene(path)` methods. It SHALL also expose `is_in_flight(path)` so consumers can distinguish between "not requested" and "currently loading".

#### Scenario: Consumer checks if model is cached
- **WHEN** a consumer calls `BatchLoader.is_loaded(path)` for a path that has been loaded
- **THEN** it SHALL return `true`

#### Scenario: Consumer retrieves cached model
- **WHEN** a consumer calls `BatchLoader.get_scene(path)` for a cached path
- **THEN** it SHALL return the `PackedScene` (or `null` if not cached)

#### Scenario: Consumer checks if model is in-flight
- **WHEN** a consumer calls `BatchLoader.is_in_flight(path)` for a path with an active request
- **THEN** it SHALL return `true`

### Requirement: MapLoader pre-warms BatchLoader before entity creation
`MapLoader.load_map_into()` SHALL collect all unique `model_path` values from the map's entity entries AND their deploy/undeploy targets, then call `BatchLoader.preload_batch()` before the entity creation loop.

#### Scenario: Map load pre-warms models
- **WHEN** `load_map_into()` parses a map JSON with entities that have `model_path`
- **THEN** it SHALL call `BatchLoader.preload_batch()` with the unique model paths before creating any entities

#### Scenario: Map load pre-warms deploy/undeploy targets
- **WHEN** a map entity has `deploys_into` or `undeploys_into` set to a valid entity ID
- **THEN** `load_map_into()` SHALL resolve the target entity's `model_path` via `EntityFactory.get_entity_data()` and include it in the preload batch

#### Scenario: Map with no models
- **WHEN** a map has no entities with `model_path`
- **THEN** `load_map_into()` SHALL skip the preload call

### Requirement: MapEditor pre-warms all entity models on startup
`MapEditor._ready()` SHALL collect all unique `model_path` values from `EntityFactory._entity_cache` and call `BatchLoader.preload_batch()`.

#### Scenario: Editor startup pre-warms all models
- **WHEN** the MapEditor scene is loaded
- **THEN** it SHALL call `BatchLoader.preload_batch()` with all entity model paths from EntityFactory

### Requirement: Sidebar pre-warms models on prerequisite change
`Sidebar` SHALL call a pre-warm method when `PrerequisiteSystem.prerequisites_changed` fires, collecting `model_path` values from newly-available build menu items AND their deploy/undeploy targets, then passing them to `BatchLoader.preload_batch()`.

#### Scenario: Prerequisite change pre-warms new items
- **WHEN** `prerequisites_changed` fires and new items become available in the build menu
- **THEN** `Sidebar` SHALL call `BatchLoader.preload_batch()` with model paths for those items

#### Scenario: Prerequisite change pre-warms deploy targets
- **WHEN** a newly-available build menu item has `deploys_into` or `undeploys_into` set
- **THEN** `Sidebar` SHALL resolve the target entity's `model_path` via `EntityFactory.get_entity_data()` and include it in the preload batch

#### Scenario: Initial sidebar load pre-warms available items
- **WHEN** `Sidebar._ready()` completes setup
- **THEN** it SHALL pre-warm models for all initially-available build menu items and their deploy/undeploy targets
