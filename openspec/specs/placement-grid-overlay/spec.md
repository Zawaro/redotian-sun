# placement-grid-overlay Specification

## Purpose

During build mode the player needs to see where a building may go: a three-state highlight overlay renders white cells for the reachable placement region derived from the `adjacent` rule, green cells under the ghost where placement is allowed, and red cells where placement is blocked. The white-region math shares the same dilation primitive as placement validation so display and `can_place` cannot diverge. Replaces the former per-frame line grid.

## Requirements

### Requirement: Three-state highlight cells during build mode
While build mode is active, the system SHALL render per-cell highlight planes in three states:
- **White**: the reachable placement region defined by the `adjacent` rule (see below)
- **Green**: cells under the ghost's foundation where placement is allowed
- **Red**: cells where placement is blocked (occupied cell, out of play area, or otherwise rejected by `can_place`)

#### Scenario: Valid ghost position shows green footprint
- **WHEN** the ghost hovers over a position where `can_place` returns `true`
- **THEN** every foundation cell under the ghost renders green

#### Scenario: Blocked cell under ghost shows red
- **WHEN** a foundation cell under the ghost is occupied by an entity, a bib, or lies outside the play area
- **THEN** that cell renders red

#### Scenario: Blocked cell in white region shows red
- **WHEN** a cell in the white region (not under the ghost) is occupied or outside the play area
- **THEN** that cell renders red

#### Scenario: Ghost cells beyond the white region show red
- **WHEN** the ghost has `adjacent > 0` and part of its foundation covers free cells outside the white region
- **THEN** those cells render red instead of green

#### Scenario: Unconstrained ghost colors freely
- **WHEN** the ghost has `adjacent <= 0` and its foundation covers a free cell outside the white region
- **THEN** that cell renders green

### Requirement: White region derived from adjacent rule
The white region SHALL be the union of every cell the ghost's foundation could cover in a placement satisfying the `adjacent` rule, computed as: friendly building footprint cells dilated by the ghost's `adjacent` value (Chebyshev), then dilated by the ghost's full foundation size in the X and Z directions respectively.

#### Scenario: Adjacent dilation around a friendly building
- **WHEN** a friendly 2x2 building exists and the ghost has `adjacent = 1`
- **THEN** white cells extend exactly 1 cell beyond the building footprint before foundation dilation

#### Scenario: Foundation dilation respects XZ size
- **WHEN** the ghost's foundation is 3 wide and 2 deep
- **THEN** the white region from step one is extended 3 cells in the X direction and 2 cells in the Z direction

#### Scenario: White cells render only in a cursor window
- **WHEN** white cells are displayed and the full white set exceeds the cursor-anchored radius of `max(foundation.x, foundation.y) * 0.5 + 3` around the ghost center (the same window the removed line grid used)
- **THEN** only white cells within that radius render, and the window follows the cursor

#### Scenario: Ghost adjacent value governs, not friendly buildings
- **WHEN** two friendly buildings exist with differing `adjacent` values
- **THEN** the white region uses only the ghost's `adjacent` value

#### Scenario: Bib cells act as foundation for dilation
- **WHEN** a friendly building has bib cells (e.g. a refinery dock) inside its foundation footprint
- **THEN** the bib cells dilate the white region exactly like regular foundation cells, even though the building registry stores only non-bib cells

#### Scenario: Adjacent zero means touching
- **WHEN** the ghost has `adjacent = 0`
- **THEN** white cells cover exactly the friendly building footprints dilated by the foundation size, and a placement one cell further out lies outside the white region

#### Scenario: Negative adjacent clamps to zero
- **WHEN** an `EntityData` declares `adjacent < 0`
- **THEN** the value is treated as 0 for both the white region and placement validation

#### Scenario: No friendly buildings means no white cells
- **WHEN** the player owns no buildings and the ghost has `adjacent > 0`
- **THEN** no white cells render, and the ghost's foundation cells still render green or red

### Requirement: Highlight cell plane mesh style
Every flat highlight cell (a cell whose corner heights are all equal, or a cell with no cell data) SHALL render as a flat plane that:
- Sits at Y = highest terrain corner height of its cell + a small tunable offset
  (`PlacementGridOverlay.PLANE_Y_OFFSET`, smoke-tuned to 0.025)
- Spans 95% of the cell size in XZ
- Has chamfered (beveled) corners rather than sharp square corners

#### Scenario: Cell height offset above terrain
- **WHEN** a flat highlight cell covers a terrain cell whose corner heights are h0..h3
- **THEN** the cell plane sits at max(h0..h3) + `PLANE_Y_OFFSET`

#### Scenario: Cell plane smaller than the cell
- **WHEN** a flat highlight cell is rendered on a cell of size `CellUtil.CELL_SIZE`
- **THEN** the plane's XZ footprint is 95% of `CellUtil.CELL_SIZE`

#### Scenario: Corners are beveled
- **WHEN** a flat highlight cell mesh is generated
- **THEN** each corner is cut (chamfered) rather than square

#### Scenario: Non-flat cells are not rendered as octagons
- **WHEN** a rendered cell's corner heights are not all equal
- **THEN** no flat octagon is generated for that cell; the cell renders per the
  "Terrain-matched non-flat highlight cells" requirement

### Requirement: Line grid removed
The line-based placement grid SHALL NOT be rendered during build mode; highlight cells are the only placement region feedback.

#### Scenario: Build mode renders no grid lines
- **WHEN** build mode is active
- **THEN** no line-grid quads (the former `_add_grid_and_indicators` output) are added to the preview

### Requirement: White region consistent with placement validation
The white region and placement validation SHALL share the same dilation primitive and the same clamped `adjacent` value. The white region SHALL be a superset of every valid placement's footprint, and every white cell SHALL be coverable by at least one placement that satisfies the `adjacent` rule. A rejected placement may still have its footprint fully inside the white region when its cells are individually reachable by different valid placements; the ghost's green/red coloring flags the actual hovered position.

#### Scenario: Valid placement lies inside white
- **WHEN** `_is_adjacency_satisfied` accepts a placement for a given ghost and friendly building set
- **THEN** every cell of that placement's footprint lies within the white region

#### Scenario: White cells are individually reachable
- **WHEN** any single white cell is considered
- **THEN** there exists at least one placement satisfying the `adjacent` rule whose foundation covers that cell

### Requirement: Terrain-matched non-flat highlight cells
A rendered cell whose four corner heights are not all equal SHALL render as a terrain-surface-matched mesh derived from those heights, in world order NW, NE, SW, SE (`TerrainSystem.get_cell_corner_heights`):
- The patch SHALL use the same XZ silhouette as the flat-cell octagon — the
  shared chamfered-octagon outline (`PlacementGridOverlay.CELL_COVERAGE`
  0.95 coverage, `CORNER_CHAMFER` corner cuts) centered on the cell — so flat
  and non-flat highlights line up edge for edge.
- Each patch vertex SHALL be evaluated on the cell's corresponding terrain
  triangle plane — the two planes formed by the four world corner points
  (`height × HEIGHT_STEP`) split along the `derive_crease` diagonal — at
  Y = plane height + `PlacementGridOverlay.PLANE_Y_OFFSET`, so the patch
  matches the two-triangle tile the terrain renderer draws and hugs it without
  z-fighting.
- The mesh SHALL split along the `derive_crease` diagonal (the `pick_diagonal`
  rule): the octagon splits at the two points where that diagonal crosses it,
  each half triangulated as a fan on its own triangle plane. When the four
  corners are coplanar either split is valid. When exactly one corner is the
  unique maximum, or one corner is the unique minimum, the split SHALL not pass
  through that corner. When two diagonally-opposite corners share the maximum
  (saddle pattern), the split SHALL connect that diagonal pair.
- No patch triangle SHALL straddle the crease: every vertex of a triangle lies
  on the same terrain plane, so the mesh folds exactly where the rendered tile
  folds rather than chording across the ridge.
- The mesh SHALL NOT contain any vertical or near-vertical face: it is a
  terrain-function surface only.
- The state color (white, green, or red per the existing color-assignment rules)
  SHALL be applied to the whole patch.
- The patch SHALL be generated from terrain data alone: no terrain art,
  catalog resolution, or GLB dependency.

This triangulation rule is the engine-side form of the `crease` derivation
baked into `TerrainObject` catalog entries (tools/isotem `derive_crease`), so a
generated patch matches the tessellation the terrain renderer draws for the
same corner data.

#### Scenario: Single-corner slope under a valid ghost
- **WHEN** the ghost hovers at a valid position and a footprint cell has one
  corner one step higher than the other three
- **THEN** that cell's highlight is a terrain-matched patch on the shared
  octagon silhouette, colored green, folded along the diagonal that does not
  pass through the raised corner

#### Scenario: Saddle cell folds along the raised diagonal
- **WHEN** a rendered cell has two diagonally-opposite corners raised above
  the other two
- **THEN** the patch's fold connects that raised diagonal pair

#### Scenario: Adjacent-raised ramp renders a planar patch
- **WHEN** a rendered cell has exactly two adjacent corners at the maximum,
  whether one step or two steps above the others
- **THEN** the patch surface is the single coplanar plane of the four corners

#### Scenario: Two-step steep cell
- **WHEN** a rendered cell's corners span two height steps with a unique
  maximum corner
- **THEN** the patch follows the single-corner rule of this requirement with
  the raised vertex at two steps (2 × `HEIGHT_STEP` + offset) above the base

#### Scenario: No vertical faces for any cell
- **WHEN** a non-flat highlight patch is generated for any corner pattern
- **THEN** every triangle's normal has `|normal.y| >= 0.5`, i.e. no vertical or
  near-vertical face is ever produced

#### Scenario: White region cells on non-flat terrain
- **WHEN** a white-region cell (not under the ghost) is non-flat
- **THEN** it renders the same terrain-matched patch in the white state color

#### Scenario: Blocked non-flat cell under the ghost
- **WHEN** a non-flat footprint cell under the ghost is blocked (occupied, out
  of play area, or otherwise rejected)
- **THEN** it renders the terrain-matched patch in red

#### Scenario: Highlights do not depend on terrain art
- **WHEN** the active terrain art is missing, a placeholder, or fails to
  resolve for the active theater
- **THEN** non-flat highlight patches still render exactly as specified,
  since they are built from corner data only
