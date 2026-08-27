## RENAMED Requirements

- FROM: `### Requirement: Hitscan damage application`
- TO: `### Requirement: Weapon dispatch and damage`

## MODIFIED Requirements

### Requirement: Weapon dispatch and damage
When firing, CombatComponent SHALL first resolve `weapon.projectile` through the GlobalRules projectile registry. If the id resolves to a `ProjectileData`, CombatComponent SHALL instantiate `Projectile.tscn`, configure it with the projectile data, weapon, shooter, and target, spawn it at the shooter's position offset by `WeaponData.fire_offset`, parent it to the gameplay root, and SHALL NOT apply direct damage. If the id is empty or unresolvable, CombatComponent SHALL apply damage directly (legacy hitscan): the weapon's base damage multiplied by the warhead armor multiplier for the target's armor type, clamped to GlobalRules `[min_damage, max_damage]`, then call `target.get_node("HealthComponent").take_damage(final_damage, weapon.warhead)`.

#### Scenario: Resolvable projectile spawns instead of direct damage
- **WHEN** a weapon with `projectile = "Invisible"` fires at an enemy in range
- **THEN** a projectile node is spawned and configured, and the target's HealthComponent is not modified by CombatComponent directly

#### Scenario: Spawn at muzzle offset
- **WHEN** a projectile is spawned
- **THEN** its initial position is the shooter's position plus `WeaponData.fire_offset`

#### Scenario: Unresolvable projectile falls back to hitscan
- **WHEN** a weapon's projectile id does not resolve in the registry (or is empty)
- **THEN** damage is applied directly with the full legacy math

#### Scenario: Fallback damage applied with armor
- **WHEN** a weapon with `damage = 100` and warhead "SA" fires via the fallback at a target with `armor = "heavy"` (SA multiplier 0.25)
- **THEN** the target's HealthComponent receives `take_damage(25, "SA")`

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

### Requirement: weapon_fired signal
CombatComponent SHALL emit `weapon_fired(weapon: WeaponData, target: Node3D)` after each successful weapon dispatch, whether the weapon spawned a projectile or applied fallback hitscan damage.

#### Scenario: Signal emitted on fire
- **WHEN** CombatComponent fires a weapon
- **THEN** `weapon_fired` is emitted with the weapon data and target reference

#### Scenario: Signal emitted on projectile dispatch
- **WHEN** a weapon dispatches a projectile instead of applying fallback damage
- **THEN** `weapon_fired` is still emitted exactly once
