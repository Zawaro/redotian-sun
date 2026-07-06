## ADDED Requirements

### Requirement: grid_cells has a setter that maintains vertex grid consistency
The `grid_cells` variable in TerrainSystem SHALL have a setter that reinitializes the vertex grid when the value changes.

#### Scenario: External code sets grid_cells
- **WHEN** external code assigns `TerrainSystem.grid_cells = 64`
- **THEN** `_init_vertex_grid()` is called automatically to resize the vertex grid

#### Scenario: Invalid grid_cells value is rejected
- **WHEN** external code assigns `TerrainSystem.grid_cells = 0` or a negative value
- **THEN** the value is clamped to a minimum of 1

#### Scenario: grid_cells value within bounds is accepted
- **WHEN** external code assigns `TerrainSystem.grid_cells = 32`
- **THEN** `grid_cells` is set to 32 and vertex grid is reinitialized
