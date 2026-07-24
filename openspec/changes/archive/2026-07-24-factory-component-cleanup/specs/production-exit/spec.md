## ADDED Requirements

### Requirement: ExitComponent defines exit point for units leaving buildings
The system SHALL provide an ExitComponent that defines where units spawn and exit from a building. ExitComponent SHALL specify `exit_cell_offset` (Vector2i), `spawn_cell_offset` (Vector2i), and `exit_facing` (int, degrees).

#### Scenario: Unit exits from war factory
- **WHEN** a vehicle is produced at a war factory with ExitComponent configured
- **THEN** the vehicle SHALL spawn at `spawn_cell_offset` relative to the building's top-left cell
- **THEN** the vehicle SHALL be positioned at `exit_cell_offset` after exit
- **THEN** the vehicle SHALL face `exit_facing` degrees

#### Scenario: Building without ExitComponent spawns unit at free cell
- **WHEN** a unit is produced at a building without ExitComponent
- **THEN** the unit SHALL spawn at the nearest free cell adjacent to the building
- **THEN** a warning SHALL be logged

### Requirement: ExitComponent positions unit using world coordinates
The system SHALL calculate the exit position using the building's top-left cell plus `exit_cell_offset` multiplied by cell size. The unit SHALL be placed at the exact world position, not snapped to cell center.

#### Scenario: Sub-cell precision for helipad exit
- **WHEN** a helipad has ExitComponent with exit_cell_offset = Vector2i(1, 1) on a 2x2 building
- **THEN** the aircraft SHALL be positioned at the center of the building (1.5 cells from top-left)
- **THEN** the aircraft SHALL NOT be snapped to the nearest cell center

### Requirement: ExitComponent emits unit_spawned signal
ExitComponent SHALL emit `unit_spawned(unit: Node3D)` after positioning the unit. ArtComponent SHALL listen to this signal to trigger door animations.

#### Scenario: Door animation triggered on exit
- **WHEN** a unit exits from a building with ExitComponent and ArtComponent
- **THEN** ExitComponent SHALL emit `unit_spawned(unit)`
- **THEN** ArtComponent SHALL play the `door_anim` sequence from ArtData

### Requirement: RallyPointComponent manages post-exit path
The system SHALL provide a RallyPointComponent that defines a path of waypoints units follow after exiting. RallyPointComponent SHALL store `rally_path: Array[Vector2i]`.

#### Scenario: Unit follows rally path after exit
- **WHEN** a unit exits from a building with RallyPointComponent and rally_path has 2+ waypoints
- **THEN** the unit SHALL move to each waypoint in sequence
- **THEN** the unit SHALL stop at the final waypoint

#### Scenario: Rally point set by player
- **WHEN** player Alt + Left Clicks on terrain while a building with RallyPointComponent is selected
- **THEN** RallyPointComponent SHALL update `rally_path` to the clicked cell
- **THEN** RallyPointComponent SHALL emit `rally_point_changed(path)`

#### Scenario: Rally point cleared
- **WHEN** player clears the rally point
- **THEN** RallyPointComponent SHALL reset `rally_path` to empty array
- **THEN** units SHALL exit to nearest free cell instead

### Requirement: RallyPointComponent toggled via EntityData
EntityData SHALL have `has_rally_point: bool`. EntityFactory SHALL create RallyPointComponent only when `has_rally_point == true`.

#### Scenario: Building with rally point support
- **WHEN** EntityData has `has_rally_point = true`
- **THEN** EntityFactory SHALL create and attach RallyPointComponent

#### Scenario: Building without rally point support
- **WHEN** EntityData has `has_rally_point = false`
- **THEN** EntityFactory SHALL NOT create RallyPointComponent
