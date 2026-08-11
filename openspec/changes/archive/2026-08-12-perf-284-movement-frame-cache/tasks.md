## 1. Frame cache scaffolding + land memo

- [x] 1.1 Add `static var _frame_cells: Dictionary` + `_frame_cells_frame: int` + `_frame_cells_gen: int` to `scripts/components/MovementController.gd`, sharing the frame/gen invalidation rule with `_frame_heights`.
- [x] 1.2 Route `_terrain_speed_factor` (`MovementController.gd:176`) through a `_frame_cell_land(cell)` helper: cache miss → `TerrainSystem.get_land_type(cell)` → cache; hit → return cached land type.
- [x] 1.3 Add `test/unit/test_movement_frame_cache.gd`: two units on the same cell resolve the land type once per frame (guard via a `TerrainSystem.get_land_type` call counter or frame-scoped observable), and a frame advance clears the cache.

## 2. Avoidance hood + empty-cell guard

- [x] 2.1 Add a `_frame_hood(cell)` helper returning the 3×3 entry lists (9 arrays) for the cell, caching per cell_key per frame.
- [x] 2.2 Rewrite the 3×3 avoidance scan (`_handle_moving_movement`, `MovementController.gd:693-717`) to read from `_frame_hood(parent_cell)` instead of calling `SpatialHash.instance.get_entries` 9× per unit; empty cells answer from the cached empty array.
- [x] 2.3 Add a perf-guard test asserting the scan performs one `get_entries` burst per unique cell per frame for a cluster of units sharing cells (deterministic counter, not wall-clock, mirroring `test_perf_guard.gd`).

## 3. Normal from corner snapshot

- [x] 3.1 Add `_memoized_normal(pos)` mirroring `_memoized_smooth_height`: reuse the same cell-key/corners lookup (`get_cell_snapshot_corners_raw`) to compute the cross-product normal (`edge_z.cross(edge_x)`, `HEIGHT_STEP` scaling).
- [x] 3.2 Route `_apply_facing` (`MovementController.gd:916`) through `_memoized_normal` instead of `TerrainSystem.get_normal_at_world`.
- [x] 3.3 Add a parity test: `_memoized_normal` equals `TerrainSystem.get_normal_at_world` bit-for-bit on a slope cell (extend `test/unit/test_movement_frame_cache.gd`).

## 4. Reconcile position short-circuit

- [x] 4.1 Add `last_x`/`last_z` (or last `Vector3`) to the pooled entry in `SpatialHash.rebuild` (`SpatialHash.gd:92-101`), initialized from the entry's position.
- [x] 4.2 In `_reconcile` (`SpatialHash.gd:118-152`), compare the node's `global_position` against the cached last position first; unchanged → `continue` before `world_to_cell`/`cell_key`; changed → run the existing mutation and update the cached position.
- [x] 4.3 Add a perf-guard test in `test/unit/test_perf_guard.gd`: reconcile over N idle, unmoved entries performs no cell recompute (counter stays 0), and a moved entry still reconciles to the correct new cell (result identical to pre-change full scan).

## 5. Verification

- [x] 5.1 Full suite: `redot --headless -s test/run_tests.gd` green (expect ~4695+ asserts), including existing movement/avoidance/snap/facing behavior tests unchanged.
- [x] 5.2 `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd` clean; no tabs (`grep -P '\t' scripts/**/*.gd test/**/*.gd`).
- [x] 5.3 Confirm the movement-frame-cache and spatial-hash delta specs are validated: `openspec validate` clean.
