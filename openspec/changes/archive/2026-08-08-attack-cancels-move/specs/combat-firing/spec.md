## MODIFIED Requirements

### Requirement: Movement integration
CombatComponent SHALL connect to `MovementController.arrived` signal on first attack engagement. When `arrived` fires, the next `_physics_process` tick SHALL re-evaluate range and fire if in range.

#### Scenario: Unit moves toward target
- **WHEN** target is out of range and MC is idle, or the current move was just superseded by a fresh attack order
- **THEN** CombatComponent SHALL compute a stop position at `weapon.attack_range * CELL_SIZE` distance from the target, at the angle from the target to the unit (atan2), and call `mc.set_target_position(stop_pos)`

#### Scenario: Multiple units spread around target
- **WHEN** 3 units attack the same target from different angles
- **THEN** each unit SHALL compute a unique stop position at its own angle from the target, spreading naturally around the target perimeter

#### Scenario: Unit already moving on an approach
- **WHEN** MC is already moving (`is_moving() == true`) on a previously issued combat approach
- **THEN** the per-frame `_physics_process` re-check SHALL NOT issue another move command

#### Scenario: Arrival triggers re-check
- **WHEN** MovementController emits `arrived` signal
- **THEN** CombatComponent SHALL re-check range on next `_physics_process` tick

## ADDED Requirements

### Requirement: Attack cancels player move
Issuing an attack order SHALL cancel a ground unit's in-progress player move and engage the target. A ground unit SHALL halt via `MovementController.stop()` (a no-op when already idle); an airborne jumpjet SHALL keep its air zone via `cancel_move_retain_vertical()`. When the target is out of range, the old move destination SHALL be dropped immediately and a new approach path issued in the same frame, so the unit starts moving toward the target without finishing the old move.

#### Scenario: Moving ground unit attacks in-range target
- **WHEN** a ground unit is moving on a player move order and receives an attack order on a target already within weapon range
- **THEN** the unit SHALL stop (settle to its sub-slot) and fire from its current position instead of continuing along the old move path

#### Scenario: Moving ground unit attacks out-of-range target
- **WHEN** a ground unit is moving on a player move order and receives an attack order on a target outside weapon range
- **THEN** the old move destination SHALL be abandoned and the unit SHALL move along a fresh approach path to within weapon range of the target, starting in the same frame as the attack order

#### Scenario: Idle unit receives attack order
- **WHEN** an idle unit receives an attack order
- **THEN** `MovementController.stop()` is a no-op and behavior SHALL be unchanged (fire if in range, approach otherwise)

#### Scenario: Airborne jumpjet attack interrupts move
- **WHEN** an airborne jumpjet moving on a player move order receives an attack order
- **THEN** the in-flight move SHALL be cancelled via `cancel_move_retain_vertical()` and the jumpjet SHALL attack from its air zone (no change to existing airborne behavior)
