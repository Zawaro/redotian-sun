## Context

Harvester → refinery docking is broken in three independent layers:

1. **Click**: `MouseHandler._handle_left_click_normal` (Pass 1, layer 16) hits the refinery's `SelectComponent`. Since it's friendly, unselected, and has a select component, the handler calls `select_entity` and returns — `OrderSystem.get_orders` is never consulted (`MouseHandler.gd:248`). The cursor path (`OrderSystem.get_cursor` → `HarvestComponent.get_order_for_target`) correctly returns ENTER, so cursor and click disagree. Regression from `f1c631d` (removed `_try_interact`) and `7d86cb2` (kept the friendly→select branch).
2. **Discovery**: `DockClientComponent.find_nearest_host` scans `current_scene.get_node_or_null("Buildings")` (`DockClientComponent.gd:268`). `MapLoader.load_map_into` adds entities to the map root, so the refinery is a sibling of `Buildings`, never a child. Result: null → `dock_slot_failed` → DELIVERING retry → harvester stops at the field (#165).
3. **Reachability**: `FoundationComponent._ready` registers **all** foundation cells — including bib cells — as `_building_cells` (`FoundationComponent.gd:25-27`). `BuildingManager.place_building:176` excludes bib cells. For GDI_REFINERY (foundation 4×3, bib `(3,0),(3,1),(3,2)`, `dock_position (6,0,2)`), the dock cell `(68,58)` is bib `(3,1)` → the dock pad is a blocked building cell → the harvester parks in front. Regression from `66a4be1` (#173).

Bib cells already have a tracking layer (`SpatialHash._bib_cells`, `is_bib_cell`), and callers already avoid them for placement (`BuildingManager._is_cell_free`), exit cells (`ExitComponent`/`FactoryComponent`), and wait cells (`DockHostComponent.find_wait_cell`). The only places treating bib as hard-blocked are the `FoundationComponent` registration and, transitively, pathfinding.

## Goals / Non-Goals

**Goals:**
- Left-clicking a refinery (or tiberium) with a compatible unit selected issues the dock/harvest order.
- Auto-return (`seek_dock`) finds map-loaded, player-built, and MCV-deployed refineries alike.
- The refinery dock cell is reachable: harvesters path onto it and unload.
- Regular traffic avoids bib pads (they are short-cut strips around buildings), while dockers and emergency crossers can still traverse them.
- Everything driven by data/tests; no scene-structure coupling for host discovery.

**Non-Goals:**
- No AI/opponent build-order work beyond the docking loop itself.
- No changes to `DockHostComponent` queue/promotion/timing logic.
- No new movement orders or formation systems.
- No multiplayer/serialization changes.

## Decisions

### D1. Bib cells: penalized, not blocked (pathfinding)
Bib cells stay tracked in `_bib_cells` and are **removed** from `_building_cells` registration. `Pathfinder.find_path` adds a per-cell surcharge when a neighbor `is_bib_cell`.

- **How**: in `find_path`, when computing `tentative_g` (`Pathfinder.gd:144`), add `rules.bib_cost_penalty` (via `GlobalRules.get_current()`) when the neighbor is a bib cell. The penalty is additive to cost, not a reachability gate — A* still enters the dock cell (its destination) and still finds an emergency route across, just paying the tax.
- **Why not hard-block**: hard-blocking is what caused the bug — the dock cell *is* a bib cell, so any unit docking must traverse it. A penalty preserves reachability while keeping regular traffic off.
- **Alternatives considered**: (a) keep bib blocked and special-case dock cells — rejected, couples movement to dock internals and leaves the "emergency crossing" gap; (b) block only non-dock bib cells — rejected, requires per-building knowledge in the pathfinder.

### D2. Penalty value is data, not code
`bib_cost_penalty` lives in `GlobalRules` (`@export_group("Movement Coefficients")`), defaulting to a value comfortably above a detour cost. The pathfinder reads it via the existing `GlobalRules.get_current()` accessor (null-safe: tests/editor fall back to no penalty).

- **Why**: tunable per-map/global config without code changes; consistent with other movement coefficients (`tracked_uphill`, `ice_cracking_weight`).
- **Default choice**: ~6.0 (cost basis is ~1.0 per cell; a 2-cell bib strip costs ~12 to cross, so a 3-4 cell detour at ~4 is cheaper, while a harvester whose destination is the dock pays it once). Exact value validated by the pathfinder test.

### D3. Host discovery scans the `entities` group
`find_nearest_host` iterates `get_tree().get_nodes_in_group("entities")`, filters nodes with a `DockHostComponent`, applies the existing `can_dock_with` + `dock_types` filters, and keeps the `occupancy_penalty` distance ranking.

- **Why**: the `entities` group is populated by `EntityFactory` for every entity regardless of parent (`EntityFactory.gd:120`), so map-loaded (map root), player-built (`Buildings` node), and MCV-deployed (current scene) buildings all appear. No reliance on a specific parent node name.
- **Alternatives considered**: reparent map-loaded buildings under `Buildings` in `MapLoader` — rejected, couples map loading to scene layout and leaves MCV-deploy (which adds to `current_scene` per `DeployComponent`) uncovered.

### D4. Click routing: orders before selection for friendly/neutral
In `_handle_left_click_normal`, the friendly/neutral-unselected branch calls `OrderSystem.get_orders(target, target_cell, target_pos, modifiers)` first; if non-empty, execute and return; only otherwise `select_entity`.

- **Why**: restores the pre-`f1c631d` `_try_interact` behavior through the existing order pipeline — the same mechanism the cursor already uses, so cursor and click agree by construction.
- **Why safe**: for a plain friendly unit (no harvest/dock), `get_order_for_target` on each component returns null (`MovementController` returns null for a non-null target; `HarvestComponent` only matches Resource/DockHost), so the order list is empty and selection still happens. The enemy branch already follows this pattern.
- **Alternatives considered**: re-introduce a bespoke `_try_interact` — rejected, duplicates order logic and drifts from the spec'd `get_order_for_target` contract.

### D5. `FoundationComponent._ready` mirrors `place_building`
`_ready` registers foundation cells excluding `_registered_bib_cells` (computed once, used for both the building-cell set and the bib-cell set), exactly like `BuildingManager.place_building:172-185`. Bib cells are still registered via `register_bib_cells`.

## Risks / Trade-offs

- [Penalty too low → regular traffic still cuts across bibs] → Default 6.0 and a pathfinder test asserting a cheap detour is preferred; value is data-driven for later tuning.
- [Penalty too high → harvesters from an awkward angle take a long detour to reach the dock] → Dock cell is the A* destination; the penalty taxes transit, and the final approach into the dock is one short leg. Test asserts a bib-destination path is still found (non-empty).
- [`find_nearest_host` scans more nodes than before] → O(entities) per seek is already the cost profile (host lookup is per-harvester, not per-frame); SpatialHash already iterates the group each physics frame.
- [Click routing change affects non-dock friendly clicks] → Covered by the existing cursor/order tests plus a new friendly-click branch test: orders empty → select still occurs.
- [Existing tests assert bib cells block pathfinding] → Audit `test_pathfinder`, `test_building_placement`, `test_spatial_hash`; adjust only assertions that codified the #173 bug (bib = blocked), per the requirement to change expectations only when the documented requirement changes.

## Migration Plan

No runtime migration — behavior change only. Land as one commit series on `fix/165-enemy-harvester-finds-refinery`:
1. `GlobalRules.bib_cost_penalty` (+ `.tres` default).
2. FoundationComponent bib exclusion + `place_building` parity.
3. Pathfinder bib penalty.
4. `find_nearest_host` group scan.
5. MouseHandler click routing.
6. Tests + spec updates.
Rollback: revert the branch; each commit is independent and the penalty default preserves reachability.

## Open Questions

- Exact default value for `bib_cost_penalty` (start 6.0, confirm against the pathfinder test's detour geometry).
- Whether `DockHostComponent.find_wait_cell`/`is_cell_available` should also treat bib as un-available (currently they already exclude bib via `is_bib_cell` in `find_wait_cell`) — no change expected, but confirmed during implementation.
