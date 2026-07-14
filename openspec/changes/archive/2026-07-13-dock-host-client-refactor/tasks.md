## 1. Resource Type System

- [x] 1.1 Create `scripts/data/ResourceType.gd` with id, display_name, category, parent_type, value_per_unit, color exports
- [x] 1.2 Create `resources/resource_types/` directory and tiberium.tres (category), tiberium_green.tres, tiberium_blue.tres, tiberium_red.tres, vein.tres
- [x] 1.3 Update `scripts/data/GlobalRules.gd` — add `resource_types: Dictionary` export, helper methods (get_resource_type, get_resource_category, get_subtypes), remove `tiberium_value`
- [x] 1.4 Update `resources/global_rules.tres` — add resource_types dictionary entries, remove tiberium_value

## 2. EntityData Updates

- [x] 2.1 Update `scripts/data/EntityData.gd` — remove `tiberium_type: int`, add `resource_type_id: String`; remove `storage: int`, add `resource_capacity: int`; add `accepted_resource_categories: PackedStringArray`
- [x] 2.2 Update `resources/entities/terrain/tiberium_crystal.tres` — `tiberium_type = 0` → `resource_type_id = "tiberium_green"`
- [x] 2.3 Update `resources/entities/terrain/tiberium_tree.tres` — add `resource_type_id = "tiberium_green"`
- [x] 2.4 Update `resources/entities/vehicles/gdi_harvester.tres` — `storage = 700` → `resource_capacity = 700`
- [x] 2.5 Update `resources/entities/structures/gdi/gdi_refinery.tres` — add `accepted_resource_categories = ["tiberium"]`

## 3. DockHostComponent (rename from DockComponent)

- [x] 3.1 Rename `scripts/components/DockComponent.gd` → `DockHostComponent.gd`, update class_name
- [x] 3.2 Remove `foundation` export, add `_get_foundation()` helper reading from FoundationComponent sibling
- [x] 3.3 Remove `allowed_entities` export, add `dock_types: PackedStringArray = []`
- [x] 3.4 Add `max_queue_length: int = 3` and `dock_wait_ticks: int = 10` exports
- [x] 3.5 Add queue length check in `request_dock()` — return false when queue full
- [x] 3.6 Add wait timer logic — `_wait_counter`, `_pending_dockers`, emit `docker_docked` after `dock_wait_ticks` for queued dockers
- [x] 3.7 Add `get_queue_size() -> int` and `has_dock_type(type: String) -> bool` methods
- [x] 3.8 Update `_compute_dock_cell()` to use `_get_foundation()` instead of stored `foundation`

## 4. DockClientComponent (new)

- [x] 4.1 Create `scripts/components/DockClientComponent.gd` with `can_dock_with`, `occupancy_penalty`, `search_radius_cells` exports
- [x] 4.2 Implement `configure(dock_id: String)` — sets `can_dock_with = [dock_id]`
- [x] 4.3 Implement `find_nearest_host(parent, exclude)` — searches Buildings group, filters by can_dock_with, applies occupancy penalty to distance
- [x] 4.4 Implement `try_reserve_dock(parent)` — find nearest → request_dock → try next if fail → emit dock_slot_reserved or dock_slot_failed
- [x] 4.5 Implement `release_reservation()`, `on_slot_available()`, `is_reserved()`, `get_dock_id()`
- [x] 4.6 Add signals: `dock_slot_reserved(host)`, `dock_slot_failed`

## 5. RefineryComponent (new)

- [x] 5.1 Create `scripts/components/RefineryComponent.gd` with `accepted_resource_categories` and `unload_rate` exports

## 6. TransportComponent Generalization

- [x] 6.1 Update `scripts/components/TransportComponent.gd` — change `cargo: int = 0` to `cargo: Dictionary = {}`, rename `storage` to `resource_capacity`
- [x] 6.2 Add helpers: `get_cargo_total()`, `get_cargo_value(global_rules)`, `add_cargo(type_id, amount)`, `remove_cargo(type_id, amount)`

## 7. TiberiumComponent + TiberiumTreeComponent

- [x] 7.1 Update `scripts/components/TiberiumComponent.gd` — `tiberium_type: int` → `resource_type_id: String = "tiberium_green"`, update `configure()`
- [x] 7.2 Update `scripts/components/TiberiumTreeComponent.gd` — `tiberium_type: int` → `resource_type_id: String = "tiberium_green"`, update `configure()`

## 8. EntityFactory Updates

- [x] 8.1 Rename `DOCK_COMPONENT_SCRIPT` → `DOCK_HOST_COMPONENT_SCRIPT`, update preload path and component name to "DockHostComponent"
- [x] 8.2 Add `DOCK_CLIENT_COMPONENT_SCRIPT` and `REFINERY_COMPONENT_SCRIPT` preloads
- [x] 8.3 Rename `_add_dock_component()` → `_add_dock_host_component()`, update condition to `data.dock_position != Vector3.ZERO`
- [x] 8.4 Add `_add_dock_client_component()` — when `data.dock != ""`
- [x] 8.5 Add `_add_refinery_component()` — when `data.accepted_resource_categories.size() > 0`
- [x] 8.6 Update `_add_components()` to call new methods

## 9. DockUnloadComponent Updates

- [x] 9.1 Replace all `DockComponent` → `DockHostComponent` references in `scripts/components/DockUnloadComponent.gd`
- [x] 9.2 Update `_process()` to iterate `transport.cargo` dictionary, look up `GlobalRules.get_resource_type(type_id).value_per_unit`, credit per type
- [x] 9.3 Check RefineryComponent `accepted_resource_categories` before unloading

## 10. HarvestComponent Simplification

- [x] 10.1 Remove dock-finding logic from `scripts/components/HarvestComponent.gd` — delete `_find_nearest_dock()`, `_try_dock()`, `_orient_to_dock()`, `_get_dock_target_pos()`
- [x] 10.2 Add `harvestable_types: PackedStringArray = ["tiberium"]` export
- [x] 10.3 Rename `_find_nearest_tiberium()` → `_find_nearest_resource()` — filter by `GlobalRules.get_resource_category(tib.resource_type_id) in harvestable_types`
- [x] 10.4 Add DockClientComponent reference, connect `dock_slot_reserved` and `dock_slot_failed` signals
- [x] 10.5 Update FULL state to call `dock_client.try_reserve_dock()` instead of `_try_dock()`
- [x] 10.6 Update `get_cargo()`/`set_cargo()` to use Dictionary from TransportComponent

## 11. Reference Updates

- [x] 11.1 Update `scripts/hud/MouseHandler.gd` — `"DockComponent"` → `"DockHostComponent"`
- [x] 11.2 Update `scripts/core/SelectionManager.gd` — `DockComponent` type → `DockHostComponent`
- [x] 11.3 Update `scripts/components/FreeUnitComponent.gd` — `_find_nearest_tiberium()` → `_find_nearest_resource()`
- [x] 11.4 Update `scripts/core/TiberiumGrowthSystem.gd` — `tiberium_type` → `resource_type_id` in overrides dict
- [x] 11.5 Update `scripts/editor/MapEditor.gd` — `tiberium_type` → `resource_type_id` in overrides dict
- [x] 11.6 Update `scripts/maps/MapLoader.gd` — `tiberium_type` → `resource_type_id` in override key list

## 12. Pathfinding Resource Search

- [x] 12.1 Update `_find_nearest_resource()` to use `Pathfinder.find_path()` distance instead of straight-line
- [x] 12.2 Add pathfinding result cache to avoid recomputing every frame

## 13. Tests

- [x] 13.1 Update `test/unit/test_harvest_dock.gd` — rename DockComponent refs to DockHostComponent, add DockClientComponent to test entity helpers
- [x] 13.2 Update `test/unit/test_tiberium_component.gd` — `tiberium_type` → `resource_type_id`
- [x] 13.3 Update `test/unit/test_tiberium_tree_component.gd` — `tiberium_type` → `resource_type_id`
- [x] 13.4 Add new tests for DockClientComponent (find_nearest_host, try_reserve, occupancy penalty)
- [x] 13.5 Add new tests for queue length limit and dock wait timer
- [x] 13.6 Add new tests for resource type hierarchy (get_resource_category, get_subtypes)
- [x] 13.7 Add new tests for multi-type cargo (add_cargo, remove_cargo, get_cargo_value)

## 14. Lint & Format

- [x] 14.1 Run `gdlint` on all modified/new .gd files
- [x] 14.2 Run `gdformat --check` on all modified/new .gd files
- [x] 14.3 Run `grep -P '\t'` to verify no tab introduction

## 15. TransportComponent Signals + Passenger Tracking

- [x] 15.1 Add `cargo_changed(current: int, capacity: int, type_id: String)` signal to TransportComponent
- [x] 15.2 Add `passenger_changed(current: int, max_passengers: int)` signal to TransportComponent
- [x] 15.3 Add `current_passengers: int = 0` variable to TransportComponent
- [x] 15.4 Add `add_passenger() -> bool` method with capacity check
- [x] 15.5 Add `remove_passenger() -> bool` method with empty check
- [x] 15.6 Emit `cargo_changed` from `add_cargo()` and `remove_cargo()`

## 16. SelectComponent Cargo/Passenger Pips

- [x] 16.1 Add pip constants: PIP_SIZE=0.12, PIP_OUTLINE_SIZE=0.15, MAX_CARGO_PIPS=5, MAX_PASSENGER_PIPS=5
- [x] 16.2 Add pip state arrays: `_cargo_pips`, `_cargo_outlines`, `_passenger_pips`, `_passenger_outlines`
- [x] 16.3 Add `_create_pip()` helper — creates outline (black, 0.15) + fill (colored, 0.12) QuadMesh pair, billboarded
- [x] 16.4 Add `_setup_transport_pips()` — called via `call_deferred()` in Vehicle `_ready()`, gets TransportComponent, connects signals, creates pip quads
- [x] 16.5 Add `_on_cargo_changed()` signal handler — updates pip fill colors based on cargo ratio and ResourceType.color
- [x] 16.6 Add `_on_passenger_changed()` signal handler — updates pip fill colors (white=occupied, gray=empty)
- [x] 16.7 Position pips: centered row below selection box, spacing = PIP_OUTLINE_SIZE * 1.5

## 17. Lint & Format (Phase 15-16)

- [x] 17.1 Run `gdlint` on TransportComponent.gd and SelectComponent.gd
- [x] 17.2 Run `gdformat --check` on TransportComponent.gd and SelectComponent.gd
- [x] 17.3 Run `grep -P '\t'` to verify no tab introduction
