## ADDED Requirements

### Requirement: Pathfinder and TerrainSystem integration shall be tested

A test file `test/integration/test_pathfinder_terrain.gd` SHALL contain tests verifying Pathfinder works with TerrainSystem height data.

#### Scenario: get_terrain_height returns valid float

- **WHEN** TerrainSystem has a grid initialized
- **THEN** `Pathfinder.get_terrain_height(Vector2i(0, 0))` returns a float (not null)

#### Scenario: find_path returns array on flat terrain

- **WHEN** `Pathfinder.find_path()` is called with start and end on flat terrain
- **THEN** the result is a `PackedVector3Array` with at least one waypoint

#### Scenario: find_path returns empty for same cell

- **WHEN** start and end are in the same cell
- **THEN** `find_path()` returns an empty array

### Requirement: MovementController signal integration shall be tested

A test file `test/integration/test_movement_signals.gd` SHALL contain tests verifying MovementController emits expected signals.

#### Scenario: arrived signal emitted on reaching target

- **WHEN** a MovementController completes a short move command
- **THEN** the `arrived` signal is emitted with a Vector3 position

#### Scenario: no arrived signal when target unreachable

- **WHEN** a MovementController is given a target surrounded by blocked cells
- **THEN** the `arrived` signal is NOT emitted within timeout
