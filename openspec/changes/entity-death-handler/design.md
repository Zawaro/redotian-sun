## Context

`HealthComponent` emits `health_zero` when an entity reaches 0 HP, but no system listens. Destroyed entities persist as ghosts — buildings occupy cells and block placement, units linger invisibly. The sell path (`BuildingManager.sell_building()`) demonstrates the correct cleanup pattern: unregister cells, unregister prerequisites, remove entry, deselect, free node.

Two entity placement paths exist:
1. **Runtime placement** — `BuildingManager.place_building()` creates entities via `EntityFactory.create_entity()` and registers them in `_buildings`
2. **Map loading** — `MapLoader.load_map_into()` creates entities via `EntityFactory.create_entity()` but does NOT register them with `BuildingManager`

SpatialHash rebuilds every frame from the `"entities"` group — freed nodes naturally disappear. SelectionManager checks `is_instance_valid` before operating — freed entities are lazily removed. The only system requiring active cleanup on death is BuildingManager (cells, prerequisites, entry).

## Goals / Non-Goals

**Goals:**
- All entities are freed when `health_zero` fires
- Buildings registered in BuildingManager get full cleanup (cells, prereqs, entry, deselect, signal)
- Non-building entities get freed via `queue_free()` — SpatialHash and SelectionManager self-clean lazily
- Components self-clean via `_exit_tree()` (DockClient, HarvestComponent, DeployComponent)

**Non-Goals:**
- Sell animation (reverse build) — future
- Sell priority logic (mid-sell + fatal damage) — future
- Death animations, death sounds, area effects — future
- Armor calculation, damage types — already works (flat damage)
- Unit registry — units tracked by SpatialHash (auto-rebuilds), not a dedicated registry
- General `entity_destroyed` signal — building_destroyed on BuildingManager covers the demo; general signal deferred to a dedicated lifecycle system if needed

## Decisions

### 1. Split responsibility: EntityFactory handles all entities, BuildingManager handles buildings

**Choice**: Two separate connections, not one cross-cutting handler.

- `EntityFactory.create_entity()`: connects `health_zero` → `entity.queue_free()` for all entities (3-line lambda)
- `BuildingManager.place_building()`: connects `health_zero` → `_on_building_destroyed()` for buildings

**Rationale**: EntityFactory is a factory — its job is creation, not destruction. Adding a full death handler with knowledge of BuildingManager, PrerequisiteSystem, and SpatialHash violates single responsibility. Instead, EntityFactory does the bare minimum (free the node). BuildingManager owns building death because it owns building registration — the cleanup data lives in its `_buildings` array.

For buildings, both connections fire. BuildingManager's handler runs first (connected earlier in `place_building`), does full cleanup. EntityFactory's lambda runs second, calls `queue_free()` (already queued, harmless double-call).

**Alternative considered**: Single `_on_entity_death()` on EntityFactory — rejected because it couples the factory to destruction logic and requires cross-cutting knowledge of every system.

### 2. `building_destroyed` signal on BuildingManager (not `entity_destroyed` on EntityFactory)

**Choice**: Emit from the handler that has the data.

**Rationale**: BuildingManager's handler has entity_data from the `_buildings` entry. EntityFactory's lambda doesn't know entity_data. Emitting a general signal from EntityFactory would require storing entity_data on every entity (via meta or StatsComponent) — unnecessary complexity for MVP.

**Future**: If a general `entity_destroyed` signal is needed, add it to a dedicated lifecycle system — not shoehorned into EntityFactory.

### 3. Double-free safety via deferred `queue_free()`

**Choice**: Both EntityFactory lambda and BuildingManager handler call `queue_free()`. No explicit guards.

**Rationale**: Redot's `queue_free()` is deferred to end of frame. Multiple calls on the same node are safe — second call is a no-op. No need for `_find_building_index` checks or `_is_selling` flags for MVP.

**Future**: When sell animations are added, BuildingManager will need a `_is_selling` flag to let death interrupt mid-sell (no refund).

### 4. Signal connection in `create_entity()` before tree entry

**Choice**: Connect `health_zero` in `EntityFactory.create_entity()` after adding HealthComponent but before the entity enters the scene tree.

**Rationale**: Works because signal connection is on the HealthComponent instance, not dependent on tree position. `health_zero` only fires during gameplay (take_damage/kill), by which time the entity is in the tree.

**Alternative considered**: Connect in `HealthComponent._ready()` — rejected because HealthComponent shouldn't know about entity death lifecycle.

## Risks / Trade-offs

- **Double queue_free()** → Mitigated: Redot's `queue_free()` is deferred and safe to call multiple times.
- **Sell + death race** → Mitigated for MVP: sell is atomic (no animation delay), so both paths can't interleave. Future sell animations will need explicit state tracking.
- **Map-loaded buildings don't free cells** → Pre-existing gap: `MapLoader` doesn't register buildings with `BuildingManager`, so cells aren't tracked. The death handler gracefully skips building cleanup for these. Cell registration for map-loaded buildings is a separate fix.
- **Components holding stale references** → Mitigated: DockClientComponent, HarvestComponent, DeployComponent all have `_exit_tree()` cleanup that releases references on `queue_free()`.
