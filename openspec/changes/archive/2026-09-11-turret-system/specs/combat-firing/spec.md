## MODIFIED Requirements

### Requirement: Fire rate cooldown per weapon
CombatComponent SHALL maintain one cooldown timer per weapon mount group (a body-mounted weapon with no mount group is its own group). After a group fires, its timer SHALL be set to `weapon.rate_of_fire / 30.0` seconds, treating `rate_of_fire` as the original Tiberian Sun `ROF=` rearm-delay frames at the engine's 30 fps logic rate. A group SHALL NOT fire while its cooldown timer is positive. Groups evaluate independently, so a unit with several weapons or several turret mounts fires each on its own schedule.

#### Scenario: Fire rate timing
- **WHEN** a group whose weapon has `rate_of_fire = 20` fires
- **THEN** the next shot from that group is delayed by 0.667 seconds (20/30)

#### Scenario: Cooldown ticks down
- **WHEN** `_physics_process(delta)` runs with a positive group cooldown
- **THEN** the cooldown decreases by `delta`

#### Scenario: Independent group schedules
- **WHEN** a unit has two mount groups with different weapons
- **THEN** each group fires on its own cooldown without waiting for the other

### Requirement: Range checking
CombatComponent SHALL check if the target is within firing range before firing. Range SHALL be calculated as `weapon.attack_range * CellUtil.CELL_SIZE` world units, measured on the horizontal (XZ) plane — the Y (altitude) component SHALL be ignored so hovering or elevated attackers are not pushed out of range by vertical separation. For weapons mounted on a `yaw_free` turret socket, being in range additionally requires turret alignment per the `turrets` capability (in-range but turret not aligned holds fire for that tick while the turret slews). For weapons that are body-mounted or mounted on a `yaw_free = false` socket, being in range additionally requires body alignment per the `combat-facing` capability.

#### Scenario: Target in range
- **WHEN** the target's horizontal distance (ignoring Y) is less than or equal to `attack_range * CELL_SIZE`
- **THEN** CombatComponent MAY fire (subject to cooldown and, for the mounting, turret or body alignment)

#### Scenario: Target out of range
- **WHEN** the target's horizontal distance (ignoring Y) exceeds `attack_range * CELL_SIZE`
- **THEN** CombatComponent SHALL issue a move command toward the target position instead of firing

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

### Requirement: Weapon dispatch and damage
When firing, CombatComponent SHALL first resolve `weapon.projectile` through the GlobalRules projectile registry. If the id resolves to a `ProjectileData`, CombatComponent SHALL instantiate `Projectile.tscn`, configure it with the projectile data, weapon, shooter, and target, spawn it at the firing mount's muzzle transform, parent it to the gameplay root, and SHALL NOT apply direct damage. The muzzle transform SHALL be the firing socket's world transform composed with the socket yaw and extended by the socket `barrel_length` for turret-mounted weapons, or the entity transform extended by the weapon barrel length for body-mounted weapons (see the `turrets` capability). If the id is empty or unresolvable, CombatComponent SHALL apply damage directly (legacy hitscan): the weapon's base damage multiplied by the warhead armor multiplier for the target's armor type, clamped to GlobalRules `[min_damage, max_damage]`, then call `target.get_node("HealthComponent").take_damage(final_damage, weapon.warhead)`.

#### Scenario: Resolvable projectile spawns instead of direct damage
- **WHEN** a weapon with `projectile = "Invisible"` fires at an enemy in range
- **THEN** a projectile node is spawned and configured, and the target's HealthComponent is not modified by CombatComponent directly

#### Scenario: Spawn at socket muzzle
- **WHEN** a turret-mounted weapon fires
- **THEN** the projectile's initial position is the firing socket's world transform extended by `barrel_length`, rotated by the current socket yaw

#### Scenario: Spawn at body muzzle
- **WHEN** a body-mounted weapon fires
- **THEN** the projectile's initial position is the entity transform extended by the weapon barrel length

#### Scenario: Unresolvable projectile falls back to hitscan
- **WHEN** a weapon's projectile id does not resolve in the registry (or is empty)
- **THEN** damage is applied directly with the full legacy math

#### Scenario: Fallback damage applied with armor
- **WHEN** a weapon with `damage = 100` and warhead "SA" fires via the fallback at a target with `armor = "heavy"` (SA multiplier 0.25)
- **THEN** the target's HealthComponent receives `take_damage(25, "SA")`

#### Scenario: Armor-piercing vs heavy
- **WHEN** a weapon with `damage = 100` and warhead "AP" fires at a target with `armor = "heavy"` (AP multiplier 1.00)
- **THEN** the target's HealthComponent SHALL receive `take_damage(100, "AP")`

#### Scenario: Fallback minimum damage floor
- **WHEN** the fallback-computed damage would be below `min_damage` (1)
- **THEN** the applied damage is clamped to 1

#### Scenario: Fallback maximum damage cap
- **WHEN** the fallback-computed damage would exceed `max_damage` (1000)
- **THEN** the applied damage is clamped to 1000

#### Scenario: Fallback zero-damage armor pairing
- **WHEN** a warhead's multiplier for the target's armor is 0.0
- **THEN** the target's HealthComponent receives `take_damage(0, warhead)` and takes no damage

#### Scenario: Fallback unknown warhead or armor
- **WHEN** the weapon's warhead id or the target's armor id is not in the GlobalRules registries
- **THEN** fallback damage is applied with full multiplier 1.0

#### Scenario: Fallback target has no HealthComponent
- **WHEN** the target entity has no HealthComponent child
- **THEN** CombatComponent skips the damage call without error
