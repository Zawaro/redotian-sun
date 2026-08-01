# cell-occupancy Specification

## Purpose
TBD - created by archiving change locomotor-shares-cell. Update Purpose after archive.
## Requirements
### Requirement: Shared cell capacity
The system SHALL allow up to `GlobalRules.shared_slots_per_cell` units whose Locomotor has `shares_cell = true` to occupy the same cell. Capacity SHALL combine physical idle sharers (from the SpatialHash grid) with in-flight sub-slot claims held by `CellReservation`, and SHALL be sharing-scoped (vehicle blocking uses physical presence only). Idle sharer cells SHALL block pathfinding for non-sharing entities (vehicles cannot path through) when at least 1 idle sharer is present.

#### Scenario: Vehicle blocked by single sharer
- **WHEN** a vehicle attempts to pathfind through a cell with 1 idle `shares_cell = true` unit
- **THEN** the cell is treated as blocked for the vehicle

#### Scenario: Sharer enters cell with 2 sharers
- **WHEN** a `shares_cell = true` unit attempts to enter a cell with 2 idle sharers and no claims
- **THEN** the cell is treated as not blocked (capacity not reached)

#### Scenario: Sharer blocked at capacity
- **WHEN** a `shares_cell = true` unit attempts to enter a cell with `shared_slots_per_cell` idle sharers, or a combination of idle sharers and in-flight claims totaling the capacity
- **THEN** the cell is treated as full and the unit spreads to a neighboring cell

#### Scenario: In-flight claims count toward capacity
- **WHEN** a cell has fewer than the capacity in idle sharers but in-flight claims bring the total to the capacity
- **THEN** the cell is treated as full for sharing-unit targeting

#### Scenario: Capacity follows rules
- **WHEN** `shared_slots_per_cell = 4` is configured
- **THEN** the cell is full at 4 sharers, not at 3

### Requirement: Sub-slot positioning
The system SHALL assign each sharer a deterministic sub-slot position. Positions SHALL be generated per-cell using a seeded PRNG (Mulberry32) with trigonometric placement: `CellSubPositions.get_slot_count()` positions evenly spaced at equal angular intervals on a circle of radius `(half_cell - 0.15) * 0.7`, with a random base angle seeded from cell coordinates. `CellSubPositions` SHALL expose `get_slot_count()` resolving `GlobalRules.shared_slots_per_cell` with a fallback of 3, and SHALL perform no occupancy tracking; slot occupancy is the responsibility of the SpatialHash grid (present units) and `CellReservation` (in-flight claims).

#### Scenario: Deterministic positions
- **WHEN** `CellSubPositions.get_sub_positions(cell)` is called twice with the same cell
- **THEN** both calls return identical positions

#### Scenario: Margin enforcement
- **WHEN** sub-positions are generated for any cell
- **THEN** all positions are at least 0.15 units from the cell edge

#### Scenario: Slot spacing
- **WHEN** sub-positions are generated for any cell
- **THEN** all positions are at least `min_slot_dist` apart from each other

#### Scenario: Geometry follows capacity
- **WHEN** `shared_slots_per_cell = 4` is configured
- **THEN** `get_sub_positions(cell)` returns 4 positions

### Requirement: Sharing repulsion bypass
The system SHALL NOT apply repulsion forces between two `shares_cell = true` units during movement. Sharers SHALL freely overlap with other sharers while moving.

#### Scenario: Two sharers moving nearby
- **WHEN** two `shares_cell = true` units are both in MOVING state and within repulsion range
- **THEN** neither unit receives a repulsion push from the other

#### Scenario: Sharer repelled by vehicle
- **WHEN** a `shares_cell = true` unit is in MOVING state near a moving non-sharing vehicle
- **THEN** the sharer receives normal repulsion from the vehicle

