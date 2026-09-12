## MODIFIED Requirements

### Requirement: Combat engagement gates firing behind facing
Weapons mounted on a `yaw_free` turret socket (per the `turrets` capability) SHALL NOT require the whole body to face the target: CombatComponent SHALL slew the turret toward the target each physics tick and hold fire until the turret is within its angle threshold, and SHALL allow firing while the body is driving a `MOVING` / `ROTATING` leg because movement does not affect turret aim. Weapons that are body-mounted, or mounted on a socket with `yaw_free = false`, SHALL retain the body-facing gate: when the attacker is a mobile entity (has a `MovementController` sibling and no live move leg), CombatComponent SHALL call `face_toward` toward the target position each physics tick before firing — if the call reports not-aligned it SHALL hold fire for that tick (cooldowns keep ticking down); if aligned it SHALL fire subject to cooldown. While the MovementController is driving a `MOVING` / `ROTATING` leg with live waypoints, a body-mounted weapon SHALL hold fire for those ticks and SHALL NOT call `face_toward` into the moving body. While `WAIT`ing, the unit is not driving a leg, so CombatComponent SHALL slew via `face_toward` as if idle. Targets closer than `CellUtil.CELL_SIZE` SHALL fire regardless of body or turret alignment.

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
- **WHEN** the target is within `CellUtil.CELL_SIZE` world units on the XZ plane
- **THEN** CombatComponent fires subject to cooldown without requiring body or turret alignment

#### Scenario: Vertical separation ignored for yaw
- **WHEN** the target is at a different altitude but within horizontal range
- **THEN** body and turret yaw are computed from the XZ direction only
