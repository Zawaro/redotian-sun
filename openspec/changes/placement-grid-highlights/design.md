## Context

During build mode, `BuildingManager._process` rebuilds the entire preview every frame: `_update_preview_position` → `_update_preview_mesh` (BuildingManager.gd:327) frees all preview children, allocates fresh `StandardMaterial3D`s and per-cell `ImmediateMesh`es, then `_add_grid_and_indicators` (BuildingManager.gd:410) draws a faint line grid plus red blocked-cell quads. The adjacency rule lives in `_is_adjacency_satisfied` (BuildingManager.gd:126): a placement is valid when any footprint cell is within Chebyshev `adjacent + 1` of a friendly building cell. Issue #345 tracks that the gap semantics there are disputed.

## Goals / Non-Goals

**Goals:**
- Three visual cell states during placement: white (reachable region), green (valid under ghost), red (blocked)
- White region derived from one shared rule used by both display and validation
- Kill the per-frame mesh/material allocation the current preview performs
- Remove the line grid entirely

**Non-Goals:**
- Fixing the `adjacent` gap off-by-one bug (#345) — but the helper must be structured so that fix lands in one place
- Map editor / `EntityPlacer` previews
- Changing what `can_place` accepts (behavior-neutral refactor for validation)

## Decisions

### D1: Flat cells at max corner height + 0.05 (not terrain-conforming)
Current `_build_cell_mesh` conforms quads to per-corner heights. Highlight cells instead use a flat quad at `max(h[0..3]) + 0.05`, smoke-tested for visual fit.
*Why:* never clips through terrain, and a flat shared mesh enables a single `MultiMesh` where the instance transform carries the Y position. Alternatives: conforming per-corner mesh (needs per-cell mesh generation, kills the MultiMesh win) or average-corner height (clips on slopes).

### D2: White region = two-step dilation
`white = dilate(dilate(⋃ friendly_footprint_cells, adjacent), (foundation.x, foundation.y))`
Step 1 uses the ghost's own `adjacent` value (friendly buildings contribute only their footprint cells). Step 2 dilates by the **full** foundation size per axis (3-wide → +3 cells in X). `adjacent == 0` → step 1 is identity (white = building cells dilated by foundation size). `adjacent < 0` clamps to 0 at the read site (`maxi(adjacent, 0)`). No friendly buildings → empty white set; ghost green/red still render at the cursor.
*Why:* this is the union of every cell a valid ghost could cover — exactly "all possible placement cells" — and it matches the gap-0-means-touching sanity case (building at origin, adjacent=0, 3×2 ghost: footprint x∈[1,3] inside white x∈[−3,3]; one gap further, x=4, outside).

### D3: Shared dilation primitive — display and validator consume one function
`_adjacent_reachable_cells()` (white region) and `_is_adjacency_satisfied()` both build on `_dilate_cells()` (exact per-cell dilation, chosen over bounding-box dilation so concave bib cell sets dilate identically to the old per-pair rule). The validator keeps its Chebyshev `adjacent + 1` reach ring; behavior is unchanged from the pre-change loop.
*Why not have the validator check `footprint ⊆ white`?* That changes behavior: with two friendly buildings A and B, a footprint can straddle their dilations so every cell is individually reachable while no footprint cell is within `adjacent + 1` of any building (e.g. 1x1 buildings at (0,0) and (8,0), adjacent=1, 3x3 ghost at (2,3): old rule rejects, subset-of-white accepts). The honest shared contract is: every valid placement's footprint lies fully within white, and every white cell is coverable by *some* valid placement — white is the exact union of coverable cells, not a per-position validator. #345's fix still lands in the shared dilation/adjacent-clamp site.

### D4: New `PlacementGridOverlay` node in `scripts/core/`
Rendering leaves `BuildingManager` (672 lines, logic-heavy). API: `set_white_cells(cells: Array[Vector2i])`, `set_cursor(origin: Vector2i, footprint: Vector2i)`, `clear()`. One `MultiMeshInstance3D` with per-instance color (white/green/red) over one shared chamfered-octagon mesh; one unshaded transparent `StandardMaterial3D` with vertex-color usage, created once at init — not per frame. White set is built once per `enter_build_mode` (buildings don't move); green/red refresh per cursor move.
*Alternative rejected:* keep inline in BuildingManager — smallest diff, but leaves the per-frame allocation pattern and grows an already-large autoload.

### D5: Chamfered octagon generated in code
Cut each corner ~15% of cell size; XZ footprint = 90% of `CellUtil.CELL_SIZE`. No texture asset, works with the shared flat mesh.
*Alternative rejected:* rounded alpha texture — new asset, fiddlier z-fighting/blending over terrain.

### D6: Layer update cadence
- White: on `enter_build_mode` only (friendly buildings static during placement)
- Green/red: on cursor move, via `set_cursor`
Blocked-cell detection reuses `_is_cell_free` / `_is_in_play_area` as today.

### D7: Review adjustments (user smoke-test round 1)
- **White window**: the full white set is computed once but only cells within the old line-grid radius (`max(footprint) * 0.5 + 3.0` around the ghost center) render — the window follows the cursor, so large bases never flood the screen.
- **Ghost beyond white**: for `adjacent > 0` ghosts, free footprint cells outside the white region turn red (adjacency binds); `adjacent <= 0` ghosts color purely free/blocked.
- **Tuning**: cell coverage 90% → 95%; red/green alpha 0.75 → 0.7; ghost transparency alpha 0.33 → 0.45. All smoke-test values.

## Risks / Trade-offs

- [Flat cells may look wrong on steep terrain] → smoke test per spec; fallback is raising the 0.05 offset or reverting to conforming quads (D1 notes the cost)
- [MultiMesh per-instance color needs vertex-color material support] → verified pattern in Godot/Redot `BaseMaterial3D` (`vertex_color_use_as_albedo`); unit-testable headless since mesh gen and color math are pure functions
- [White region recomputed on building death mid-placement] → out of scope: placement session ends before buildings change in practice; `set_white_cells` API allows a refresh later if needed
- [Existing tests assert preview child structure] → update `test_building_manager` / `test_asset_preview_scene` in the same change

## Migration Plan

Single-branch change on `feat/352-placement-grid-highlights`; no data or scene format changes, rollback is revert. Additive: new overlay file + helper; deletions confined to BuildingManager internals.

## Open Questions

- Exact white/green/red alphas — smoke test in-engine (start near current values: white ~0.35, green/red 0.75)
- Whether the 0.05 offset needs render_priority/depth bias tweaks — smoke test
