## RENAMED Requirements

- FROM: ### Requirement: Combined infantry-scoped capacity
- TO: ### Requirement: Combined sharing-scoped capacity

## MODIFIED Requirements

### Requirement: In-flight sub-slot registry
The system SHALL provide a `CellReservation` autoload owning all sub-slot claims for `shares_cell = true` units en route to a cell. The registry SHALL map each cell to up to `CellSubPositions.get_slot_count()` owned slots. It SHALL be the single source of truth for in-flight slot occupancy and combined cell capacity for sharing-unit targeting.

#### Scenario: Reserve an available slot
- **WHEN** `reserve_sub_slot(cell, owner)` is called on a cell with fewer claims than `CellSubPositions.get_slot_count()`
- **THEN** the owner SHALL be assigned the lowest-numbered free slot and the claim SHALL be immediately visible to all subsequent calls in the same frame

#### Scenario: Cell is full
- **WHEN** `reserve_sub_slot(cell, owner)` is called on a cell with `CellSubPositions.get_slot_count()` claims
- **THEN** the call SHALL return -1 and no claim SHALL be made

#### Scenario: Release a claim
- **WHEN** `release_sub_slot(cell, owner)` is called for a claim held by owner
- **THEN** the slot SHALL become available and `get_available_sub_slot(cell)` SHALL return it

#### Scenario: Query claim ownership
- **WHEN** `get_slot_owner(cell, slot)` is called for a claimed slot
- **THEN** it SHALL return the owning entity

### Requirement: Combined sharing-scoped capacity
`is_cell_full(cell)` SHALL return true when `physical idle sharer count + in-flight claims >= CellSubPositions.get_slot_count()`. The capacity query SHALL apply only to sharing-unit targeting; vehicle blocking SHALL remain purely physical.

#### Scenario: In-flight units count toward capacity
- **WHEN** the capacity in sharers hold claims on a cell but none have arrived
- **THEN** a targeting query SHALL treat the cell as full

#### Scenario: Physical + claims combine
- **WHEN** a cell has 1 idle sharer and in-flight claims bringing the total to the capacity
- **THEN** a targeting query SHALL treat the cell as full

#### Scenario: Vehicle blocking unaffected by claims
- **WHEN** a vehicle pathing check queries a cell with only in-flight sharing-unit claims
- **THEN** the cell SHALL NOT be blocked for the vehicle

#### Scenario: Capacity follows rules
- **WHEN** `shared_slots_per_cell = 4`
- **THEN** `is_cell_full` is false at 3 idle sharers and true at 4
