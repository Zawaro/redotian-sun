## ADDED Requirements

### Requirement: Continuous turret aim
A `yaw_free` socket SHALL continuously face the entity's current order target. While the entity has a live combat target, the socket SHALL slew toward that target every physics tick regardless of whether the target is inside weapon range (so a turret tracks during the chase). While the entity has no combat target and its `MovementController` sibling `is_moving()`, the socket SHALL slew toward `MovementController.get_target_position()`. When the entity has no combat target and is not moving, the socket SHALL realign to its rest orientation (`yaw` toward `0.0`, the chassis forward). Fixed sockets (`yaw_free = false`) and entities without a `MovementController` SHALL be unaffected. Combat aim SHALL take precedence over movement/idle aim within a tick, and no socket SHALL advance its yaw more than once per tick.

#### Scenario: Target tracked during the chase
- **WHEN** a `yaw_free` mount has a live target outside weapon range and the body is driving toward it
- **THEN** the turret yaws toward the target that tick (it does not stay frozen until the target is in range)

#### Scenario: Movement destination tracked
- **WHEN** a `yaw_free` mount has no combat target and the entity is moving
- **THEN** the turret yaws toward the movement destination

#### Scenario: Attack target wins over movement
- **WHEN** an entity with a `yaw_free` mount is moving and also has a live combat target in a different direction
- **THEN** the turret faces the combat target, not the movement destination

#### Scenario: Idle realigns to chassis forward
- **WHEN** a `yaw_free` mount has no combat target and the entity is not moving
- **THEN** the turret yaws back toward its rest orientation

#### Scenario: Fixed socket does not move
- **WHEN** the entity moves or has a target and its socket has `yaw_free = false`
- **THEN** the socket yaw stays at its rest orientation
