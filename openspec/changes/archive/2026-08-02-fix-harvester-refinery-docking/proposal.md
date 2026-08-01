## Why

Harvester → refinery docking is broken end-to-end: left-clicking the refinery with a harvester selected only selects the building (dock cursor never issues the order), auto-return can't find the refinery (`find_nearest_host` scans a `Buildings` node that map-loaded buildings never join), and even when the harvester reaches the refinery it parks in front because the dock cell is a bib cell now registered as a blocked building cell. The local player (regression from #173 / #165 work) and the AI enemy (#165) are both affected, so resource income for every faction is dead.

## What Changes

- **MouseHandler click routing**: clicking a friendly/neutral unselected selectable entity while units are selected consults `OrderSystem.get_orders` *before* falling back to selection, so dock/harvest orders issue on left-click (restores the pre-`f1c631d` interact behavior through the modern order pipeline).
- **Dock host discovery**: `DockClientComponent.find_nearest_host` scans the `entities` group for `DockHostComponent` instead of `current_scene/Buildings`, so map-loaded, player-built, and MCV-deployed refineries are all discoverable.
- **Bib cells are no longer building cells**: `FoundationComponent._ready` registers only non-bib foundation cells as `_building_cells` (mirroring `BuildingManager.place_building`), fixing the #173 inconsistency that blocked the refinery dock pad.
- **Bib pathfinding penalty**: `Pathfinder` adds a tunable cost surcharge for traversing bib cells (new `GlobalRules.bib_cost_penalty`), so regular traffic routes around bibs while harvesters (and units needing the dock) still pass through. Bib cells remain reachable — they are penalized, not hard-blocked.

## Capabilities

### New Capabilities
- `bib-pathfinding-penalty`: bib cells incur an extra pathfinding cost configured via `GlobalRules`, so ordinary traffic detours around them while dockers and emergency crossers can still pass.

### Modified Capabilities
- `dock-host-client`: `find_nearest_host` SHALL locate compatible dock hosts across the whole scene (entities group), not only under a `Buildings` node.
- `order-system`: clicking a friendly/neutral unselected selectable entity SHALL route through the order system first, issuing dock/harvest orders when available before falling back to selection.
- `spatial-hash`: `FoundationComponent` SHALL register only non-bib foundation cells as building cells; bib cells SHALL remain bib-tracked only.

## Impact

- `scripts/hud/MouseHandler.gd` — click resolution branch for friendly/neutral unselected entities.
- `scripts/components/DockClientComponent.gd` — `find_nearest_host` source of hosts.
- `scripts/components/FoundationComponent.gd` — `_ready()` building-cell registration excludes bibs.
- `scripts/core/Pathfinder.gd` — bib-cell cost penalty in A* cost accumulation.
- `scripts/data/GlobalRules.gd` + `resources/global_rules.tres` — new `bib_cost_penalty` export.
- Tests: `test/unit/test_pathfinder.gd`, `test/unit/test_dock_client_component.gd`, `test/integration/test_building_placement.gd`, `test/unit/test_unit_order_generator.gd`, `test/unit/test_global_rules.gd` (add coverage; adjust any bib-blocking assertions).
- Specs: `openspec/specs/dock-host-client`, `openspec/specs/order-system`, `openspec/specs/spatial-hash`, plus new `bib-pathfinding-penalty`.
