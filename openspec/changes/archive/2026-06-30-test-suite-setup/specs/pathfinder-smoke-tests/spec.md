## ADDED Requirements

### Requirement: Smoke tests shall exist for Pathfinder

A test file `test/unit/test_pathfinder.gd` SHALL contain tests for Pathfinder static pure functions.

#### Scenario: Test file created

- **WHEN** `test/unit/test_pathfinder.gd` is opened
- **THEN** it extends `GutTest`
- **THEN** it contains test methods prefixed with `test_`

### Requirement: world_to_cell shall be tested

Tests SHALL verify `Pathfinder.world_to_cell()` converts world positions to grid cells correctly.

#### Scenario: Origin position maps to cell (0,0)

- **WHEN** `world_to_cell(Vector3.ZERO)` is called
- **THEN** the result is `Vector2i(0, 0)`

#### Scenario: Positive position maps to correct cell

- **WHEN** `world_to_cell(Vector3(5.0, 0.0, 5.0))` is called
- **THEN** the result is `Vector2i(2, 2)`

#### Scenario: Negative position maps to correct cell

- **WHEN** `world_to_cell(Vector3(-3.0, 0.0, -3.0))` is called
- **THEN** the result is `Vector2i(-2, -2)`

### Requirement: cell_to_world shall be tested

Tests SHALL verify `Pathfinder.cell_to_world()` converts grid cells to world positions correctly.

#### Scenario: Cell (0,0) maps to world center

- **WHEN** `cell_to_world(Vector2i(0, 0))` is called
- **THEN** the result is `Vector3(1.0, 0.0, 1.0)`

#### Scenario: Cell to world roundtrip preserves cell

- **WHEN** a cell is converted to world position and back to cell
- **THEN** the original cell is recovered

### Requirement: _cell_key shall be tested

Tests SHALL verify `Pathfinder._cell_key()` produces deterministic string output.

#### Scenario: Cell key is deterministic

- **WHEN** `_cell_key(Vector2i(3, 5))` is called twice
- **THEN** both calls return `"3,5"`
