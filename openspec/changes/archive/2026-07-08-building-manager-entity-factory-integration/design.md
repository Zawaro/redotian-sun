## Context

BuildingManager.gd (559 lines) is the last major consumer of the legacy `BuildingType` resource system. It loads `resources/buildings/*.tres` files (7 total), each a 9-field `BuildingType` resource with `id`, `display_name`, `footprint`, `scene`, `cameo`, `cost`, `build_time`. Buildings are placed via `building_type.scene.instantiate()` — direct scene instantiation that bypasses the EntityFactory component stack.

EntityFactory (251 lines) already works for vehicles (TestMap02 spawns BGGY via `create_entity("BGGY")`). It scans `resources/entities/`, caches EntityData by id, instantiates Entity.tscn, and conditionally adds 13 component types based on data properties. Buildings placed through EntityFactory would automatically get Stats, Health, Hitbox, Select, Foundation, Power, and other components.

BuildMenu.gd (95 lines) reads `BuildingManager.building_types` and casts each to `BuildingType` for button labels and press handlers. The coupling is thin — mostly type annotations and `display_name` access.

## Goals / Non-Goals

**Goals:**
- Migrate BuildingManager to use `EntityFactory.create_entity()` for all building placement
- Migrate BuildMenu to iterate EntityData instead of BuildingType
- Add `get_all_by_type()` to EntityFactory for querying entities by category
- Add `buildable: bool` to EntityData to distinguish player-placeable structures
- Create 4 missing EntityData .tres files (barracks, refinery, war factory, guard tower)
- Delete BuildingType.gd and `resources/buildings/` directory
- Update tests to use EntityData instead of BuildingType

**Non-Goals:**
- Power grid system (Issue #33 — future work)
- Build prerequisites / tech tree filtering
- Actual 3D model art for buildings (stays as colored placeholders)
- Build queue / production timing

## Decisions

### D1: `buildable` field on EntityData vs. separate list

**Choice**: Add `buildable: bool` field to EntityData.

**Alternatives considered**:
- Separate `buildable_entities` list in EntityFactory — rejected: duplicates data that belongs on the resource
- Filter by `entity_type == BUILDING` only — rejected: doesn't distinguish player-buildable (ConYard, Power Plant) from map-only structures (Civilian Guard Tower)

**Rationale**: The field is a single bool with default `false`. Non-buildable entities (infantry, vehicles, terrain, neutral structures) keep `false`. Only player-placeable buildings set `true`. This is data-driven, testable, and matches the original `BuildingType` system's implicit "everything in `resources/buildings/` is buildable" contract.

### D2: EntityFactory query method signature

**Choice**: `get_all_by_type(entity_type: EntityType) -> Array[EntityData]`

**Alternatives considered**:
- `get_buildable()` — rejected: too specific, `get_all_by_type()` is general-purpose
- Expose `_entity_cache.values()` — rejected: breaks encapsulation, no filtering

**Rationale**: BuildingManager needs "all BUILDING-type entities". A generic type filter serves this and future queries (e.g., "all VEHICLE types for a unit factory menu"). The method iterates the cache once and returns filtered results. Cache is small (~20 entities), so no performance concern.

### D3: Preview system approach

**Choice**: Keep grid overlay (green/red cells) unchanged. Replace 3D ghost instantiation with `EntityFactory.create_entity()` call, applied with transparency.

**Alternatives considered**:
- Drop 3D preview entirely — rejected: loses useful visual feedback
- Cache preview scenes per building — rejected: defeats the purpose of EntityFactory

**Rationale**: The preview at line 347-357 does `current_building_type.scene.instantiate()`. After migration, `EntityFactory.create_entity(data.id)` produces the same node tree (Entity.tscn + components). The `_set_node_transparency()` helper already works recursively on any Node3D. One subtlety: the preview entity must be freed when exiting build mode (already handled at line 74-77).

### D4: Signal signature change

**Choice**: `building_placed(building: Node3D, entity_data: EntityData)` — direct replacement.

**Rationale**: `building_placed` has zero current listeners (confirmed via graph trace). The signal is defined but never connected. Safe to change the type parameter. If future consumers need the BuildingType-equivalent data, EntityData is a superset.

### D5: `_buildings` array stored type

**Choice**: Change `"type": building_type` to `"type": entity_data` in the stored dictionary.

**Rationale**: The `_buildings` array (line 152-161) stores placed building metadata. `get_all_buildings()` returns this array. Currently nothing reads the `"type"` field externally, but it's part of the public API. Changing it to EntityData is consistent and backward-compatible (EntityData has all BuildingType fields plus more).

### D6: Incremental vs. full migration

**Choice**: Full migration in one shot — delete BuildingType.gd, remove old .tres files, update all references.

**Alternatives considered**:
- Dual-path (support both old and new) — rejected: adds complexity for zero benefit since `building_placed` has no listeners and the system is small

**Rationale**: The codebase is small (559-line BuildingManager, 95-line BuildMenu, 4 test functions). A clean break is simpler than maintaining two parallel paths. The 7 old .tres files map 1:1 to new EntityData files (3 already exist, 4 to create).

## Risks / Trade-offs

**[Risk] Preview entity has full component stack** → The preview entity from `EntityFactory.create_entity()` will have HealthComponent, HitboxComponent, etc. These are harmless in preview mode (no combat processing), but the HitboxComponent adds collision shapes. **Mitigation**: The preview is added to a `_preview` Node3D that is freed on exit. Collision shapes persist briefly but don't affect gameplay since placement validation uses SpatialHash, not physics.

**[Risk] BuildMenu button order depends on directory scan order** → `_load_building_types()` scans files alphabetically. After migration, EntityFactory scans `resources/entities/structures/` recursively (GDI and Nod subdirectories). Order may change. **Mitigation**: BuildMenu already handles index-based color mapping with a fallback to GRAY. Order change is cosmetic. Could add an `@export var build_order: int` later if needed.

**[Risk] Missing .tres files for 4 buildings** → Barracks, Refinery, War Factory, Guard Tower need EntityData equivalents. Without them, the build menu will show fewer buildings. **Mitigation**: Create stub .tres files with placeholder values (strength=0, foundation=correct size, cost=0, build_time=0). These match the current BuildingType placeholders which also have cost=0 and build_time=0.

**[Trade-off] `buildable` field adds a bool to every EntityData** → All 10+ existing .tres files need `buildable = false` added (or rely on default). **Mitigation**: Default is `false`, so only the 7 buildable building .tres files need explicit `buildable = true`. Existing files work unchanged.
