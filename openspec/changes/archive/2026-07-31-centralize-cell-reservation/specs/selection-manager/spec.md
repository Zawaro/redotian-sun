## MODIFIED Requirements

### Requirement: Infantry cell pre-assignment (modified)
When infantry units are selected and a move command is issued, `request_move()` SHALL pre-assign each infantry to a cell using spiral search from the target cell, with max 3 per cell based on `CellReservation` combined capacity (physical idle infantry + in-flight claims). `request_move()` SHALL NOT pre-assign sub-slots; slot assignment SHALL occur at movement start inside `MovementController.set_target_position` via `CellReservation.reserve_sub_slot`.

#### Scenario: Three infantry to same cell (modified)
- **WHEN** 3 infantry move to a cell with no existing infantry and no claims
- **THEN** all 3 are assigned to the target cell, and each claims a distinct sub-slot (0, 1, 2) at movement start

#### Scenario: Infantry overflow to adjacent cells (modified)
- **WHEN** 4 infantry move to a cell
- **THEN** 3 are assigned to the target cell, the 4th is assigned to the nearest free adjacent cell

#### Scenario: Target cell already has infantry (modified)
- **WHEN** 2 infantry move to a cell that already has 1 idle infantry
- **THEN** the 2 new infantry fill the remaining capacity, totaling 3 in the cell

#### Scenario: In-flight claims fill capacity (added)
- **WHEN** a cell has idle infantry plus in-flight claims totaling 3
- **THEN** `_find_infantry_cell()` assigns new infantry to a neighboring cell instead

### Requirement: Cell reservation during move (unchanged)
Before issuing move commands, SelectionManager SHALL clear all existing reservations, then reserve each selected entity's current cell. If a vehicle's target cell is already reserved, a fallback target is found via spiral search. This requirement covers vehicle cell reservation only; infantry sub-slot claims are handled by `CellReservation`.

#### Scenario: Reserve current cells (unchanged)
- **WHEN** `request_move()` is called
- **THEN** all existing reservations are cleared, and each entity's current cell is reserved

#### Scenario: Fallback on reserved target (unchanged)
- **WHEN** a vehicle's target cell is already reserved
- **THEN** `CellUtil.spiral_first_free()` finds the nearest available cell within radius 8
