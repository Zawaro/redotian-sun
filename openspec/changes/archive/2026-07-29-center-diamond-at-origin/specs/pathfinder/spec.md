## MODIFIED Requirements

### Requirement: Pathfinder cell-to-world-with-height
`Pathfinder.cell_to_world_with_height(cell)` SHALL return a world-space position centered at world origin (0,0,0) using the same centering formula as `CellUtil.cell_to_world()`. The Y component SHALL be the terrain height at that cell.

#### Scenario: Path endpoint at world origin
- **WHEN** `cell_to_world_with_height(Vector2i(50, 50))` is called on a 50×50 grid
- **THEN** the returned position is near `Vector3(0, height, 0)` (diamond center)

### Requirement: Pathfinder uses centered coordinates
`Pathfinder.find_path()` SHALL convert start and end world positions to cell coordinates using centered `CellUtil.world_to_cell()`. Path waypoints SHALL be converted back to centered world positions using `CellUtil.cell_to_world()`.

#### Scenario: Path waypoints are centered
- **WHEN** `find_path(start_world, end_world)` is called on a 50×50 grid
- **THEN** all waypoints in the returned `PackedVector3Array` are centered at world origin (negative and positive coords)
