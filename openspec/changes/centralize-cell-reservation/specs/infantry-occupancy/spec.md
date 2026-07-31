## MODIFIED Requirements

### Requirement: Infantry cell capacity (modified)
The system SHALL allow up to 3 infantry to occupy the same cell. Capacity SHALL combine physical idle infantry (from the SpatialHash grid) with in-flight sub-slot claims held by `CellReservation`, and SHALL be infantry-scoped (vehicle blocking uses physical presence only). Idle infantry cells SHALL block pathfinding for non-infantry entities (vehicles cannot path through) when at least 1 idle infantry is present.

#### Scenario: Vehicle blocked by single infantry (unchanged)
- **WHEN** a vehicle attempts to pathfind through a cell with 1 idle infantry
- **THEN** the cell is treated as blocked for the vehicle

#### Scenario: Infantry enters cell with 2 infantry (modified)
- **WHEN** an infantry unit attempts to enter a cell with 2 idle infantry and no claims
- **THEN** the cell is treated as not blocked (capacity not reached)

#### Scenario: Infantry blocked at capacity (modified)
- **WHEN** an infantry unit attempts to enter a cell with 3 idle infantry, or a combination of idle infantry and in-flight claims totaling 3
- **THEN** the cell is treated as full and the unit spreads to a neighboring cell

#### Scenario: In-flight claims count toward capacity (added)
- **WHEN** a cell has fewer than 3 idle infantry but in-flight claims bring the total to 3
- **THEN** the cell is treated as full for infantry targeting

### Requirement: Sub-slot positioning (unchanged)
The system SHALL assign each infantry in a cell a deterministic sub-slot position. Positions SHALL be generated per-cell using a seeded PRNG (Mulberry32) with trigonometric placement: 3 positions evenly spaced at 120° intervals on a circle of radius `(half_cell - 0.15) * 0.7`, with a random base angle seeded from cell coordinates. `CellSubPositions` performs no occupancy tracking; slot occupancy is the responsibility of the SpatialHash grid (present units) and `CellReservation` (in-flight claims).

#### Scenario: Deterministic positions (unchanged)
- **WHEN** `CellSubPositions.get_sub_positions(cell)` is called twice with the same cell
- **THEN** both calls return identical positions

#### Scenario: Margin enforcement (unchanged)
- **WHEN** sub-positions are generated for any cell
- **THEN** all positions are at least 0.15 units from the cell edge

#### Scenario: Slot spacing (unchanged)
- **WHEN** sub-positions are generated for any cell
- **THEN** all positions are at least 0.4 units apart from each other

### Requirement: Infantry group pre-assignment (modified)
The system SHALL separate infantry from vehicles when processing a group move command. Infantry SHALL be distributed to cells near the target with max 3 per cell, using `CellReservation` combined capacity. Each infantry SHALL be assigned a sub-slot at movement start inside `MovementController.set_target_position`; SelectionManager SHALL NOT pre-assign slots.

> **Note:** This requirement describes SelectionManager's `_find_infantry_cell()` behavior, which is a selection/movement concern. It is included here for completeness but may be moved to the selection-manager spec in the future.

#### Scenario: Group move with mixed units (modified)
- **WHEN** a player issues a move command with 6 infantry and 2 vehicles selected
- **THEN** infantry are spread across cells near the target (≤3 per cell) using combined capacity, and vehicles use existing offset logic

#### Scenario: Infantry cell search (modified)
- **WHEN** `_find_infantry_cell()` is called with a target cell at capacity
- **THEN** it spirals outward to find the nearest cell with capacity < 3
