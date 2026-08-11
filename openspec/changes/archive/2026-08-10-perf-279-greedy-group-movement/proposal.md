## Why

Issuing a move order to 50+ infantry costs ~14.6ms/frame of Process time for ~6 frames because every unit independently runs a full A* (`find_path`, ~1.8ms each) from its scattered start to its formation cell. The reverse-frontier fast path proposed in `perf-279-shared-move-lines-group-path` was benchmarked and profiled as a REGRESSION (95ms single-frame spike vs 14.6ms — reverse Dijkstra has no heuristic, so it expands a uniform disc over the whole reachable map and pays the union of all corridors from scattered starts). The residual per-unit A* drain remains the top move-order cost after the shroud fix.

## What Changes

- **Drop the reverse-frontier fast path.** `Pathfinder.compute_frontier` / `reconstruct_path`, SelectionManager `_frontier_eligible`/`_frontier_memo`/`_frontier_path`/`_sharer_blocked_cells`, and MovementController `get_locomotor_data`/`precomputed_path` are removed. Move dispatch returns to per-unit `find_path` (the pre-frontier state).
- **Greedy-first path resolution.** A new `Pathfinder.try_greedy_step(from_cell, target_cell, blocked, locomotor) -> Vector2i` returns the best strictly-improving passable neighbor (or a stall sentinel). `MovementController.set_target_position` walks it with a bounded step budget (e.g. 64) before falling back to full `find_path` from the stalled cell. On open terrain (the common march) the order costs ~0ms; the A* fallback is the correctness net for concave pockets, cliffs, and heavy crowding.
- **Per-cell terrain cost cache.** `find_path`'s inner loop probes `_cell_height` (4× `terrain.get_vertex`), `get_land_type`, bib, and blocked state per neighbor. A memoized per-cell terrain-cost lookup (filled once per unique cell) makes 50 overlapping searches read shared cost data instead of re-probing TerrainSystem/SpatialHash — byte-identical paths, constant-factor speedup.
- **Flyer bypass.** Airborne locomotors (fly/jumpjet, `ignores_height`) skip greedy-uncertainty entirely: unbounded greedy descent on Euclidean distance is exact for them, so they never pay A* (or greedy) at all.
- **Batch-lifetime cache reuse.** SelectionManager keeps the terrain-cost cache alive across its 8-per-frame drain (~6 frames), so the whole 50-unit order shares one cost grid. Cache invalidation tracks the blocked/reservation generation.
- Keep the batched move-line renderer from `perf-279-shared-move-lines-group-path` (that half ships as-is; only the frontier deltas are superseded).

## Capabilities

### New Capabilities

_None. Both behaviors land as requirements on the existing `pathfinder` capability._

### Modified Capabilities

- `pathfinder`: Reverse frontier (ADDED delta from `perf-279-shared-move-lines-group-path`) is **superseded/removed**. ADDED: greedy step primitive (`try_greedy_step`), per-cell terrain cost cache with generation-aware invalidation, and the greedy-before-A* resolution contract for movement orders. Existing `find_path` requirements (A*, per-locomotor filtering, climb tolerance, bib penalty, stagnation fallback) are unchanged.
- `selection-manager`: "Batched move dispatch" requirement is **superseded**: the frontier-mandated dispatch (from `perf-279-shared-move-lines-group-path`) is replaced by per-unit `find_path` with greedy-first resolution, sharing one batch-lifetime terrain-cost cache. Batch-of-8 dispatch, sharer cell pre-assignment, and sub-slot behavior are unchanged.

## Impact

- `scripts/core/Pathfinder.gd` — add `try_greedy_step`, `_terrain_cost_cache` (or similar); remove `compute_frontier`/`reconstruct_path`.
- `scripts/components/MovementController.gd` — greedy loop in `set_target_position` before `find_path`; remove `get_locomotor_data`/`precomputed_path` param; flyer bypass.
- `scripts/core/SelectionManager.gd` — remove all `_frontier_*` code; restore plain `_execute_move`; own the batch-lifetime cost cache.
- `scripts/core/ShroudSystem.gd`/`VisionComponent.gd` — untouched (phase-1 fix stays).
- Tests: delete the frontier tests in `test/integration/test_pathfinder_terrain.gd` and `test/unit/test_selection_manager.gd`; delete bench leftovers `test/_bench_tmp.gd` and `test/unit/test_bench_tmp.gd`; add greedy-step unit tests (including concave-pocket escape via A* fallback and flyer bypass) and a byte-identical cache diff test.
- OpenSpec: `openspec/changes/perf-279-shared-move-lines-group-path` keeps its `move-line-renderer` and `select-component` deltas; its `pathfinder` and `selection-manager` frontier deltas are superseded by this change and dropped before archive.
