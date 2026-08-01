## RENAMED Requirements

- FROM: ### Requirement: Infantry cell capacity
- TO: ### Requirement: Shared cell capacity

## MODIFIED Requirements

### Requirement: Blocked cells from idle units
During rebuild, SpatialHash SHALL populate `_blocked_cells` with cells containing IDLE units whose MovementController `shares_cell()` returns false. Sharing cells are tracked separately in `_shared_cell_counts`.

#### Scenario: Idle vehicle blocks cell
- **WHEN** a vehicle with `shares_cell() == false` is IDLE at cell (5, 3)
- **THEN** `_blocked_cells` contains key for (5, 3)

#### Scenario: Idle sharer counted, not blocked
- **WHEN** a unit with `shares_cell() == true` is IDLE at cell (5, 3)
- **THEN** `_shared_cell_counts[(5,3)]` increments, `_blocked_cells` does NOT contain (5, 3)

#### Scenario: Moving units not counted
- **WHEN** a unit is in MOVING or ROTATING state
- **THEN** it is neither blocked nor counted in shared cells

### Requirement: Shared cell capacity
Each cell SHALL support up to `CellSubPositions.get_slot_count()` idle sharers. `is_cell_full_for_shared(cell)` SHALL return true when count >= the capacity.

#### Scenario: Cell below capacity not full
- **WHEN** `_shared_cell_counts[cell]` is one less than `CellSubPositions.get_slot_count()`
- **THEN** `is_cell_full_for_shared(cell)` returns false

#### Scenario: Cell at capacity is full
- **WHEN** `_shared_cell_counts[cell]` equals `CellSubPositions.get_slot_count()`
- **THEN** `is_cell_full_for_shared(cell)` returns true
