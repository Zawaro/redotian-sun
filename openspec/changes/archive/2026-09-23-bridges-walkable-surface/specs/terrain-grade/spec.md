## ADDED Requirements

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
