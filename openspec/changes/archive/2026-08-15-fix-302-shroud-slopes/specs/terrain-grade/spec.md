# terrain-grade Specification (delta)

## ADDED Requirements

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
