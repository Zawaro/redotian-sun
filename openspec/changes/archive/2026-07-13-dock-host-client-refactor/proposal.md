## Why

The current dock/harvest system has a monolithic DockComponent that handles both host (building) and client (unit) concerns, no queue limits, no reservation-before-movement, and a single integer for cargo. Tiberium types are bare ints with no hierarchy. This blocks multi-type tiberium (green/blue/red), weed eaters, service depot repair, and proper harvester distribution across refineries.

## What Changes

- **BREAKING**: Rename `DockComponent` → `DockHostComponent` (on buildings). Remove `allowed_entities`, add `dock_types`, `max_queue_length`, `dock_wait_ticks`. Read `foundation` from FoundationComponent sibling instead of storing its own copy.
- **New**: `DockClientComponent` (on units) — handles dock-finding, reservation-before-movement, occupancy-aware host selection. Specifies `can_dock_with` by entity ID.
- **New**: `RefineryComponent` (on refinery buildings) — declares `accepted_resource_categories` (e.g. `["tiberium"]`). Separate from DockUnloadComponent (data vs logic).
- **New**: `ResourceType` resource class + `.tres` files for resource type hierarchy (parent categories + sub-types with value_per_unit, color).
- **BREAKING**: `TransportComponent.cargo` changes from `int` to `Dictionary` (`{resource_type_id: amount}`). `storage` → `resource_capacity`.
- **BREAKING**: `TiberiumComponent.tiberium_type: int` → `resource_type_id: String`. Same for `TiberiumTreeComponent`.
- **BREAKING**: `EntityData` — remove `tiberium_type`, `storage`, `dock` fields. Add `resource_type_id`, `resource_capacity`, `accepted_resource_categories`.
- **BREAKING**: `GlobalRules` — remove `tiberium_value`. Add `resource_types: Dictionary` with helper methods.
- HarvestComponent simplified: removes all dock-finding logic, delegates to DockClientComponent. Adds `harvestable_types` (category-based). Renames `_find_nearest_tiberium()` → `_find_nearest_resource()`.
- **New**: TransportComponent signals (`cargo_changed`, `passenger_changed`) + `current_passengers` tracking for real-time UI.
- **New**: SelectComponent cargo/passenger pips — small colored QuadMesh pairs below vehicle selection rectangle showing fill level. Cargo pips use `ResourceType.color`, passenger pips use white.
- All `.tres` files updated to new field names.

## Capabilities

### New Capabilities
- `dock-host-client`: DockHost/DockClient component pair — queue management, reservation-before-movement, occupancy-aware selection, dock types
- `resource-type-system`: ResourceType resource class, parent/sub-type hierarchy, GlobalRules registry, category-based matching
- `refinery-component`: RefineryComponent — declares accepted resource categories for dock buildings
- `transport-pip-display`: SelectComponent cargo/passenger pips — real-time visual feedback for transport fill level

### Modified Capabilities
- `tiberium-harvesting`: TiberiumComponent uses `resource_type_id: String` instead of `tiberium_type: int`
- `tiberium-tree`: TiberiumTreeComponent uses `resource_type_id: String`
- `entity-data`: Remove `tiberium_type`, `storage`, `dock`. Add `resource_type_id`, `resource_capacity`, `accepted_resource_categories`
- `global-rules`: Remove `tiberium_value`. Add `resource_types: Dictionary` with lookup helpers
- `entity-factory`: Create DockHostComponent, DockClientComponent, RefineryComponent. Rename DockComponent refs
- `tiberium-growth-system`: Pass `resource_type_id` instead of `tiberium_type` when spawning crystals
- `map-editor-tiberium`: Use `resource_type_id` in overrides dict
- `map-loader`: Use `resource_type_id` in override key list
- `free-unit`: Call `_find_nearest_resource()` instead of `_find_nearest_tiberium()`

## Impact

- **Scripts**: 20 files modified/created across components/, data/, entities/, core/, editor/, maps/, hud/
- **Resources**: 5 new `.tres` files (resource_types/), 6 existing `.tres` updated
- **Tests**: 3 test files updated, new tests for DockClientComponent, resource type hierarchy, queue limits
- **Scenes**: No `.tscn` changes — all components are script-attached by EntityFactory at runtime
- **Data format**: `.tres` entity files use new field names (hard break, no migration)
- **Specs**: 1 new spec (transport-pip-display) with 7 requirements
