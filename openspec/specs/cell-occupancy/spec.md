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

### Requirement: Per-level shared cell capacity
Cell capacity SHALL be evaluated per surface level. Each level of a cell (ground and each deck) SHALL have its own `shared_slots_per_cell` places, combining physical idle sharers at that level with in-flight `CellReservation` claims for that level. A deck's capacity SHALL NOT be reduced by ground occupants beneath it, and vice versa. Idle sharer cells SHALL block pathfinding for non-sharing entities at that level only. When no level is supplied, capacity SHALL resolve at level 0.

#### Scenario: Deck capacity independent of ground
- **WHEN** a cell's ground level has `shared_slots_per_cell` idle sharers and its deck level is empty
- **THEN** the deck level is not full

#### Scenario: Ground capacity independent of deck
- **WHEN** a cell's deck level has `shared_slots_per_cell` idle sharers and its ground level is empty
- **THEN** the ground level is not full

#### Scenario: Ground level blocks at capacity
- **WHEN** a cell's ground level reaches `shared_slots_per_cell` idle sharers
- **THEN** the ground level is full for sharing-unit targeting

#### Scenario: Default level is ground
- **WHEN** a capacity query is made without a level
- **THEN** it resolves against level 0

### Requirement: Per-level sub-slot positions
`CellSubPositions` SHALL generate sub-slot positions per surface level, so a deck's places are positioned independently of the ground's. `CellSubPositions.get_sub_positions(cell, level, slot_count)` and `get_sub_position(cell, level, slot)` SHALL include the level in their seeded placement, and SHALL default to level 0. Positions SHALL remain deterministic for a given `(cell, level)` and satisfy the existing margin and spacing guarantees.

#### Scenario: Deck positions differ from ground
- **WHEN** sub-slot positions are generated for the same cell at level 0 and a deck level
- **THEN** the two sets are independent and do not have to coincide

#### Scenario: Deterministic per level
- **WHEN** `get_sub_positions(cell, level)` is called twice for the same cell and level
- **THEN** both calls return identical positions

#### Scenario: Default level preserves positions
- **WHEN** `get_sub_positions(cell)` is called without a level
- **THEN** it returns the level-0 positions, matching pre-change behavior
