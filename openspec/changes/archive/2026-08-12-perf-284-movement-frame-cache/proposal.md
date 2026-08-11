## Why

Issue #284's profile (100 infantry) pins ~70µs per moving unit per tick on **pure GDScript interpreter tax**, not algorithm: the 3×3 avoidance scan pays 9 `SpatialHash.get_entries` dict lookups per unit per tick (4.34ms), `_terrain_speed_factor` re-resolves land type every tick (3.43ms), and `_apply_facing` re-reads 4 raw `_vertex_grid` entries per tick for the terrain normal (2.11ms). These costs are behavior-neutral to remove — every value is unit-independent and static within a physics frame.

## What Changes

- **Cell-scoped shared frame cache in `MovementController`** (frame + generation-guarded, same pattern as `_frame_heights`): per unique cell, cache the 3×3 avoidance-hood entry lists and the land type. Units sharing a cell pay one dict fetch per cell per frame instead of 9 per unit; empty cells are answered from the cached hood without a repeated dict lookup.
- **Frame-memoized land type**: `_terrain_speed_factor` reads the cached land type per cell instead of `TerrainSystem.get_land_type` (resource registry + land-type dict) on every call.
- **Normal routed through the corner snapshot**: `_apply_facing` computes the terrain normal from the same 4 corner heights the height memo already fetches (`get_cell_snapshot_corners_raw`), instead of 4 raw `get_vertex` reads. Bit-identical output (same 4 raw int corners, same cross-product order).
- **`SpatialHash._reconcile` position short-circuit**: reconcile skips the `world_to_cell` + `cell_key` recompute for entries whose position has not changed since the last reconcile, eliminating the per-entry recompute cost for the steady-state (idle) majority at 1500 units.
- No breaking changes: movement math, avoidance behavior, snapping, facing, and shroud results are preserved byte-for-byte.

## Capabilities

### New Capabilities
- `movement-frame-cache`: per-cell frame-scoped terrain + hood cache in `MovementController` — land type memo, 3×3 avoidance-hood sharing with empty-cell guard, and normal-via-corner-snapshot, all keyed to the physics frame.

### Modified Capabilities
- `spatial-hash`: reconcile SHALL skip `world_to_cell`/`cell_key` recomputation for entries whose cached position is unchanged, keeping the reconciled result identical to the pre-change full-scan behavior.

## Impact

- `scripts/components/MovementController.gd` — add frame cache scaffolding + gen guard; route `_terrain_speed_factor`, the 3×3 scan, and `_apply_facing` through it.
- `scripts/core/SpatialHash.gd` — `_reconcile` position short-circuit (`last_x`/`last_z` per entry).
- Tests: `test/unit/test_movement_controller_infantry.gd` (behavior unchanged), new `test/unit/test_movement_frame_cache.gd` (parity, hood sharing, empty-cell guard, land memo), `test/unit/test_perf_guard.gd` (reconcile short-circuit counter).
- No scene or resource changes; no data changes.
