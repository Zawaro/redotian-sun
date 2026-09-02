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
Every highlight cell SHALL be rendered as a flat plane that:
- Sits at Y = highest terrain corner height of its cell + a small tunable offset (`PlacementGridOverlay.PLANE_Y_OFFSET`, smoke-tuned to 0.025)
- Spans 95% of the cell size in XZ
- Has chamfered (beveled) corners rather than sharp square corners

#### Scenario: Cell height offset above terrain
- **WHEN** a highlight cell covers a terrain cell whose corner heights are h0..h3
- **THEN** the cell plane sits at max(h0..h3) + `PLANE_Y_OFFSET`

#### Scenario: Cell plane smaller than the cell
- **WHEN** a highlight cell is rendered on a cell of size `CellUtil.CELL_SIZE`
- **THEN** the plane's XZ footprint is 95% of `CellUtil.CELL_SIZE`

#### Scenario: Corners are beveled
- **WHEN** a highlight cell mesh is generated
- **THEN** each corner is cut (chamfered) rather than square

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
