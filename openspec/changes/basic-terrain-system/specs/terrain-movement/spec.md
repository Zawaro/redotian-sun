## ADDED Requirements

### Requirement: Pathfinder shall query terrain height for movement cost
The Pathfinder SHALL query TerrainSystem.get_height_at_world() to determine terrain height at each cell and apply movement cost modifiers.

#### Scenario: Height query during pathfinding
- **WHEN** Pathfinder.find_path() is called
- **THEN** it queries TerrainSystem for height at each neighbor cell

#### Scenario: Default height when no terrain
- **WHEN** TerrainSystem has no data for a cell
- **THEN** Pathfinder assumes height 0 (flat ground)

### Requirement: MovementController shall interpolate Y-position on slopes
When a unit moves onto a slope cell, the MovementController SHALL interpolate the Y-position based on progress through the cell (0.0 to 1.0).

#### Scenario: Single-height slope traversal
- **WHEN** unit enters a slope cell with height_level 1 at start (progress=0.0)
- **THEN** unit Y = 0.0 (start height)

#### Scenario: Mid-slope position
- **WHEN** unit is at progress 0.5 through a single-height slope
- **THEN** unit Y = 0.4075 (half of 0.815)

#### Scenario: End of slope
- **WHEN** unit reaches progress 1.0 at end of single-height slope
- **THEN** unit Y = 0.815 (full height step)

### Requirement: MovementController shall match unit angle to slope normal
When on a slope cell, the unit's rotation SHALL align with the slope's normal direction.

#### Scenario: North-facing slope alignment
- **WHEN** unit is on a slope facing north (rises toward -Z)
- **THEN** unit rotates to face the slope direction

### Requirement: TerrainSystem shall provide slope normal at position
The TerrainSystem SHALL calculate and return the slope normal vector at a given world position.

#### Scenario: Normal query for flat cell
- **WHEN** `TerrainSystem.get_normal_at_world(Vector3(0, 0, 0))` is called on a flat cell
- **THEN** the returned normal is Vector3(0, 1, 0) (straight up)

#### Scenario: Normal query for slope cell
- **WHEN** `TerrainSystem.get_normal_at_world()` is called on a north-facing slope
- **THEN** the returned normal is tilted toward the slope direction
