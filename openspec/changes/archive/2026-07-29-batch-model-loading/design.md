## Context

`ArtComponent` currently loads models via per-entity `ResourceLoader.load_threaded_request()` calls, with a process-wide static `_model_cache` for deduplication. This works but has no coordination — each entity fires its own request independently. When a map loads with 50+ entities, that's 50+ requests fired in a single frame. The build menu doesn't preload models — they only load when the player places a building. The MapEditor has no pre-warming.

The project has 6 `.glb` models and 3 art resources with `model_path` set. The architecture needs to scale as more models are added.

Redot's `ResourceLoader.load_threaded_request()` fires async loads on a worker thread pool (default ~4-8 threads). The engine deduplicates requests for the same path. There is no built-in batch API — proposals like godotengine/godot-proposals#2966 request this but it doesn't exist yet.

## Goals / Non-Goals

**Goals:**
- Centralized control over model loading: batch sizes, prioritization, progress tracking
- Pre-warm models at map load, editor startup, and prerequisite changes
- Remove per-entity threading complexity from `ArtComponent`
- Zero runtime cost when no loads are in flight
- Fallback safety: entities always load even if BatchLoader hasn't pre-warmed their model

**Non-Goals:**
- Loading screen (future enhancement, not this change)
- Cache eviction (models are static assets, cache lives for process lifetime)
- Streaming / priority loading by distance (future enhancement)
- Progress bar UI (BatchLoader enables it, but not building it now)
- Changing `EntityFactory`, `EntityData`, or `ArtData` schemas

## Decisions

### 1. BatchLoader as autoload singleton

**Choice:** New `scripts/core/BatchLoader.gd` registered as autoload in `project.godot`.

**Rationale:** Needs to be accessible from `MapLoader` (static), `MapEditor` (@tool), `Sidebar` (UI), and `ArtComponent` (component). An autoload singleton is the established pattern in this project (13 existing autoloads). Alternative: a static utility class — rejected because it needs `_process()` polling and cannot be a @tool script.

**Registration order:** After `EntityFactory` (needs entity data available) but before `BuildingManager` (which creates previews that need models).

### 2. Batch size = 4 concurrent requests

**Choice:** Fire up to 4 `load_threaded_request()` calls simultaneously, then wait for at least one to complete before firing the next.

**Rationale:** Redot's thread pool is ~4-8 threads. Firing 4 at a time saturates the pool without starving other engine work (physics, rendering). The exact value can be tuned — start conservative.

**Alternative considered:** Fire all requests at once — rejected because 50+ concurrent requests could starve the thread pool and cause frame hitches. Alternative: fire 1 at a time — too slow for maps with many entities.

### 3. ArtComponent checks BatchLoader cache, falls back to own load

**Choice:** On `configure()`, ArtComponent checks `BatchLoader.get_scene(path)`. If cached → instant. If BatchLoader has it in-flight → wait for `BatchLoader.model_loaded` signal. If neither → fire its own `load_threaded_request()`.

**Rationale:** The fallback ensures entities always load, even if BatchLoader wasn't asked to pre-warm this path. This handles edge cases like `DeployComponent` creating entities at runtime with models that weren't in the initial preload batch.

**Signal pattern:** ArtComponent connects to `BatchLoader.model_loaded`, filters by path, disconnects on receipt. Multiple ArtComponents can wait on the same path — all receive the signal.

### 4. ArtComponent removes static `_model_cache`

**Choice:** Remove `static var _model_cache: Dictionary` from ArtComponent. `BatchLoader._cache` is the single source of truth.

**Rationale:** Two caches create confusion about which is authoritative. BatchLoader owns the cache lifecycle (preloading, polling, completion). ArtComponent reads from it.

**Risk:** If BatchLoader is not yet registered when ArtComponent tries to access it — mitigated by autoload registration order (BatchLoader before ArtComponent is instantiated via EntityFactory).

### 5. MapLoader pre-warms before entity creation loop

**Choice:** In `load_map_into()`, iterate the JSON entities, collect unique `model_path` values from `EntityFactory.get_entity_data(id).art_data.model_path`, call `BatchLoader.preload_batch(paths)` BEFORE the entity creation loop.

**Rationale:** `load_threaded_request()` is near-instant (just enqueues). The actual load happens async. By the time the entity loop creates entities and `ArtComponent.configure()` runs, most models will be in the cache or in-flight. Entity creation stays synchronous — no coroutine/await complexity.

**Alternative considered:** Make `load_map_into` async with yield — rejected as over-engineered. The sync loop with pre-warming achieves the same result without coroutine complexity.

### 6. MapEditor pre-warms all entity models on startup

**Choice:** In `MapEditor._ready()`, iterate `EntityFactory._entity_cache.values()`, collect all `model_path` values, call `BatchLoader.preload_batch()`.

**Rationale:** The editor needs all models available since the user can place any entity. Pre-warming once at startup means all subsequent entity creations hit the cache.

### 7. Sidebar pre-warms on prerequisite change

**Choice:** In `Sidebar._on_prerequisites_changed()`, call `_prewarm_available_models()` which collects `model_path` from `_get_current_entities()` and calls `BatchLoader.preload_batch()`.

**Rationale:** When prerequisites change, new items become available in the build menu. Pre-warming their models means the player can place them immediately without waiting for the model to load. Also called in `_ready()` for initially available items.

## Risks / Trade-offs

- [BatchLoader registration order] If BatchLoader loads after EntityFactory, the first `create_entity()` call might not find it. → Register BatchLoader before EntityFactory in project.godot. EntityFactory._ready() scans .tres files, doesn't create entities — so the order is safe.

- [Fallback threaded requests] ArtComponent's fallback path fires its own `load_threaded_request()`, which duplicates a BatchLoader request for the same path. → Engine deduplicates. The loaded resource is cached by the engine. At worst, a redundant request — not a correctness issue.

- [Signal cleanup] ArtComponent connects to `BatchLoader.model_loaded` and must disconnect. If the entity is freed before the signal fires, the dangling connection could error. → Disconnect in `_exit_tree()` or use `CONNECT_ONE_SHOT`.

- [Batch size tuning] 4 concurrent requests may be too conservative or too aggressive. → Expose `batch_size` as a const. Profile with 50+ entity maps and adjust.

- [Texture loading remains sync] `_finalize_model()` still calls `load(art_data.texture_path)` synchronously. → Not in scope for this change. Can be made async in a follow-up if texture loads are significant.
