## Context

The movement hot path (`MovementController._handle_moving_movement`, ~43µs/unit/tick) and `SpatialHash._reconcile` dominate the #279 profile at scale. Profile at 100 infantry:

| Function | Total | Calls | Cost/unit/tick |
|---|---|---|---|
| `_handle_moving_movement` | 47.30 ms | 1092 | ~43µs |
| `get_entries` | 4.34 ms | 9836 | ~440ns × 9 |
| `_terrain_speed_factor` | 3.43 ms | 1092 | — |
| `_apply_facing` | 2.11 ms | 1106 | — |
| `SpatialHash._reconcile` | 3.09 ms | 6 ticks | — |

All four targets are unit-independent inputs static within a physics frame: terrain height (already memoized via `_memoized_smooth_height`), land type (painted overlay + resource registry), occupancy (entry lists), and the 4 corner heights for the facing normal. Reuse the existing frame/gen-keyed memo pattern (`_frame_heights`, `_frame_heights_frame`, `_frame_heights_gen`) rather than inventing a new cache discipline.

## Goals / Non-Goals

**Goals:**
- Collapse the 3×3 avoidance scan's 9 `get_entries` dict lookups per unit into one per-cell hood fetch (plus an empty-cell guard).
- Resolve land type once per cell per frame for `_terrain_speed_factor`.
- Route the `_apply_facing` terrain normal through the existing corner snapshot instead of 4 raw `get_vertex` reads.
- Eliminate `world_to_cell`/`cell_key` recompute for unchanged entries in `SpatialHash._reconcile`.
- Preserve movement, avoidance, snapping, facing, and shroud results bit-for-bit (suite green).

**Non-Goals:**
- The SoA fused batched pass (issue Step 5), deferred reveal queue (Step 3), or straight-segment spline skip (Step 2) — separate follow-up changes.
- Native/GDExtension ports (#285–289).
- The `_memoized_smooth_height` bilinear math itself (already memoized); the cache only adds land type, hood, and normal consumers alongside it.

## Decisions

### D1: One frame cache, three consumers, gen-guarded like `_memoized_smooth_height`
Extend the existing static frame-scoped memo pattern. A single `static var _frame_cells: Dictionary` keyed by `CellUtil.cell_key(cell)` holds `{"land": String, "hood": Array}` (hood = 9 entry lists for the 3×3 around that cell, each possibly empty). Invalidation: same rule as `_memoized_smooth_height` — clear when `Engine.get_process_frames()` advances or when `TerrainSystem.height_snapshot_generation` changes. Land type and hood are only recomputed on a cache miss.
- **Alternative rejected:** separate caches per concern — more clearing sites, more surface for staleness, no measurable win.
- **Alternative rejected:** world-lifetime land cache — the resource registry (harvest/growth) mutates with no invalidation signal; the issue's Step 1a already rules this out in favor of frame scope.

### D2: Hood is populated per unique cell, empty cells included
When a unit's 3×3 scan needs a cell not yet in the cache, populate all 9 neighbor slots in one pass (9 `get_entries` calls). Reuse: any unit in the same cell reads the cached hood, and empty neighbor cells answer from the cached empty array — no `get_entries` call per unit per empty neighbor. The hood lives only for the frame, so occupancy staleness is bounded to the current physics tick (matching `_reconcile`'s within-tick semantics).
- **Alternative rejected:** per-unit scratch lists — does not dedupe across units sharing a cell, which is the entire win.

### D3: Normal-from-corners reuses the height-memo corner fetch
`_apply_facing` currently calls `TerrainSystem.get_normal_at_world` (4 `get_vertex` reads). Route it through the corner array the height memo already fetches (`get_cell_snapshot_corners_raw`). Bit-identical because both read the same 4 raw int corners and apply the same cross-product edge order (`edge_z.cross(edge_x)`, `HEIGHT_STEP` scaling). Implemented as a `_memoized_normal(pos)` helper mirroring `_memoized_smooth_height`, sharing its cell-key/corners lookup.
- **Alternative rejected:** caching the computed normal — the position differs per unit within a cell (sub-cell offsets), so the normal must be recomputed per position; only the corner fetch is shareable.

### D4: `_reconcile` position short-circuit via cached last position
Each entry already caches `cell_key`/`state`/`shares`. Add a cached `last_x`/`last_z` (or last `Vector3`) set at reconcile time. `_reconcile` compares `node.global_position` against it first; unchanged → `continue` before `world_to_cell`/`cell_key`. Because `MovementController` (the only continuous position writer; spawn/Deploy set position before add_child and trigger a rebuild) always mutates `global_position` in place, the short-circuit is safe: an unchanged position implies an unchanged cell.
- **Alternative rejected:** dirty-flag contract from MovementController — requires every writer to notify; the position comparison is allocation-free and catches all writers.

## Risks / Trade-offs

- [Stale land type served mid-frame after a resource flip] → Frame scope bounds staleness to ≤1 physics tick; `PathCostCache` already ships batch-lifetime land caching with the same accepted staleness. Explicitly tolerated in the movement-frame-cache spec.
- [Hood memory ceiling] → The hood stores only cells touched by moving units this frame; for a 1500-unit rush that is the moving group's distinct cells, not the whole map. Cleared every frame.
- [Normal bit-parity regression on slopes] → Guarded by a dedicated parity test asserting equality with `get_normal_at_world` (same pattern as `test_terrain_height_cache.gd`).
- [`_reconcile` short-circuit misses an external position write] → Verified writers are only MovementController (in-place) plus spawn/Deploy (both trigger a membership rebuild via add_child). A position change without a state/cell change is caught on the next position comparison.
- [Per-frame cache keyed by `Engine.get_process_frames()` in tests] → The memo pattern already handles test-driven frames via the frame/gen guard; existing frame-memo tests keep passing.

## Migration Plan

Pure in-tree change, behavior-neutral throughout. Implement in order, running the suite after each step:
1. Frame cache scaffolding (D1) + land memo (D2) into `_terrain_speed_factor`.
2. Hood population + empty-cell guard into the 3×3 scan.
3. `_memoized_normal` (D3) into `_apply_facing`.
4. `_reconcile` position short-circuit (D4).
Rollback = revert the commit; each step is independently revertible and behavior-identical.

## Open Questions

- Whether the hood should also prefetch the land type of the 8 neighbor cells (currently only the unit's own cell land type is consumed by `_terrain_speed_factor`). Answer now: no — nothing reads neighbor land type on the hot path; add only if a later step needs it.
