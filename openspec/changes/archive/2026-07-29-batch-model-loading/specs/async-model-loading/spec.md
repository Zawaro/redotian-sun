## MODIFIED Requirements

### Requirement: ArtComponent caches loaded models across instances
`ArtComponent` SHALL check `BatchLoader._cache` for a model before issuing any load request. If `BatchLoader` has the model cached, `ArtComponent` SHALL instantiate it synchronously. If `BatchLoader` has the model in-flight, `ArtComponent` SHALL wait for `BatchLoader.model_loaded` signal. If neither, `ArtComponent` SHALL fall back to its own `ResourceLoader.load_threaded_request()`.

#### Scenario: Cache hit via BatchLoader
- **WHEN** `ArtComponent` is configured with an `art_data.model_path` that is already cached by `BatchLoader`
- **THEN** it SHALL instantiate the cached `PackedScene` synchronously and SHALL NOT issue a threaded load request

#### Scenario: In-flight via BatchLoader
- **WHEN** `ArtComponent` is configured with an `art_data.model_path` that `BatchLoader` is currently loading
- **THEN** it SHALL connect to `BatchLoader.model_loaded` and wait for the signal before instantiating

#### Scenario: Fallback to own threaded load
- **WHEN** `ArtComponent` is configured with an `art_data.model_path` that is neither cached nor in-flight by `BatchLoader`
- **THEN** it SHALL issue its own `ResourceLoader.load_threaded_request()` and poll for completion in `_process()`

#### Scenario: Cache shared across instances
- **WHEN** two entities reference the same model path
- **THEN** the model is read from disk at most once for the lifetime of the process

### Requirement: ArtComponent signals model availability
`ArtComponent` SHALL declare a `model_loaded` signal and emit it once the model mesh has been added as a child — for the BatchLoader cache-hit path, the BatchLoader signal-wait path, and the fallback threaded-load path.

#### Scenario: Signal on BatchLoader cache hit
- **WHEN** the model is instantiated from BatchLoader's cache
- **THEN** `ArtComponent` SHALL emit `model_loaded`

#### Scenario: Signal on BatchLoader signal-wait
- **WHEN** `BatchLoader.model_loaded` fires and `ArtComponent` instantiates the model
- **THEN** `ArtComponent` SHALL emit `model_loaded`

#### Scenario: Signal on fallback background completion
- **WHEN** a fallback threaded load completes and the model is added as a child
- **THEN** `ArtComponent` SHALL emit `model_loaded`
