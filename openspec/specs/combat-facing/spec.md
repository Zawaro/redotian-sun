## Purpose

Combat engagement aligns the attacker to its target before firing: mobile turretless units slew the whole body via `face_toward`, buildings and immobile entities are exempt, and rotatable turret mounts (see the `turrets` capability) aim independently while the body holds course.
## Requirements
### Requirement: MovementController exposes body-facing API
MovementController SHALL expose `face_toward(target_pos: Vector3, delta: float) -> bool`, which slews the entity body toward a world position and reports alignment. Desired yaw SHALL be computed from the XZ direction to `target_pos` (Y ignored). For `instant_turn` locomotors the body SHALL snap via `_apply_facing` and return aligned immediately. Otherwise the yaw SHALL advance toward the desired yaw by at most `deg_to_rad(rotation_speed) * delta` using the `angle_difference` step idiom, applied through `_apply_facing`, and return true only when `abs(angle_difference(current_yaw, desired_yaw)) <= rotation_angle_threshold`. The method SHALL NOT touch `_waypoints`, issue moves, or emit `movement_started` / `arrived` / `pathfinding_failed`.

#### Scenario: Instant-turn unit snaps
- **WHEN** `face_toward` is called on a Foot-locomotor unit facing away from the target position
- **THEN** the body yaw points at the target position and the method returns true in the same call

#### Scenario: Vehicle slews at rotation speed
- **WHEN** `face_toward` is called on a Track-locomotor unit 90 degrees off target with `rotation_speed = 180.0`
- **THEN** one call with `delta = 0.25` advances yaw by 45 degrees and returns false, and repeated calls converge to aligned within `rotation_angle_threshold`

#### Scenario: No signals or waypoints touched
- **WHEN** `face_toward` runs on an idle unit
- **THEN** no `movement_started` signal is emitted and the unit's waypoint state is unchanged

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

### Requirement: rotation_speed wired from entity data
`MovementController.configure(data)` SHALL adopt `data.rotation_speed` (the `rules.ini` `ROT=` value, degrees per second) as the controller's turn rate. The scene-export default remains only as a fallback when no data is configured.

#### Scenario: Per-unit turn rates diverge
- **WHEN** a unit configured from entity data with `rotation_speed = 90.0` and another with `rotation_speed = 180.0` each slew 90 degrees
- **THEN** the first takes twice as long as the second

### Requirement: Buildings and immobile entities exempt
Entities without a `MovementController` sibling (buildings, `speed = 0`) SHALL fire exactly as before with no facing precondition.

#### Scenario: Building fires out-of-arc
- **WHEN** a defensive structure engages an in-range target at any bearing
- **THEN** it fires subject to cooldown with no rotation

### Requirement: Turret mounts track the target while closing
Weapons mounted on a `yaw_free` turret socket SHALL slew toward the target every physics tick a target exists, including while the target is out of weapon range and the body is chasing it. This tracking SHALL NOT require the body to face the target and SHALL NOT itself fire the weapon; firing remains gated by range, cooldown, and turret alignment.

#### Scenario: Chase tracking
- **WHEN** a turreted unit is ordered to attack an enemy beyond weapon range and drives toward it
- **THEN** the turret continues to yaw toward the enemy during the approach, and the weapon does not fire until the enemy is in range and the turret is aligned

