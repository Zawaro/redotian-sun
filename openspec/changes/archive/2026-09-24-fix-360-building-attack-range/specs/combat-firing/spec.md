## MODIFIED Requirements

### Requirement: Range checking
CombatComponent SHALL check if the target is within firing range before firing. Range SHALL be calculated as `weapon.attack_range * CellUtil.CELL_SIZE` world units, measured on the horizontal (XZ) plane — the Y (altitude) component SHALL be ignored so hovering or elevated attackers are not pushed out of range by vertical separation. The measured distance SHALL be from the attacker to the target's **effective target point**: when the target is a structure (`StatsComponent.is_structure()` is true) and has a `FoundationComponent`, the effective target point SHALL be the nearest point on the target's foundation footprint to the attacker (the clamped projection of the attacker's position onto the footprint rectangle); otherwise it SHALL be the target's `global_position`. For weapons mounted on a `yaw_free` turret socket, being in range additionally requires turret alignment per the `turrets` capability (in-range but turret not aligned holds fire for that tick while the turret slews). For weapons that are body-mounted or mounted on a `yaw_free = false` socket, being in range additionally requires body alignment per the `combat-facing` capability.

#### Scenario: Target in range
- **WHEN** the target's horizontal distance (ignoring Y) is less than or equal to `attack_range * CELL_SIZE`
- **THEN** CombatComponent MAY fire (subject to cooldown and, for the mounting, turret or body alignment)

#### Scenario: Target out of range
- **WHEN** the target's horizontal distance (ignoring Y) exceeds `attack_range * CELL_SIZE`
- **THEN** CombatComponent SHALL issue a move command toward the target position instead of firing

#### Scenario: Building edge in range fires while center is out of range
- **WHEN** the target is a building whose foundation-footprint center is beyond `attack_range * CELL_SIZE` but whose nearest footprint edge is within it
- **THEN** CombatComponent SHALL treat the building as in range and MAY fire (subject to cooldown and alignment), matching Tiberian Sun's rule that a building is engaged while any foundation cell is in range

#### Scenario: Building center in range still fires
- **WHEN** the target is a building whose foundation-footprint center is within `attack_range * CELL_SIZE`
- **THEN** CombatComponent SHALL treat the building as in range (its nearest footprint point is at least as close as the center)

#### Scenario: Single-cell building measured as a point
- **WHEN** the target is a 1x1 building (no `FoundationComponent`; footprint center equals the cell center)
- **THEN** CombatComponent SHALL measure to the target's `global_position`, unchanged from before this change

#### Scenario: Non-building target unchanged
- **WHEN** the target is a unit without a `FoundationComponent`
- **THEN** CombatComponent SHALL measure to the target's `global_position` exactly as before this change

#### Scenario: Multi-cell non-structure measured as a point
- **WHEN** the target is not a structure but carries a `FoundationComponent` (possible because `EntityFactory` attaches one for any `foundation != 1x1`)
- **THEN** CombatComponent SHALL measure to the target's `global_position`, matching `GuardComponent`'s classifier

#### Scenario: Vertical separation ignored
- **WHEN** a unit hovers or flies at `4.08` world units above a target that is within `attack_range * CELL_SIZE` horizontally
- **THEN** CombatComponent SHALL treat the target as in range and fire

#### Scenario: Airborne attacker engages ground target
- **WHEN** a jumpjet hovering at its flight altitude attacks a ground target within horizontal range
- **THEN** the target is in range regardless of the altitude difference

#### Scenario: In range but turret not aligned holds fire
- **WHEN** a `yaw_free` mount has an in-range target outside its turret angle tolerance
- **THEN** CombatComponent SHALL NOT fire that tick and the turret yaws toward the target instead

#### Scenario: In range but body not facing holds fire
- **WHEN** a body-mounted or fixed-socket weapon has an in-range target outside the body facing tolerance with no live move leg
- **THEN** CombatComponent SHALL NOT fire that tick and the body yaws toward the target instead

### Requirement: Movement integration
CombatComponent SHALL connect to `MovementController.arrived` signal on first attack engagement. When `arrived` fires, the next `_physics_process` tick SHALL re-evaluate range and fire if in range. The approach destination SHALL be computed from the target's effective target point (nearest foundation-footprint point for a building, `global_position` otherwise), and the post-relocation in-range re-check SHALL measure to that same point.

#### Scenario: Unit moves toward target
- **WHEN** target is out of range and MC is idle, or the current move was just superseded by a fresh attack order
- **THEN** CombatComponent SHALL compute a stop position at `weapon.attack_range * CELL_SIZE` distance from the target's effective target point, on the attacker's side of that point, and call `mc.set_target_position(stop_pos)`

#### Scenario: Attacker stops at range from the nearest wall, not the center
- **WHEN** the target is a large building and the attacker approaches from outside its footprint
- **THEN** CombatComponent SHALL issue a stop position `attack_range * CELL_SIZE` from the nearest footprint point, not from the footprint center, so the attacker does not close into the footprint center

#### Scenario: Multiple units spread around target
- **WHEN** 3 units attack the same target from different angles
- **THEN** each unit SHALL compute a unique stop position at its own angle around the target's effective target point, spreading naturally around the target perimeter

#### Scenario: Unit already moving on an approach
- **WHEN** MC is already moving (`is_moving() == true`) on a previously issued combat approach
- **THEN** the per-frame `_physics_process` re-check SHALL NOT issue another move command

#### Scenario: Arrival triggers re-check
- **WHEN** MovementController emits `arrived` signal
- **THEN** CombatComponent SHALL re-check range on next `_physics_process` tick

#### Scenario: Stop relocation keeps the target in range
- **WHEN** the computed stop position is relocated to the nearest passable cell and that relocation pushes it outside `attack_range * CELL_SIZE` of the effective target point
- **THEN** CombatComponent SHALL pull the stop position back inside the range circle around the effective target point, or back off as a failed path if that is impossible
