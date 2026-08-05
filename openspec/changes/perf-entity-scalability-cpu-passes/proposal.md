# Proposal: perf-entity-scalability-cpu-passes

## Why

The frame is CPU-bound by three full-entity passes running every frame — `SpatialHash.rebuild()`, `SelectionManager._synchronize_visual_selection()`, and `SelectionOverlay._collect_entities()` each scan all entities and allocate per-entity dictionaries/arrays. At ~318 entities (TestMap01) and above, these O(n) passes plus per-unit floor costs (idle terrain sampling, per-call scene-tree lookups in `CellUtil`) dominate steady-state frame time and grow linearly with entity count — the main scaling wall for battles.

## What Changes

- `SpatialHash` stops rebuilding the entire grid every physics tick. It updates incrementally when a unit's cell changes (position-diff), and does a full rebuild only on entity membership changes (add/remove) and ice spawn. Entry dictionaries are pooled and child node references are cached, not looked up per frame. Query results (`get_entries`, blocked cells, shared-cell counts, crush queries) are unchanged.
- `MovementController` emits a `cell_changed` signal when a unit crosses a cell boundary, and stops sampling terrain + writing `global_position.y` every physics tick for idle units (snap only when the cell or stored height changes).
- `SelectionManager` stops polling the `"selectable"` group every frame. Selection state is synchronized event-driven via `SelectComponent` selection-change signals.
- `SelectionOverlay` stops recollecting + redrawing every frame unconditionally. It redraws only when selection, hover, or health changes, iterating a small cached list instead of the whole group.
- `CellUtil.world_to_cell`/`cell_to_world` stop doing a scene-tree lookup per call. Resolved `grid_cells` is cached and invalidated on `TerrainSystem.init_grid`; the explicit-arg path remains.
- `ProductionManager` stops re-scanning all factories per queue per frame. Per-queue production speed (factory count + primary) is cached and invalidated on FactoryComponent add/remove/`set_primary`.
- `Pathfinder` avoids scene-tree lookups and per-probe String keys for terrain height: it reads the vertex grid directly, resolves `terrain`/`grid_cells` once per `find_path`, and reuses the previous iteration's height.
- `CellReservation.release_all` becomes O(claims of the claimant) via a per-claimant cell index, instead of scanning every cell with claims.

No changes to public EntityData / resource schemas or packed scene structure. All query APIs keep identical return values.

## Capabilities

### New Capabilities

### Modified Capabilities
- `spatial-hash`: requirement "SpatialHash rebuilt every physics frame" changes to incremental cell-change updates with full rebuilds only on entity membership changes; blocked/shared-cell population moves to state transitions; entry pooling and cached node refs are introduced.
- `selection-manager`: requirement "Visual selection synchronization" changes from polling every frame to event-driven synchronization via SelectComponent selection signals.

## Impact

- `scripts/core/SpatialHash.gd` — incremental grid maintenance, entry pooling, cached node references, `cell_changed` handling.
- `scripts/components/MovementController.gd` — emit `cell_changed` on cell crossing (existing `new_cell != old_cell` at MovementController.gd:689-695); idle snap only on cell change.
- `scripts/core/SelectionManager.gd` — remove per-frame visual-sync poll; drive from signals.
- `scripts/components/SelectComponent.gd` — selection-change signals; existing `set_is_selected` used as the emit point.
- `scripts/ui/SelectionOverlay.gd` — dirty-flag redraw, cached entity list.
- `scripts/core/CellUtil.gd` — cached `grid_cells`; invalidation hook.
- `scripts/core/TerrainSystem.gd` — notify CellUtil on `init_grid`.
- `scripts/production/ProductionManager.gd` — cached per-queue speed; invalidation wiring.
- `scripts/components/FactoryComponent.gd` — add/remove/`set_primary` signals for speed-cache invalidation.
- `scripts/core/Pathfinder.gd` — terrain height fast-path.
- `scripts/core/CellReservation.gd` — per-claimant cell index.
- Tests: existing `test/unit` suites for spatial-hash, selection-manager, production-manager, pathfinder, and cell-reservation must pass unchanged; new perf-guard + behavior tests.
- No new dependencies. No changes to `.tscn`/`.tres` files.
