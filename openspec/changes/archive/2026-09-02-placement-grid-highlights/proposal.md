## Why

During build mode the player gets almost no preview of where a building may go: a faint line grid follows the cursor and red cells pop for blocked cells near the ghost. There is no indication of the region bounded by the `adjacent` rule, so players probe for valid spots by dragging the ghost around. GH issue #352.

## What Changes

- Add three-state highlight cells rendered during build mode:
  - **White** — every cell the ghost's foundation could ever cover, derived from the `adjacent` rule: friendly building footprints dilated by the ghost's `adjacent` value, then dilated by the ghost's full foundation size in X and Z respectively
  - **Green** — cells under the ghost where placement is allowed
  - **Red** — cells where placement is blocked (occupied, out of play area, etc.)
- Shared cell-plane mesh style for all highlight cells: flat quad at highest terrain corner height + 0.05, XZ footprint = 90% of cell size, chamfered (beveled) corners
- White set is anchored to friendly buildings (built once per build-mode session); `adjacent == 0` white = building cells dilated by foundation size only; negative `adjacent` clamps to 0; no friendly buildings → no white cells
- Extract overlay rendering into a new `PlacementGridOverlay` node; the white-region math is shared between the overlay and `can_place`/`_is_adjacency_satisfied` so display and validation cannot diverge
- Remove the per-frame line grid (`BuildingManager._add_grid_and_indicators` and helpers)
- Out of scope: fixing the `adjacent` gap semantics bug (#345) and the map editor's `EntityPlacer` preview

## Capabilities

### New Capabilities
- `placement-grid-overlay`: Three-state (white/green/red) highlight cell overlay shown during building placement, including the white-region rule derived from the `adjacent` value and the shared cell-plane mesh style

### Modified Capabilities

## Impact

- `scripts/buildings/BuildingManager.gd` — preview flow rewritten: `_update_preview_mesh` slims down, `_add_grid_and_indicators`/`_quad`/`_build_cell_mesh` deleted, adjacency math extracted into a shared helper
- New `scripts/core/PlacementGridOverlay.gd` (+ scene if needed) — MultiMesh-based rendering, one shared chamfered mesh, per-instance color
- Tests touching preview children (`test/unit/test_building_manager.gd`, `test/integration/test_asset_preview_scene.gd`) need updating
- No packed scene or `.tres` format changes; no new autoload
