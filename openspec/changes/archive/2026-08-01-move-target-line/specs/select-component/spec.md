## ADDED Requirements

### Requirement: Move target line drawing
When a selected unit has a `MovementController` and is executing a move order, `SelectComponent` SHALL draw a green line from the unit to the final cell of its current move order, with a small filled marker at the destination cell center. When the unit has an active attack target (`CombatComponent.get_target()`), the line SHALL end at the attack target's current position instead of the move order's destination cell, so the marker tracks the enemy entity as it moves. The line SHALL use the same layer treatment as the rally line (unshaded, `no_depth_test`, `render_priority = 100`).

#### Scenario: Line appears when a selected unit is ordered to move
- **WHEN** a selected unit's `MovementController` starts a new move order from a genuine player order (not an internal re-path or a scatter/nudge triggered by another unit)
- **THEN** a green move target line is shown from the unit to its destination cell with a filled marker at the destination

#### Scenario: Line points at the enemy during an attack
- **WHEN** a selected unit with an active attack target (`CombatComponent.get_target()` is valid) issues a move toward that target
- **THEN** the move target line is shown from the unit to the attack target's current position, and the marker tracks the target as it moves

#### Scenario: Line does not appear or restart on internal re-paths
- **WHEN** a selected unit's `MovementController` re-paths internally (repair/wait re-path) or is scattered/nudged by another unit
- **THEN** the move target line is not shown or restarted by that re-path

#### Scenario: Line appears when a moving unit is selected
- **WHEN** a unit that is already executing a move order becomes selected
- **THEN** the move target line is shown

#### Scenario: Line follows the unit while visible
- **WHEN** the move target line is visible and the unit is moving
- **THEN** the line is redrawn each frame so its origin tracks the unit's current position

### Requirement: Move target line timing
The move target line SHALL be visible for 1 second, controlled by a one-shot timer, and SHALL hide automatically when the timer elapses.

#### Scenario: Line hides after one second
- **WHEN** the move target line has been visible for 1 second
- **THEN** the line is hidden

#### Scenario: Reselecting a moving unit restarts the timer
- **WHEN** a still-moving unit is deselected and then selected again
- **THEN** the 1-second timer restarts and the line is shown again

#### Scenario: Reselecting an attacking unit shows the line
- **WHEN** a unit with an active attack target is deselected and then selected again, even if it is stationary (already in weapon range)
- **THEN** the move target line is shown pointing at the attack target

### Requirement: Move target line hidden on deselect
When the unit is not selected, the move target line SHALL be hidden immediately and its timer reset.

#### Scenario: Deselect hides the line
- **WHEN** a unit showing its move target line is deselected
- **THEN** the line is hidden immediately and the timer is stopped

#### Scenario: No line without a movement controller
- **WHEN** a selected entity has no `MovementController` (e.g. a structure)
- **THEN** no move target line is created or shown
