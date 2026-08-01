## ADDED Requirements

### Requirement: Sharers distribute by capacity
The system SHALL separate sharers from non-sharers when processing a group move command. Units whose MovementController `shares_cell()` returns true SHALL be distributed to cells near the target with at most `CellSubPositions.get_slot_count()` per cell, using `CellReservation` combined capacity. Each sharer SHALL be assigned a sub-slot at movement start inside `MovementController.set_target_position`; SelectionManager SHALL NOT pre-assign slots. Non-sharers SHALL use the existing offset-based vehicle formation.

#### Scenario: Group move with mixed units
- **WHEN** a player issues a move command with 6 sharers and 2 non-sharers selected
- **THEN** sharers are spread across cells near the target (≤ capacity per cell) using combined capacity, and non-sharers use existing offset logic

#### Scenario: Sharer cell search
- **WHEN** `_find_sharer_cell()` is called with a target cell at capacity
- **THEN** it spirals outward to find the nearest cell below capacity
