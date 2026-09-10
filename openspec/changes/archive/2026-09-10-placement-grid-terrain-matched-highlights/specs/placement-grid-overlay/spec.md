## MODIFIED Requirements

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

## ADDED Requirements

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
