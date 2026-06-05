## MODIFIED Requirements

### Requirement: MovementController shall interpolate Y-position on slopes
When a unit moves onto a slope cell, the MovementController SHALL interpolate the Y-position based on progress through the cell (0.0 to 1.0), using the terrain height data from TerrainSystem.

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
When on a slope cell, the unit's rotation SHALL align with the slope's normal direction, queried from TerrainSystem.

#### Scenario: North-facing slope alignment
- **WHEN** unit is on a slope facing north (rises toward -Z)
- **THEN** unit rotates to face the slope direction

## ADDED Requirements

### Requirement: MovementController shall query terrain height at waypoints
The MovementController SHALL query TerrainSystem for the height at each waypoint position to ensure units follow terrain elevation.

#### Scenario: Waypoint height query
- **WHEN** MovementController processes a waypoint at position Vector3(4.0, 0.0, 6.0)
- **THEN** it queries TerrainSystem.get_height_at_world() and adjusts the waypoint Y accordingly

#### Scenario: Default height when no terrain
- **WHEN** TerrainSystem has no data for a waypoint position
- **THEN** MovementController uses Y = 0.0 (flat ground)
