## ADDED Requirements

### Requirement: Building cell lookup
`SpatialHash` SHALL expose `is_building_cell(cell: Vector2i) -> bool` that returns true when the cell is part of any registered building footprint. It SHALL derive from the existing building-cell tracking without triggering a rebuild.

#### Scenario: Building cell lookup
- **WHEN** a building footprint is registered covering cell (5, 3)
- **THEN** `is_building_cell(Vector2i(5, 3))` returns true

#### Scenario: Non-building cell lookup
- **WHEN** no building covers cell (5, 4)
- **THEN** `is_building_cell(Vector2i(5, 4))` returns false

#### Scenario: No rebuild triggered
- **WHEN** `is_building_cell` is called during normal gameplay
- **THEN** it performs a direct lookup and does not trigger a grid rebuild
