## MODIFIED Requirements

### Requirement: ExitComponent defines exit point for units leaving buildings
The system SHALL provide an ExitComponent that defines where units spawn and exit from a building. ExitComponent SHALL specify `exit_offset: Vector3` (local-space offset from building origin for exit position), `spawn_offset: Vector3` (local-space offset for spawn position), and `exit_facing: int` (degrees). When a building has no ExitComponent, the unit SHALL spawn at the nearest free cell adjacent to the building; if no free cell is found within the search radius, the unit SHALL NOT be placed on the building's own cell and SHALL instead be retained for retry.

#### Scenario: Unit exits from war factory
- **WHEN** a vehicle is produced at a war factory with ExitComponent configured
- **THEN** the vehicle SHALL spawn at `spawn_offset` in the building's local space, transformed to world coordinates
- **THEN** the vehicle SHALL be positioned at `exit_offset` in the building's local space after exit
- **THEN** the vehicle SHALL face `exit_facing` degrees

#### Scenario: Building without ExitComponent spawns unit at free cell
- **WHEN** a unit is produced at a building without ExitComponent and a free adjacent cell exists
- **THEN** the unit SHALL spawn at the nearest free cell adjacent to the building
- **THEN** a warning SHALL be logged

#### Scenario: No free cell available near building
- **WHEN** a unit is produced at a building without ExitComponent and no free cell exists within the search radius
- **THEN** the unit SHALL NOT be placed on the building's own cell
- **THEN** a warning SHALL be logged and the unit SHALL be retained in the ready-to-spawn retry state
