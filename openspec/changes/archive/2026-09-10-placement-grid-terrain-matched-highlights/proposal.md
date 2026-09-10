## Why

During build mode every foundation highlight cell renders as a flat octagon at the
cell's max corner height. On non-flat terrain that reads as a slab floating over
the ramp: the known risk D1 of the archived `placement-grid-highlights` change
(#352) has materialized, and players can't see the slope a building would sit on
before placing.

## What Changes

- Non-flat cells under the placement overlay (computed `slope` cells: any corner
  pattern with a height difference, including 1-step slopes, 2-step steep, and
  saddle patterns) render a mesh matching the terrain surface instead of a flat
  octagon.
- The matching mesh is derived from the data model: the cell's four corner
  heights (`TerrainSystem.get_cell_corner_heights`), tessellated by the
  `derive_crease` rule already baked into catalog objects. No GLB dependency, no
  vertical surfaces, no per-theater art coupling.
- Flat cells keep the current octagon (95% coverage, chamfered, max corner +
  offset).
- Existing state rules (white region, green/red under the ghost, adjacency) are
  unchanged: only the per-cell mesh shape for non-flat cells changes.

## Capabilities

### New Capabilities

(None)

### Modified Capabilities

- `placement-grid-overlay`: The "Highlight cell plane mesh style" requirement
  currently requires every highlight cell to be a flat plane. It becomes flat
  cells only; a new requirement specifies that non-flat cells render a
  terrain-surface-matched mesh (corner heights, crease triangulation, lifted
  offset, state color, no vertical faces).

## Impact

- `scripts/core/PlacementGridOverlay.gd`: flat/non-flat partition in `_rebuild()`;
  new pure mesh builder (corner heights -> inset-free 4-corner patch, planar quad
  or single-diagonal split); per-cell `MeshInstance3D` with shared state
  materials (white/green/red), pooled; octagon `MultiMesh` path unchanged.
- Tests: `test/unit/test_placement_grid.gd` (split the flat-plane test; add
  state-color partition tests) and a new per-cell geometry test module asserting
  generated patch vertices against `TerrainSystem` corner data and the catalog
  `crease` rule; integration assertions on `test_terrain.json` / `test_map01.json`
  slope cells.
- No changes to `BuildingManager`, `TerrainSystem`, `TerrainRenderer`, catalog
  data, or `.tscn`/`.tres` resources. `can_place` / `flatten_footprint` behavior
  is untouched.
