## MODIFIED Requirements

### Requirement: Combat engagement gates firing behind facing
Weapons mounted on a `yaw_free` turret socket (per the `turrets` capability) SHALL NOT require the whole body to face the target: CombatComponent SHALL slew the turret toward the target each physics tick and hold fire until the turret is within its angle threshold, and SHALL allow firing while the body is driving a `MOVING` / `ROTATING` leg because movement does not affect turret aim. Weapons that are body-mounted, or mounted on a socket with `yaw_free = false`, SHALL retain the body-facing gate: when the attacker is a mobile entity (has a `MovementController` sibling and no live move leg), CombatComponent SHALL call `face_toward` toward the target position each physics tick before firing — if the call reports not-aligned it SHALL hold fire for that tick (cooldowns keep ticking down); if aligned it SHALL fire subject to cooldown. The facing position SHALL be the target's effective target point: the nearest point on the foundation footprint for a target that has a `FoundationComponent`, otherwise the target's `global_position`. While the MovementController is driving a `MOVING` / `ROTATING` leg with live waypoints, a body-mounted weapon SHALL hold fire for those ticks and SHALL NOT call `face_toward` into the moving body. While `WAIT`ing, the unit is not driving a leg, so CombatComponent SHALL slew via `face_toward` as if idle. Targets closer than `CellUtil.CELL_SIZE` (measured to the effective target point) SHALL fire regardless of body or turret alignment.

#### Scenario: Turreted unit fires while moving
- **WHEN** a Track unit with a `yaw_free` turret mount is driving a live move leg with an in-range target off the body heading
- **THEN** the turret yaws toward the target and the weapon fires once the turret is aligned, without stopping the body

#### Scenario: Body-mounted unit holds fire then fires
- **WHEN** a stationary Track unit with a body-mounted weapon has an out-of-arc target in range and off cooldown
- **THEN** it does not fire on the first tick, its body yaw advances toward the target, and it fires once aligned

#### Scenario: Moving body-mounted attacker holds fire until stopped and aligned
- **WHEN** an in-range attack order arrives for a body-mounted weapon while the attacker is mid-move, and the body does not point at the target
- **THEN** no shot fires while the leg is live; after the leg ends the body slews to the target and the first shot fires only once aligned

#### Scenario: Fixed socket forces body facing
- **WHEN** a weapon on a `yaw_free = false` socket has an in-range target off the body heading
- **THEN** the weapon holds fire while the body slews onto the target, exactly like a body-mounted weapon

#### Scenario: Infantry fires immediately
- **WHEN** a stationary Foot unit with a body-mounted weapon engages an out-of-arc target in range
- **THEN** it snaps to face the target and fires in the same tick

#### Scenario: Close target fires without turning
- **WHEN** the target is within `CellUtil.CELL_SIZE` world units on the XZ plane of the effective target point
- **THEN** CombatComponent fires subject to cooldown without requiring body or turret alignment

#### Scenario: Building target faces the nearest wall
- **WHEN** a body-mounted attacker engages a building and the foundation-footprint center is off the body heading
- **THEN** CombatComponent SHALL slew the body (and any `yaw_free` turrets) toward the nearest point on the foundation footprint, not the footprint center

#### Scenario: Vertical separation ignored for yaw
- **WHEN** the target is at a different altitude but within horizontal range
- **THEN** body and turret yaw are computed from the XZ direction only

### Requirement: Turret mounts track the target while closing
Weapons mounted on a `yaw_free` turret socket SHALL slew toward the target every physics tick a target exists, including while the target is out of weapon range and the body is chasing it. The slew position SHALL be the target's effective target point (nearest foundation-footprint point for a building, `global_position` otherwise). This tracking SHALL NOT require the body to face the target and SHALL NOT itself fire the weapon; firing remains gated by range, cooldown, and turret alignment.

#### Scenario: Chase tracking
- **WHEN** a turreted unit is ordered to attack an enemy beyond weapon range and drives toward it
- **THEN** the turret continues to yaw toward the enemy during the approach, and the weapon does not fire until the enemy is in range and the turret is aligned

#### Scenario: Chase tracking a building
- **WHEN** a turreted unit chases an out-of-range building
- **THEN** the turret SHALL track the nearest point on the building's foundation footprint, not the footprint center
