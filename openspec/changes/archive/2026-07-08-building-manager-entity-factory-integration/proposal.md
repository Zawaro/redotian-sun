## Why

BuildingManager and BuildMenu still use the legacy `BuildingType` resource system (7 fields, no combat/power/movement data), while the rest of the codebase has migrated to `EntityData` + `EntityFactory`. This creates a parallel data path where buildings bypass the component stack entirely — placed buildings lack Stats, Health, Hitbox, Select, Foundation, Power, and other components that EntityFactory adds automatically. The migration closes this gap and makes buildings first-class entities.

## What Changes

- **BREAKING**: `BuildingType` class is removed — all code referencing it is updated to use `EntityData`
- **BREAKING**: `resources/buildings/*.tres` directory is removed — replaced by `resources/entities/structures/*.tres`
- `BuildingManager` calls `EntityFactory.create_entity()` instead of `building_type.scene.instantiate()`
- `BuildMenu` iterates `EntityData` resources instead of `BuildingType`
- `EntityFactory` gains a `get_all_by_type(entity_type)` query method for listing entities by category
- `EntityData` gains a `buildable: bool` field to distinguish player-buildable structures from map props
- 4 missing EntityData `.tres` files are created (barracks, refinery, war factory, guard tower)
- `building_placed` signal signature changes from `(Node3D, BuildingType)` to `(Node3D, EntityData)`

## Capabilities

### New Capabilities

None — this change integrates existing capabilities, it doesn't introduce new ones.

### Modified Capabilities

- `entity-factory`: Add `get_all_by_type(entity_type: EntityType) -> Array[EntityData]` query method to support listing entities by category (e.g., all BUILDING types for the build menu)
- `entity-data`: Add `buildable: bool` field to distinguish player-placeable structures from neutral/map-prop structures
- `entity-validation`: Update validation to warn on `buildable = true` with `strength <= 0` or missing `foundation`

## Impact

- **Scripts modified**: `scripts/buildings/BuildingManager.gd`, `scripts/ui/BuildMenu.gd`, `scripts/entities/EntityFactory.gd`, `scripts/data/EntityData.gd`
- **Scripts removed**: `scripts/buildings/BuildingType.gd`
- **Resources removed**: 7 files in `resources/buildings/`
- **Resources created**: 4 new `.tres` in `resources/entities/structures/`
- **Tests updated**: `test/unit/test_building_manager.gd`, `test/integration/test_building_placement.gd`
- **Signal consumers**: `building_placed` has zero current listeners — safe to change signature
- **Preview system**: 3D ghost preview (line 347-357) needs EntityFactory path — grid overlay remains unchanged
