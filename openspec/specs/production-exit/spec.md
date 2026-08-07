## ADDED Requirements

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

#### Scenario: No free cell available near building
- **WHEN** a unit is produced at a building without ExitComponent and no free cell exists within the search radius
- **THEN** the unit SHALL NOT be placed on the building's own cell
- **THEN** a warning SHALL be logged and the unit SHALL be retained in the ready-to-spawn retry state

### Requirement: ExitComponent positions unit using local-space offsets
The system SHALL calculate the exit position by transforming `exit_offset` from the building's local space to world coordinates via `building.to_global(exit_offset)`. The unit SHALL be placed at the exact world position, not snapped to cell center.

#### Scenario: Sub-cell precision for helipad exit
- **WHEN** a helipad has ExitComponent with exit_offset = Vector3(2, 0, 2) (local-space offset)
- **THEN** the aircraft SHALL be positioned at the building's local offset transformed to world space
- **THEN** the aircraft SHALL NOT be snapped to the nearest cell center

### Requirement: ExitComponent emits unit_spawned signal
ExitComponent SHALL emit `unit_spawned(unit: Node3D)` after positioning the unit. ArtComponent SHALL listen to this signal to trigger door animations.

#### Scenario: Door animation triggered on exit
- **WHEN** a unit exits from a building with ExitComponent and ArtComponent
- **THEN** ExitComponent SHALL emit `unit_spawned(unit)`
- **THEN** ArtComponent SHALL play the `door_anim` sequence from ArtData

### Requirement: RallyPointComponent manages post-exit destination
The system SHALL provide a RallyPointComponent that defines a single destination cell units move to after exiting. RallyPointComponent SHALL store `rally_point: Vector2i`.

#### Scenario: Unit moves to rally point after exit
- **WHEN** a unit exits from a building with RallyPointComponent and a rally point is set
- **THEN** the unit SHALL move to the rally point cell

#### Scenario: Rally point set by player
- **WHEN** player Alt + Left Clicks on terrain while a building with RallyPointComponent is selected
- **THEN** RallyPointComponent SHALL update `rally_point` to the clicked cell
- **THEN** RallyPointComponent SHALL emit `rally_point_changed(cell)`

#### Scenario: Rally point cleared
- **WHEN** player clears the rally point
- **THEN** RallyPointComponent SHALL reset `rally_point` to `Vector2i(-1, -1)` (sentinel for unset)
- **THEN** units SHALL exit to nearest free cell instead

### Requirement: RallyPointComponent toggled via EntityData
EntityData SHALL have `has_rally_point: bool`. EntityFactory SHALL create RallyPointComponent only when `has_rally_point == true`.

#### Scenario: Building with rally point support
- **WHEN** EntityData has `has_rally_point = true`
- **THEN** EntityFactory SHALL create and attach RallyPointComponent

#### Scenario: Building without rally point support
- **WHEN** EntityData has `has_rally_point = false`
- **THEN** EntityFactory SHALL NOT create RallyPointComponent
