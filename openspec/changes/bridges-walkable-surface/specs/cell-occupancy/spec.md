## ADDED Requirements

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
