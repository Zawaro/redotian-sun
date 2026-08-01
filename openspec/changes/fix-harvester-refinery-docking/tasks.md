## 1. GlobalRules data

- [x] 1.1 Add `@export var bib_cost_penalty: float = 6.0` to the Movement Coefficients group in `scripts/data/GlobalRules.gd`
- [x] 1.2 Add `bib_cost_penalty = 6.0` to `resources/global_rules.tres`

## 2. Bib cells not building cells

- [x] 2.1 In `scripts/components/FoundationComponent.gd` `_ready()`, compute bib cells first and register only the non-bib foundation cells via `register_building_cells` (mirror `BuildingManager.place_building` exclusion); keep `register_bib_cells` for bibs
- [x] 2.2 Confirm `_exit_tree()` unregisters the same non-bib set

## 3. Bib pathfinding penalty

- [x] 3.1 In `scripts/core/Pathfinder.gd` `find_path()`, fetch `GlobalRules.get_current()` once (null-safe) and add `bib_cost_penalty` to `tentative_g` when the neighbor `SpatialHash.instance.is_bib_cell(neighbor)`

## 4. Dock host discovery

- [x] 4.1 In `scripts/components/DockClientComponent.gd`, rewrite `find_nearest_host()` to scan `get_tree().get_nodes_in_group("entities")` for `DockHostComponent`, keeping `can_dock_with`, `dock_types`, and occupancy-penalty distance ranking; drop the `Buildings`-node lookup

## 5. Click routing

- [x] 5.1 In `scripts/hud/MouseHandler.gd` `_handle_left_click_normal()`, in the friendly/neutral-unselected branch, call `OrderSystem.get_orders(...)` first; execute orders if non-empty and return; otherwise `select_entity`

## 6. Tests

- [x] 6.1 Pathfinder: bib cell raises path cost; cheap detour preferred; bib destination still reachable; no rules → no penalty (extend `test/unit/test_pathfinder.gd`)
- [x] 6.2 FoundationComponent/building placement: map-loaded refinery bib cells registered as bib but not building-blocked; non-bib foundation cells blocked; unregister parity (extend `test/integration/test_building_placement.gd`)
- [x] 6.3 `find_nearest_host`: finds map-rooted host (not under `Buildings`), skips incompatible dock types, preserves occupancy ranking, returns null with no host (extend `test/unit/test_dock_client_component.gd`)
- [x] 6.4 Order click routing: friendly unselected DockHost/Resource targets resolve to orders, no-order friendly unit still selects (extend `test/unit/test_unit_order_generator.gd`)
- [x] 6.5 GlobalRules: `bib_cost_penalty` default present and ≥ 4.0 (extend `test/unit/test_global_rules.gd`)

## 7. Verification

- [x] 7.1 Run the full suite: `redot --headless -s test/run_tests.gd` — all tests pass
- [x] 7.2 Run lint/format: `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`; run `grep -P '\t' scripts/**/*.gd` to confirm no tabs
- [x] 7.3 Manual sanity in-editor: select harvester → left-click refinery issues ENTER/dock; full-auto return docks and unloads; ordinary units route around bibs

## 8. Follow-up bug fixes

- [x] 8.1 Fix pre-placed building dock offset: `MapLoader.placement_position()` places BUILDING entities at footprint center (`cell_origin_to_world`) matching the editor, so dock/foundation cells derived from world position line up (was origin-cell center → dock shifted 1 cell)
- [x] 8.2 Fix exiting units paying the bib penalty: `Pathfinder.find_path` gains `ignore_bib_penalty`; `MovementController` passes `unblock_buildings` for building-associated moves (factory exit / rally), so units legitimately crossing their own pad are not penalized
- [x] 8.3 Tests: `test/unit/test_map_loader_placement.gd` (building footprint-center placement, dock alignment, non-building cell center, null-data fallback); pathfinder `ignore_bib_penalty` crossing test; typed the bib-cell arrays in the pathfinder tests that were silently erroring
