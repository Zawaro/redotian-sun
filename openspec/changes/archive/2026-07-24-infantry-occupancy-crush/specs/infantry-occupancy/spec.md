## ADDED Requirements

### Requirement: Infantry cell capacity
The system SHALL allow up to 3 infantry entities to occupy the same cell. Idle infantry cells SHALL be blocked for non-infantry entities when at least 1 idle infantry is present. Infantry cells SHALL be blocked for infantry when at capacity (3 idle infantry). Moving infantry do not block cells.

#### Scenario: Vehicle blocked by single infantry
- **WHEN** a vehicle attempts to pathfind through a cell with 1 idle infantry
- **THEN** the cell is treated as blocked for the vehicle

#### Scenario: Infantry enters cell with 2 infantry
- **WHEN** an infantry unit attempts to enter a cell with 2 idle infantry
- **THEN** the cell is treated as not blocked (capacity not reached)

#### Scenario: Infantry blocked at capacity
- **WHEN** an infantry unit attempts to enter a cell with 3 idle infantry
- **THEN** the cell is treated as blocked for the infantry

### Requirement: Sub-slot positioning
The system SHALL assign each infantry in a cell a deterministic sub-slot position. Positions SHALL be generated per-cell using a seeded PRNG (Mulberry32) with trigonometric placement: 3 positions evenly spaced at 120° intervals on a circle of radius `(half_cell - 0.15) * 0.7`, with a random base angle seeded from cell coordinates.

#### Scenario: Deterministic positions
- **WHEN** `CellSubPositions.get_sub_positions(cell)` is called twice with the same cell
- **THEN** both calls return identical positions

#### Scenario: Margin enforcement
- **WHEN** sub-positions are generated for any cell
- **THEN** all positions are at least 0.15 units from the cell edge

#### Scenario: Slot spacing
- **WHEN** sub-positions are generated for any cell
- **THEN** all positions are at least 0.4 units apart from each other

### Requirement: Infantry movement skips rotation
The system SHALL transition infantry directly from IDLE to MOVING without entering the ROTATING state. Infantry SHALL face their movement direction immediately on the first frame of movement.

#### Scenario: Infantry move command
- **WHEN** an infantry unit receives a move command
- **THEN** the MovementController enters MOVING state directly (skips ROTATING)

### Requirement: Infantry repulsion bypass
The system SHALL NOT apply repulsion forces between infantry entities during movement. Infantry SHALL freely overlap with other infantry while moving.

#### Scenario: Two infantry moving nearby
- **WHEN** two infantry units are both in MOVING state and within repulsion range
- **THEN** neither unit receives a repulsion push from the other

#### Scenario: Infantry repelled by vehicle
- **WHEN** an infantry unit is in MOVING state near a moving vehicle
- **THEN** the infantry receives normal repulsion from the vehicle

### Requirement: Infantry group pre-assignment
The system SHALL separate infantry from vehicles when processing a group move command. Infantry SHALL be distributed to cells near the target with max 3 per cell. Each infantry SHALL receive an assigned sub-slot position before movement begins.

#### Scenario: Group move with mixed units
- **WHEN** a player issues a move command with 6 infantry and 2 vehicles selected
- **THEN** infantry are assigned to 2 cells near the target (3 each) with sub-slot positions, and vehicles use existing offset logic

#### Scenario: Infantry cell search
- **WHEN** `_find_infantry_cell()` is called with a target cell at capacity
- **THEN** it spirals outward to find the nearest cell with capacity < 3
