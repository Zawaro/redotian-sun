## Why

`HealthComponent.health_zero` fires when an entity reaches 0 HP, but nothing listens. Destroyed buildings persist as ghosts — occupying cells, blocking placement, appearing in the build menu. Units at 0 HP linger invisibly. This blocks the First Blood demo (deploy MCV → build base → destroy enemy Con Yard) and any meaningful combat.

## What Changes

- `EntityFactory.create_entity()` connects `health_zero` → `queue_free()` for all entities with a HealthComponent (3-line lambda)
- `BuildingManager.place_building()` connects `health_zero` → `_on_building_destroyed()` for buildings it tracks
- `_on_building_destroyed()` performs full building cleanup: unregister cells/bib cells from SpatialHash, unregister from PrerequisiteSystem, remove entry from `_buildings`, deselect from SelectionManager, emit `building_destroyed`, free node
- Map-loaded entities (not in `BuildingManager._buildings`) get freed via EntityFactory's lambda — building-specific cleanup gracefully skipped

## Capabilities

### New Capabilities
- `entity-death-cleanup`: Entity death handling — signal wiring and node removal for all entities, full system cleanup for buildings

### Modified Capabilities

## Impact

- **Scripts modified**: `scripts/entities/EntityFactory.gd` (~3 lines), `scripts/buildings/BuildingManager.gd` (~20 lines)
- **Systems affected**: `BuildingManager._buildings` (entry removal), `SpatialHash` (cell unregistration), `PrerequisiteSystem` (building unregistration), `SelectionManager` (deselection)
- **Signals**: New `building_destroyed` signal on `BuildingManager`
- **Scenes**: No scene changes — all logic in scripts
- **Backward compatibility**: No breaking changes — existing `sell_building()` path unchanged, `building_sold` signal preserved
