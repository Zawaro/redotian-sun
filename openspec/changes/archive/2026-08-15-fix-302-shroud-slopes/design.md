## Context

`ShroudSystem._cell_blocks` (scripts/core/ShroudSystem.gd) blocks LOS when `TerrainSystem.get_cell_max_height(cell) > viewer_height + _max_height_delta`, with `_max_height_delta = HEIGHT_STEP * 0.75 = 0.611`. `get_cell_max_height` (TerrainSystem.gd) returns the tallest of the four corners × HEIGHT_STEP. A graded 1-step slope (raw corners `[0,0,1,1]`, max 0.815) exceeds the eye of a low unit, and the map's 2-step slope tiles present multi-step faces to a climbing viewer, so the slope ahead stays shrouded while a unit walks up it (#302). The test map has 344 grade-1 and 117 grade-2 slope cells — all walkable terrain the pathfinder routes through (min-corner heights, `climb_tolerance = 1`).

Two faults were compounding: (1) the blocking predicate had no slope/cliff distinction, treating graded faces like sheer walls; (2) `move_revealer` read `viewer_height` frozen at registration, so a unit climbing a slope never gained a higher eye for its shadowcast — the "C1" branch from the ADHD exploration.

The fix narrows the blocking predicate to walkable grades and makes the revealer's eye height track the unit. This mirrors what the game's own locomotion already knows — `Locomotor.climb_tolerance` is measured in `HEIGHT_STEP` units, so edge-rise-1 grades are traversable and should not occlude.

## Goals / Non-Goals

**Goals:**
- A unit walking up a 1–2 step slope reveals the face ahead.
- Walkable graded slopes/stairs (edge rise == 1) never block; flat raised plateaus and sheer cliff faces keep the height-delta blocking behavior.
- The revealer's `viewer_height` updates as a unit climbs, so high ground sees over.
- Minimal diff: one TerrainSystem helper + `_cell_blocks` change + `move_revealer` height plumbing.
- Preserve the #279 crescent fast path (no extra work on flat terrain).

**Non-Goals:**
- No directional/near-edge ray geometry, no ray-height interpolation, no octant symmetry tables.
- No baked per-cell tag arrays or new persistent storage.
- No GlobalRules tuning knobs.

## Decisions

### D1. Derive grade on the hot path from the existing height snapshot

`TerrainSystem._snapshot_corners(cell)` already backs `get_cell_max_height` and auto-invalidates on `cell_changed` / grid re-init via `height_snapshot_generation`. A new `get_cell_grade_steps(cell) -> int` reads the same snapshot and returns the steepest adjacent-corner rise in raw height units. No new storage, no new invalidation wiring — the snapshot is the single source of truth.

**Alternative considered:** bake a per-cell PackedByteArray step tag at grid init. Rejected: correctness first, and the snapshot lookup is a cached dict read; only bake if profiling flags the allocation on the 60Hz re-stamp path.

### D2. Edge-rise blocking rule (walkable grades never block)

`_cell_blocks` becomes: exempt cells with `get_cell_grade_steps(cell) == 1` (a walkable graded slope or stair — every edge rises at most one step, matching `climb_tolerance = 1`); all other cells — flat raised plateaus (grade 0) and steep faces (grade >= 2) — fall through to the unchanged `get_cell_max_height > viewer_height + _max_height_delta` check. This keeps `test_hill_blocks_vision` (flat 3-step ridge) blocking and `test_high_ground_sees_over` seeing over.

**Why edge rise, not global span:** the map's 2-step slope tiles are stair patterns like `[0,1,1,2]` — global max-min span is 2, but every edge rises one step, so foot units walk them. Span-based grading misclassifies these as cliffs; edge-rise grading matches walkability. Verified against `assets/test_map01.json` corners: grade-2 map cells resolve to edge rise 1.

**Alternative considered:** directional near-edge test (block the edge the ray crosses, not the tallest corner). More geometrically honest, but introduces a 45°-diagonal wedge leak requiring an 8-octant symmetry table — a second bug waiting to happen. The edge-rise rule gets the same user-visible result with a fraction of the surface area.

### D3. Live viewer height through `move_revealer`

`move_revealer(player_id, key, new_cell, viewer_height = -1.0)` gains an optional height. When supplied (>= 0) and differing from the stored height beyond epsilon, the revealer's whole disc is re-evaluated from the new vantage via a new `_recompute_at` helper that stamps the symmetric difference (never leaking counts). When height is unchanged (flat terrain — the common case), behavior is byte-for-byte the existing crescent fast path, so #279 perf is preserved. `VisionComponent` passes `_viewer_height()` at the existing cell-crossing call site.

**Alternative considered:** re-stamp only the banded crescent around the shadow edge. More work for the same user-visible result at typical sight radii (<= 12); the full-disc recompute is rare (only on elevation change) and cheaper than the unregister+register it replaces.

## Risks / Trade-offs

- [Saddle cells `[0,1,1,0]` have edge rise 1 and become transparent, leaking a thin sight line along the high diagonal half] → Accepted: single-step faces are walkable and the leak is a wedge a Bresenham line would clip only rarely; crease-aware handling is a follow-up if the map uses saddles heavily.
- [A flat 2-step plateau block is graded 0, so it falls to the float check and blocks from below] → Correct: that is a raised flat surface, not a walkable grade. `test_flat_plateau_blocks_vision_from_below` locks this in.
- [`move_revealer` full-disc recompute on height change could surprise the overlap-cell "SHALL NOT be re-stamped" spec clause] → The clause governs pure center moves; the height-change path is explicitly documented and spec-amended as a separate branch.
- [The stale-overlap approximation in `move_revealer` (crescent-only re-stamp on unchanged height) can still leave a cell momentarily unrevealed at a shadow edge] → Pre-existing, documented, self-corrects on the next crossing; out of scope for this fix.

## Migration Plan

Additive change: new TerrainSystem helper defaults safe, `_cell_blocks` exemption inert for flat terrain (grade 0 falls through to the unchanged float check), `move_revealer` new param has a sentinel default so existing callers/tests are unaffected. No scene/resource changes. Rollback = revert the three-file diff.

## Open Questions

- Does the GDI1 map's terrain use saddle cells (`[0,1,1,0]`) enough to justify crease-aware handling later? (Likely not; defer.)
- Should the height-change recompute be banded to the shadow edge for very large sight radii? (Defer until a unit with sight > 12 climbs; the map's max sight is 6-8.)
