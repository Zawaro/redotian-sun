# cell-reservation Specification

## Purpose

`CellReservation` owns in-flight sharer sub-slot claims, the "coming" half of cell occupancy. Present occupancy is derived from the SpatialHash grid; this registry holds claims for units en route to a cell.
## Requirements
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

### Requirement: Present/coming occupancy split
Present occupancy SHALL be derived from the SpatialHash grid using each present infantry's assigned slot, not from registry claims. The registry SHALL hold claims only for units not yet present in the destination cell.

#### Scenario: Idle infantry slot visible
- **WHEN** a unit targeting a cell queries occupancy
- **THEN** it SHALL observe the `_assigned_slot` of infantry already present in that cell, including IDLE infantry, without requiring a registry claim

#### Scenario: In-flight unit holds claim
- **WHEN** a unit is en route to a cell it has claimed
- **THEN** the claim SHALL count toward the cell's capacity until the unit arrives

### Requirement: Idempotent same-cell reservation
A re-reserve of the same cell by the same owner SHALL return the existing claim unchanged. A reserve of a different cell SHALL release the owner's prior claim first.

#### Scenario: Re-issuing same destination
- **WHEN** `reserve_sub_slot(cell, owner)` is called twice for the same cell and owner
- **THEN** both calls SHALL return the same slot and no churn SHALL occur

#### Scenario: Move to new cell releases old claim
- **WHEN** an owner holding a claim on cell A calls `reserve_sub_slot(B, owner)`
- **THEN** the claim on A SHALL be released before the claim on B is made

### Requirement: Full-cell spread fallback
When no free slot is available on the target cell, the unit SHALL spread to the nearest cell with a free slot via `_find_nearest_free_cell` and claim there, rather than settling at the cell center.

#### Scenario: Full cell causes spread
- **WHEN** a unit's target cell has no free slot
- **THEN** the unit SHALL claim the nearest adjacent cell with capacity and move to its sub-slot

### Requirement: Automatic cleanup on owner free
When an owner node is freed, all of its sub-slot claims SHALL be released automatically.

#### Scenario: Death releases claim
- **WHEN** an infantry owning a claim is freed (health_zero → queue_free)
- **THEN** its slot SHALL become available after the node leaves the tree

#### Scenario: Stale owner pruned on read
- **WHEN** a read encounters a claim whose owner is no longer a valid instance
- **THEN** the claim SHALL be discarded and the slot SHALL be reported available

### Requirement: Race-free assignment under batching
Slot assignment SHALL be deterministic: with GDScript single-threaded execution and ordered `_execute_move` batching, a claim made by an earlier unit SHALL be visible to a later unit in the same batch.

#### Scenario: Group move assigns distinct slots
- **WHEN** 3 infantry in one move order target the same cell
- **THEN** they SHALL be assigned slots 0, 1, 2 in execution order, with no duplicates

#### Scenario: Concurrent orders do not pile
- **WHEN** a second move order targets a cell whose 3 slots are already claimed by in-flight infantry
- **THEN** the new infantry SHALL spread to a neighboring cell via the fallback instead of sharing a taken slot

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

