# terrain-grade Specification

## Purpose

Per-cell slope-grade classification distinguishing walkable graded faces (slopes/stairs) from sheer cliff faces, derived from the existing terrain height snapshot. LOS blocking consumes it to exempt walkable grades from the height-delta check.

## Requirements

### Requirement: Per-cell grade steps

The system SHALL provide `TerrainSystem.get_cell_grade_steps(cell) -> int` that returns the steepest adjacent-corner rise of the cell in raw height units (unscaled by `HEIGHT_STEP`): the maximum absolute height difference across the cell's four edges `[nw-ne, sw-se, nw-sw, ne-se]`. The value SHALL be computed from the world-lifetime height snapshot already used by `get_cell_max_height`, SHALL return 0 for out-of-bounds or empty-snapshot cells, and SHALL NOT introduce new persistent storage.

#### Scenario: Flat cell has zero grade
- **WHEN** a cell's four corners share the same raw height
- **THEN** `get_cell_grade_steps` returns 0

#### Scenario: Single-step graded slope reports one step
- **WHEN** a cell's corners span exactly one height level (e.g. raw corners `[0, 0, 1, 1]`)
- **THEN** `get_cell_grade_steps` returns 1

#### Scenario: Multi-step cliff face reports two or more
- **WHEN** a cell has an edge jumping two or more height levels (e.g. raw corners `[0, 0, 2, 2]`)
- **THEN** `get_cell_grade_steps` returns the steepest edge rise (2 or more)

#### Scenario: Stair pattern spanning two levels reports one
- **WHEN** a cell's corners span two height levels but every edge rises only one (e.g. raw corners `[0, 1, 1, 2]`)
- **THEN** `get_cell_grade_steps` returns 1, matching the walkable edge rise despite the two-level span

#### Scenario: Out-of-bounds cell reads zero
- **WHEN** the queried cell is outside the terrain diamond
- **THEN** `get_cell_grade_steps` returns 0

### Requirement: Grade reported per surface level
Grade classification SHALL be reportable for a surface level beyond the terrain surface. `TerrainSystem.get_cell_grade_steps(cell, level)` SHALL accept an optional level defaulting to 0: at level 0 it SHALL return the existing terrain corner grade; at a deck level it SHALL report that deck surface's grade relative to the adjacent surfaces at the same level, deriving from the level's walkable surface heights. A deck authored on one flat span grade SHALL report a flat (zero) internal grade. The value SHALL NOT introduce new persistent storage.

#### Scenario: Terrain grade unchanged at level 0
- **WHEN** `get_cell_grade_steps(cell)` is called without a level
- **THEN** it returns the same terrain corner grade as before

#### Scenario: Flat deck reports zero internal grade
- **WHEN** a deck authored on one flat span grade is queried at its level
- **THEN** its internal grade is flat

#### Scenario: Deck end grade reflects the span transition
- **WHEN** a high deck at the span grade is adjacent to ground at the base grade
- **THEN** the end cell reports a grade consistent with the four-level transition

#### Scenario: Out-of-bounds level reads zero
- **WHEN** a grade is queried for a `(cell, level)` with no surface
- **THEN** it returns 0
