## Context

`perf/279-mass-infantry-move-fps-drop` profile after the greedy-first change: 186 moving infantry sustain ~30ms frames during a 50+ unit move. The dominant costs are no longer pathfinding (now 3ms) but the per-unit movement sim:
- `MovementController._handle_moving_movement` 10.5ms/186 calls (56µs each, every 60Hz physics tick) — a 3×3 SpatialHash avoidance scan (9 dict lookups + per-entry `distance_to`/`normalized`/`dot`), ~3 bilinear `get_height_at_world_smooth` terrain samples per unit, and multiple Catmull-Rom spline evals.
- `SelectionManager._process` → `try_greedy_step` 5ms dispatch burst — `Pathfinder._get_terrain_system()` walks `Engine.get_main_loop().get_node_or_null()` **per greedy step** (74× per order drain).
- `ShroudSystem.move_reveal` 3ms/13 calls (230µs each) — Bresenham LOS rays re-reading 4 `_vertex_grid` entries per step via `get_cell_max_height`.

Every unit re-pays for facts that are static between terrain edits (heightfield) or static per order (path spline, autoload reference). Frame budget is 16.6ms; Process time is 13.5ms.

## Goals / Non-Goals

**Goals:**
- Cut the sustained movement cost (10.5ms) and the dispatch burst (5ms) via behavior-identical caching/hoisting.
- A world-lifetime terrain height snapshot that serves all four height consumers and is provably coherent with the live heightfield.
- Frame-scoped height memo and spline path baking in `MovementController`.
- Batch-scoped `TerrainSystem` reference hoisting through pathfinding.
- Preserve steering, snap, climb, LOS, and fog results byte-for-byte (suite stays green at 4640+).

**Non-Goals:**
- Jam-coupled tick throttling / far-field decimation (Focus 2 from the ADHD run) — requires a displacement-histogram proof first; a separate follow-up change.
- Land-type world-lifetime caching — invalidation channels don't exist (`set_land_type` emits no signal; SpatialHash resource registry mutates on harvest/growth). Stays batch-lifetime.
- The 3×3 avoidance scan micro-math (squared-distance prune, scratch buffers) — cheap win, but folded into this change only if the movement memo lands clean; otherwise a separate small change.
- Shroud LOS row-streaming / crescent memoization — targeted at the 3ms `move_reveal`, separate scope.
- SelectionOverlay draw batching (1.2ms) — separate.

## Decisions

### D1: World-lifetime height snapshot lives in `TerrainSystem`, invalidated by `cell_changed`
The existing `cell_changed` signal fires for every vertex mutation (`set_vertex`, raise/lower paint) and for all cells on map load — it is the free, correct invalidation channel. Store a `Dictionary` keyed by `CellUtil.cell_key(cell) → [h_nw, h_ne, h_sw, h_se]` (raw int heights, `HEIGHT_STEP` applied by consumers as today). Populate lazily on first query; erase the affected cell(s) on `cell_changed`; clear all on `grid_initialized`.
- **Alternative rejected:** dense `PackedInt32Array` indexed by cell index — faster than a dict for a full grid, but the diamond grid is only partially populated and out-of-diamond cells must return the current default; a dict preserves exact semantics with less risk. Swap later if profiling shows dict hits are hot (documented in the cache's perf note).
- **Alternative rejected:** per-query `Array` of heights — allocates per call, exactly what we're removing.

### D2: All height consumers read the snapshot
`get_height_at_world_smooth` (bilinear via `_sample_heightfield_at`), `get_cell_max_height` (max-corner), and `Pathfinder._cell_height` (min-corner) all read the snapshot's 4 corners. Bit-identical float output is guaranteed by storing raw ints and applying `HEIGHT_STEP` in the same per-consumer ordering as today — no float round-trip through the cache.

### D3: Land type stays batch-lifetime in `PathCostCache`
No world-lifetime land cache. `_cell_cost` keeps resolving land via `get_land_type` and bib via `SpatialHash.is_bib_cell`, memoized only for the batch lifetime (generation-guarded), exactly as the greedy change shipped it.

### D4: `TerrainSystem` reference threaded through pathfinding
`try_greedy_step`, `_cell_cost`, and `find_path` gain an optional `terrain: Node` parameter. `MovementController`/`SelectionManager` resolve the autoload once per order batch (or per path build) and pass it down. When null, `_get_terrain_system()` fallback preserves existing behavior and test ergonomics. This removes the 74×/order `Engine.get_main_loop()` walk.

### D5: Frame-scoped height memo in `MovementController`
A `static var _frame_heights: Dictionary` cleared when `Engine.get_process_frames()` changes; keyed by quantized cell (start: half-cell rounding) → smoothed height. Routes `_snap_to_terrain`, `_slope_coefficient`'s height_ahead/height_now pair, and the arrival snap. Only unit-independent reads are memoized; the 3×3 avoidance scan stays live per-unit (it depends on dynamic positions, which are order-dependent mid-loop).
- **Risk note:** quantization on slopes could exceed climb tolerance if the bucket is too coarse — start with half-cell rounding and assert max bucket height delta < climb tolerance in a test.

### D6: Spline path baking
At `set_target_position` time, precompute per-segment arrays: positions, tangents, lengths. `_get_spline_pos(t)` / `_get_spline_tangent(t)` / segment-length reads become array indexing. Same Catmull-Rom math, evaluated once per path instead of ~6× per unit per tick. Organic (straight-leg) infantry keep their steering but still get the baked tangent/lengths.

## Risks / Trade-offs

- [Stale heights served after a mutation] → every vertex mutation path already emits `cell_changed`; D1 erases on that signal and on `grid_initialized`. A unit test paints a cell and asserts the next query re-reads live data.
- [Quantization error in the frame memo changes snap/slope behavior] → start with half-cell rounding; test asserts the bucket height delta stays under the climb tolerance and float parity with direct reads.
- [Land-type staleness if someone later widens the cache] → D3 is explicit in the spec (world-lifetime = heights only); the `terrain-height-cache` spec scenario "Harvested crystal reflects new land type" guards it.
- [Signature churn on `find_path`/`try_greedy_step`] → new parameter is optional (default null → autoload fallback), so all 4640 existing tests keep compiling and passing; only the hot call sites pass the reference.
- [Spline bake memory] → per-path arrays scale with path length (tens of waypoints); trivial vs. the eval cost removed. Freed on re-target/stop.

## Migration Plan

Pure in-tree change: implement D1+D2 (snapshot + consumers), then D4 (threading), then D5+D6 (movement memo + spline bake). Each lands with its tests; the full suite runs after each step. No scene/resource/data migration. Rollback = revert the commit; behavior is identical throughout, so nothing can regress invisibly.

## Open Questions

- Whether to fold the avoidance-scan micro-math (squared-distance + scratch buffers) into this change or a follow-up — depends on how far D1+D5+D6 move the 10.5ms figure after profiling.
