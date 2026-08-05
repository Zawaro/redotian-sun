# Tasks: perf-entity-scalability-cpu-passes

## 1. CellUtil cached grid resolution (D4 — foundation)

- [x] 1.1 Add static `_cached_grid_cells: Vector2i` + validity flag to `CellUtil`; make `_resolve_grid_cells()` return the cache when valid and populate it on first call (including the 50,50 fallback); keep the explicit-arg fast path taking precedence.
- [x] 1.2 Add `CellUtil.notify_grid_changed()` that invalidates the cache; call it from `TerrainSystem.init_grid()` and `TerrainSystem._enter_tree()`.
- [x] 1.3 Verify `world_to_cell`/`cell_to_world`/`cell_origin_to_world` still pass all existing `CellUtil` unit tests; add a test asserting the cache is invalidated by `notify_grid_changed()`.

## 2. SpatialHash incremental reconcile (D1)

- [x] 2.1 Add `_entry_map: Dictionary` keyed by entity root; `rebuild()` creates a pooled entry per entity (`node`, cached `mc`/`stats` refs, `entity_type`, `player_id`, `cached_cell_key`, `cached_state`, `shares`) and populates `_grid`/`_blocked_cells`/`_shared_cell_counts`/`_ice_cells` exactly as today.
- [x] 2.2 Replace `_physics_process` full rebuild with a reconcile loop: for each `_entry_map` value, compare current `world_to_cell(node.global_position)` and `mc._state`/`mc.shares_cell()` to cached values; apply cell-move (remove+append) and blocked/shared flips only on difference. No group scans, no node lookups, no per-entity allocations.
- [x] 2.3 Trigger full `rebuild()` on entity/ice membership change (tree signals) and keep explicit `refresh()` path; ensure runtime-spawned ice still registers.
- [x] 2.4 Confirm all existing `test/unit` spatial-hash tests pass unchanged; add reconcile tests: entry moves cell, IDLE↔MOVING flips blocked/shared, entry ordering preserved, query parity vs full rebuild.

## 3. MovementController idle snap on cell change (D2)

- [x] 3.1 In the `State.IDLE` non-jumpjet branch, cache the last snapped cell key; recompute terrain height and write `global_position.y` only when the cell changed or on entry to IDLE. Force a snap on external displacement (crush/dock/editor) paths.
- [x] 3.2 Verify existing movement tests pass; add a test that an idle unit in the same cell does not rewrite `global_position.y`.

## 4. SelectionManager event-driven sync (D3)

- [x] 4.1 Emit a `selection_state_changed` signal from `SelectComponent.set_is_selected()`.
- [x] 4.2 Connect it in SelectionManager for tracked entities and reconcile that single entity on signal; remove the per-frame `_synchronize_visual_selection()` call from `_process`.
- [x] 4.3 Keep `_synchronize_visual_selection()` as a ≤10 Hz safety net for direct `is_selected` writes.
- [x] 4.4 Verify existing `test/unit` selection-manager tests pass; add tests for event-driven sync (same-frame add/remove) and the ≤100 ms external-mutation reconcile.

## 5. SelectionOverlay tracked entity list (D6)

- [x] 5.1 Maintain the overlay's `_entities` list from SelectionManager `selection_changed`/`hover_changed` signals and HealthComponent health-changed signals instead of scanning the `"selectable"` group each frame; keep per-frame `queue_redraw()` for the small selected set.
- [x] 5.2 Verify brackets, pips, and health bars still render for selected/hovered entities; add a test that the overlay no longer scans the whole group per frame.

## 6. ProductionManager cached per-queue speed (D5)

- [x] 6.1 Add add/remove/`set_primary` signals to `FactoryComponent` (emit on ready, exit, and primary change).
- [x] 6.2 Cache production speed per `queue_key` in `ProductionManager`; invalidate the affected player/factory-type cache entries on those signals; keep `_find_factories()` for the spawn path only.
- [x] 6.3 Verify existing `test/unit` production-manager tests pass (speed formula unchanged); add a cache-invalidation test (factory destroyed → speed recomputed).

## 7. Pathfinder terrain height fast path (D7)

- [x] 7.1 Resolve `terrain` and `grid_cells` once per `find_path`; replace `_cell_height` per-probe scene-tree/dict/string lookups with `CellUtil.cell_to_world(cell, grid_cells)` + `terrain.get_height_at_world_smooth()`.
- [x] 7.2 Cache the current node's height across A* iterations (computed once, reused as current from previous neighbor pass).
- [x] 7.3 Verify existing `test/unit` pathfinder tests pass unchanged (cost/heuristic results identical); add a fast-path equality test vs the old lookup.

## 8. CellReservation per-claimant index (D8)

- [x] 8.1 Maintain `_claimant_cells: Dictionary[claimant, Dictionary[cell_key, bool]]` in `reserve_sub_slot`/`release_sub_slot`; `release_all(claimant)` iterates only the claimant's own cells and prunes empty entries.
- [x] 8.2 Verify existing `test/unit` cell-reservation tests pass unchanged; add a test that `release_all` only touches the claimant's cells.

## 9. Perf guard

- [ ] 9.1 Add a `test/unit` perf-guard test asserting the per-frame SpatialHash reconcile performs no group-array allocations / child-node lookups for N entities (deterministic counters, not wall-clock).
- [ ] 9.2 Add the same scan/alloc guard for SelectionManager and SelectionOverlay (no per-frame `get_nodes_in_group`).
- [x] 9.3 Run the full suite via `redot --headless -s test/run_tests.gd` and confirm all pass.

## 10. Final verification

- [x] 10.1 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`; fix issues; check for tabs after format.
- [ ] 10.2 Launch in the Redot editor on TestMap01 and eyeball selection/brackets/movement; confirm no regression.
- [ ] 10.3 Update the OpenSpec change status and prepare for archive after merge.
