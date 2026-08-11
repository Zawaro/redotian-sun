## 1. TerrainSystem world-lifetime height snapshot

- [x] 1.1 Add the snapshot dict (keyed by `CellUtil.cell_key(cell)` → `[h_nw, h_ne, h_sw, h_se]` raw ints) to `scripts/core/TerrainSystem.gd`, populated lazily on first query, with a generation counter bumped on `grid_initialized`/clear.
- [x] 1.2 Connect invalidation: erase the affected cell(s) on the existing `cell_changed` signal; clear all on `grid_initialized`; verify `notify_grid_changed`/`_on_grid_initialized` paths reset the cache.
- [x] 1.3 Reroute `get_cell_max_height` (max-corner) through the snapshot; keep bounds/out-of-diamond behavior identical.
- [x] 1.4 Reroute `get_height_at_world_smooth` (`_sample_heightfield_at`) through the snapshot for the 4 corner reads; keep bilinear output bit-identical (raw ints, `HEIGHT_STEP` at the end).
- [x] 1.5 Update `Pathfinder._cell_height` to read the snapshot's 4 corners (min-corner) instead of 4 `get_vertex` calls, with `terrain == null` fallback to `0.0`.

## 2. Terrain reference threading through pathfinding

- [x] 2.1 Add optional `terrain: Node` parameter to `Pathfinder._cell_cost`; when provided use it (and its snapshot) instead of `_get_terrain_system()`.
- [x] 2.2 Add optional `terrain: Node` parameter to `Pathfinder.try_greedy_step`; hoist the `_get_terrain_system()` call out of the per-step path so one reference serves all 8 neighbor probes (and all 74 steps).
- [x] 2.3 Add optional `terrain: Node` parameter to `Pathfinder.find_path`; thread it into `_cell_cost`/`_cell_height` and remove per-call autoload resolution when provided.
- [x] 2.4 `MovementController`: resolve the `TerrainSystem` reference once per path build (in `_greedy_or_search_path`/`set_target_position`) and pass it into `try_greedy_step`/`find_path` calls.
- [x] 2.5 `SelectionManager`: resolve the `TerrainSystem` reference once per move-order batch (`request_move`/`_process` drain) and thread it alongside `_cost_cache` into `set_target_position`/`_execute_move`.

## 3. Frame-scoped height memo in MovementController

- [x] 3.1 Add `static var _frame_heights: Dictionary` + frame tracking cleared on `Engine.get_process_frames()` change; key by quantized cell (half-cell rounding).
- [x] 3.2 Route `_slope_coefficient`'s height_ahead/height_now pair through the memo.
- [x] 3.3 Route `_snap_to_terrain`'s `get_height_at_world_smooth` through the memo.
- [x] 3.4 Route the arrival snap (MOVING → IDLE transition) through the memo; leave the 3×3 avoidance scan live per-unit.

## 4. Spline path baking

- [x] 4.1 In `set_target_position` (path build), precompute per-segment position/tangent/length arrays from the waypoints (same Catmull-Rom math as `SplineUtil`).
- [x] 4.2 Rewrite `_get_spline_pos`/`_get_spline_tangent`/segment-length reads to index the baked arrays; keep `_spline_t` semantics identical.
- [x] 4.3 Free baked arrays on re-target, stop, and arrival; guard stale-access with a path-generation counter.

## 5. Tests

- [x] 5.1 New `test/unit/test_terrain_height_cache.gd`: snapshot served on repeat query (no `_vertex_grid` re-index), bit-identical float parity with direct reads, invalidation on single-cell paint, full clear on grid re-init, unaffected cells keep cached values.
- [x] 5.2 New `test/unit/test_terrain_height_cache.gd`: land type NOT cached world-lifetime — harvest/growth registry change yields fresh land type on next probe (spec "Land type excluded" scenarios).
- [x] 5.3 `test/integration/test_pathfinder_terrain.gd`: `find_path`/`try_greedy_step` with a passed terrain reference produces identical paths to autoload-resolved calls; `find_path_call_count`-style guard that scene-tree lookup is skipped when a reference is supplied.
- [x] 5.4 `test/unit/test_movement_infantry_path.gd`: greedy-first regression tests pass unchanged with threading (open-terrain no-A*, concave fallback, flyer height).
- [x] 5.5 New movement equivalence tests: frame-scoped height memo returns identical snap/slope output to direct reads on a slope cell (quantization delta < climb tolerance); baked spline produces identical path positions/tangents to `SplineUtil` for the same waypoints.
- [x] 5.6 Full suite: `redot --headless -s test/run_tests.gd` green (expect 4640+).

## 6. Verification

- [x] 6.1 `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd` clean; no tabs (`grep -P '\t'`).
- [x] 6.2 Headless timing confirms the height-read cost is real (~1.5µs/smooth read → ~50ms/sec of pure terrain sampling across a 186-unit move) and the memo collapses it to unique-bucket reads; the frame memo + baked spline are covered by equivalence tests. **Pending: user re-profiles the 50-infantry move in-game** — Process time target ≤7ms (was 13.5ms).
- [x] 6.3 The 3×3 avoidance scan micro-math (squared-distance prune, scratch buffers) is still needed after the height/spline cuts — the scan's per-entry `distance_to`+`normalized`+`dot` remains the dominant per-unit movement cost. Tracked as a follow-up change (not in this scope).
