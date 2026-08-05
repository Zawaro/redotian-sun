# Design: perf-entity-scalability-cpu-passes

## Context

Steady-state frame cost is proportional to entity count because three systems re-scan the whole entity set every frame and pay allocation + node-lookup churn while doing so:

- `SpatialHash.rebuild()` (`scripts/core/SpatialHash.gd:19-76`) clears 4 dictionaries and repopulates them every physics tick: two `get_nodes_in_group()` array allocations, two `get_node_or_null()` child lookups and one 4-key Dictionary allocation **per entity**, per tick.
- `SelectionManager._synchronize_visual_selection()` (`scripts/core/SelectionManager.gd:201-227`) re-scans the `"selectable"` group every render frame with a `get_node_or_null("SelectComponent")` per entity, to detect selection changes that are already driven by SelectionManager's own API.
- `SelectionOverlay._collect_entities()` (`scripts/ui/SelectionOverlay.gd:46-50, 90-99`) does the same group scan and `queue_redraw()`s both draw nodes unconditionally every frame.

Per-unit floor costs compound this: every idle unit samples terrain and writes `global_position.y` every physics tick (`MovementController.gd:489-494`), and `CellUtil.world_to_cell`/`cell_to_world` fall back to a scene-tree lookup on every call when `grid_cells` is omitted (`CellUtil.gd:27-36`) — the common case.

`TerrainRenderer` and terrain collision are already event-driven and correct; they are untouched. Terrain is static in gameplay.

## Goals / Non-Goals

**Goals:**
- Make steady-state cost allocation-free and lookup-free: no per-frame group-array allocations, no per-frame child-node lookups, no per-frame Dictionary allocations in the three scanning systems.
- Keep all public query semantics identical (`get_entries`, `get_blocked_cells`, shared-cell counts, crush queries, selection list, overlay visuals).
- Reduce per-unit floor cost: idle units stop writing transforms every tick; `CellUtil` stops resolving `grid_cells` through the scene tree on every call.
- Eliminate the worst spikes: Pathfinder per-probe scene-tree lookups + String keys; `CellReservation.release_all` full-claims scan.
- All existing unit/integration tests keep passing; add regression + perf-guard coverage.

**Non-Goals:**
- GPU/rendering budget (SDFGI, shadows, MultiMesh instancing) — separate issue #219.
- Debug-geometry gating — separate issue #219.
- Object pooling of entire unit scenes.
- Physics tick-rate changes or physics interpolation.
- Changes to `EntityData`/resource schemas or packed scene structure.

## Decisions

### D1: SpatialHash — allocation-free reconcile over cached entries, not signals

**Decision:** Replace the per-tick full rebuild with a per-entity **entry registry** (`_entry_map: Dictionary[entity_root, Dictionary]`) built on full rebuild, and a per-tick **reconcile loop** that only corrects drift. Full `rebuild()` runs on entity/ice membership change or explicit `refresh()`, not on position.

- `rebuild()` creates one pooled entry per entity: `{node, mc, stats, entity_type, player_id, cached_cell_key, cached_state, shares}`. The `mc`/`stats` node references are resolved **once** at rebuild time and cached — never re-looked-up per frame. `_grid`, `_blocked_cells`, `_shared_cell_counts`, `_ice_cells` are populated exactly as today (same semantics, same ordering).
- `_physics_process` runs the reconcile loop: iterate `_entry_map.values()` (no group scan, no allocations); for each entry read `world_to_cell(node.global_position)` (O(1) after D4) and `mc._state`/`mc.shares_cell()` off the cached refs; if cell or state differs from `cached_cell_key`/`cached_state`, apply the delta — move the entry between `_grid` keys and flip its blocked/shared contribution. Because all inputs come from cached refs and one arithmetic conversion, the loop is ~constant ops per entity, no heap traffic.
- `rebuild()` is triggered by: entity `tree_entered`/`tree_exited` (add/remove), ice spawn (rare — existing 1-frame window is acceptable, and matches today), and explicit `refresh()` callers (building placement already routes through `register_building_cells`).
- `_entry_map` values are reused dicts; cell moves are remove+append so per-cell entry ordering is preserved.

**Rationale / alternatives considered:**
- *Signal-driven cell/state updates* (emit `cell_changed`/`state_changed` from `MovementController`): avoids even the O(n) iteration, but requires instrumenting every `_state` assignment (risk of a missed transition → stale blocked/shared cells, subtle bugs) and couples MovementController to SpatialHash. The reconcile loop costs ~5-10 ops/entity/tick (~µs at 318 entities) after D4 makes `world_to_cell` allocation-free — negligible next to the allocation churn it removes. Signals rejected as over-coupling for the marginal gain; noted as an upgrade path if profiling later shows reconcile to be a bottleneck.
- *Keep full rebuild but only on change detection:* there is no cheap way to know "something changed" without scanning — reconcile *is* the cheap scan.

### D2: MovementController idle snap — snap on cell change only

**Decision:** In the `State.IDLE` branch (non-jumpjet), cache the last snapped cell key. Only when `world_to_cell(global_position)` differs from the cached key (or on entry into IDLE) recompute the terrain height and write `global_position.y`. Jumpjet vertical update is unchanged (it is animation-driven).

**Rationale:** Terrain height is static per cell, so within a cell the y-write is a no-op that still dirties the transform and forces a GPU re-upload. A forced snap runs when a unit transitions into IDLE and when it is externally displaced (crush, dock, editor), so correctness is preserved without per-tick writes.

### D3: SelectionManager — event-driven sync with a slow safety net

**Decision:** Remove the per-frame `_synchronize_visual_selection()` call from `_process`. Instead:
- `SelectComponent.set_is_selected()` emits `selection_state_changed`; SelectionManager connects per-entity when it starts tracking the entity and reconciles that single entity on signal.
- Keep `_synchronize_visual_selection()` as a **10 Hz safety net** (once per 6 render frames) to reconcile external direct writes to `is_selected` — preserving the existing spec scenario ("visual selection out of sync") without paying O(n) every frame.

**Rationale / alternatives:**
- *Full signal-only:* the existing spec explicitly covers "selection state modified externally" — direct property writes cannot be intercepted in GDScript, so a poll safety net is required. 10 Hz is well above input rate and keeps the O(n) cost 10x rarer; combined with signal-driven per-entity sync the common path costs O(1).

### D4: CellUtil — cached grid resolution

**Decision:** Add a process-wide static cache: `_cached_grid_cells` + a validity flag. `_resolve_grid_cells(grid_cells)` returns the cached value when valid; on first call it does the current tree lookup and caches it (including the 50,50 fallback). `TerrainSystem` calls `CellUtil.notify_grid_changed()` from `init_grid()` and `_enter_tree()` to invalidate. The explicit-arg fast path is unchanged and takes precedence.

**Rationale:** `grid_cells` changes only on grid init / map load; a static cache eliminates ~1-2k scene-tree lookups per frame at 200 entities while keeping the API identical. Invalidation on `_enter_tree` covers editor scene reuse and test teardown.

### D5: ProductionManager — cached per-queue speed

**Decision:** Cache production speed (and the factory count/primary inputs) per `queue_key`; invalidate on `FactoryComponent` add/remove/`set_primary` signals. `_find_factories()` remains for the event-driven spawn path only.

**Rationale:** The speed formula requirement is unchanged; only its recomputation cadence changes (once per factory-list change instead of per frame per queue).

### D6: SelectionOverlay — redraw from a small tracked list, not the group

**Decision:** Maintain the overlay's `_entities` list from SelectionManager's `selection_changed`/`hover_changed` signals and HealthComponent health-changed signals, replacing the per-frame `get_nodes_in_group("selectable")` scan. Per-frame `queue_redraw()` stays (brackets must track moving selected units), but the work is O(selected+hover), not O(all entities). Optionally gate the health-bar redraw node to a dirty flag.

**Rationale:** The O(n) cost was the group scan + per-entity node lookup, not the redraw. Signal-maintained lists collapse it to O(selection), which is small and exactly the set that changes per frame.

### D7: Pathfinder — terrain height fast path

**Decision:** In `find_path`, resolve `terrain` and `grid_cells` once. Replace `_cell_height(terrain, cell)` (which does `cell_to_world` → `world_to_cell` → `get_cell` → String-keyed dict lookup) with `CellUtil.cell_to_world(cell, grid_cells)` + `terrain.get_height_at_world_smooth(world_pos)` (pure arithmetic, 4 vertex reads, no dict/string). Cache the current node's height across iterations so it is computed once, not once as neighbor and again as current.

**Rationale:** `get_height_at_world_smooth` already exists and is the documented cheap read; this removes up to ~27k scene-tree lookups + ~13.5k String allocations in the worst-case pathfind.

### D8: CellReservation — per-claimant index

**Decision:** Maintain `_claimant_cells: Dictionary[claimant, Dictionary[cell_key, bool]]`, updated in `reserve_sub_slot`/`release_sub_slot`. `release_all(claimant)` iterates only the claimant's own cell keys, erasing claims, then removes the now-empty claimant entry. Capacity logic is unchanged.

**Rationale:** `release_all` today scans every cell with in-flight claims — O(C) per reservation, quadratic under mass infantry orders. The index makes it O(claims-of-claimant) = O(1) in practice.

## Risks / Trade-offs

- [Stale blocked/shared cells if reconcile misses a transition] → reconcile reads live `mc._state`/`shares_cell()` off cached refs every tick, so any drift self-heals within one tick; no new signals to get wrong.
- [Grid-cache stale after map reload/test teardown] → invalidated on `TerrainSystem.init_grid()` and `_enter_tree()`; tests that build bare `CellUtil` use the cached 50,50 fallback deterministically.
- [Selection list missed an external `is_selected` write between signal and safety poll] → bounded to ≤100 ms by the 10 Hz reconcile; same eventual consistency as the spec scenario requires.
- [Incremental SpatialHash changes entry ordering under moves] → cell move is remove+append, preserving order per cell; existing spatial-hash tests pin the query results and must pass unchanged.
- [Perf-guard test flakiness] → perf guard asserts *allocation/scan counts* (inspectable, deterministic) rather than wall-clock frame time; wall-clock measurement stays manual via a debug overlay.
- [Trade-off] → SpatialHash remains an O(n) *iteration* per tick (reconcile), just allocation-free and lookup-free. Fully signal-driven removal of even that O(n) is deferred; revisit only if profiling shows reconcile as a bottleneck at scale.

## Migration Plan

- Internal only; no scene, resource, or API changes. Each decision is a self-contained refactor with its existing test suite as the regression gate.
- Rollback: revert the change branch; none of the changes touch persistent data.

## Open Questions

- None blocking. (Confirm perf-guard style with reviewer during apply: assert scan/alloc counts vs. optional FPS overlay.)
