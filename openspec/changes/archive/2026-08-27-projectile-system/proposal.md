# Projectile System

## Why

The damage pipeline dead-ends at the receiver. #29 built `HitboxComponent` to forward damage from anything implementing `get_damage_info()` to `HealthComponent`, but nothing in the game implements that contract: no projectile node exists at runtime. `CombatComponent._fire_weapon` applies damage instantly, bypassing hitboxes entirely. The data layer is already fully populated (all 44 weapon `.tres` files reference projectile ids, and `resources/projectiles/` holds matching `ProjectileData` definitions), so the runtime node is the last missing piece of the combat loop.

## What Changes

- New `Projectile.tscn` with a single `ProjectileController` script: flight, detection, arming, detonation, and damage payload resolved from `ProjectileData` flags (same data-flag branch pattern `MovementController` uses for locomotors). No component-per-behavior decomposition; no new autoload.
- Damage contract extension: `get_damage_info()` now returns `{amount, type, source, position}`. The position is the detonation point (for FX and, later, splash); source is the shooter for kill credit.
- Two flight behaviors, picked per projectile data:
  - Invisible family (26 current weapons): teleport-detonate. Spawn at the muzzle, detonate at the target coordinate at dispatch (same tick as legacy hitscan) through the full damage pipeline. Behavior-preserving for the existing hitscan balance.
  - Visible guided projectiles: real flight. Straight-line travel with optional homing (`is_guided`, `homing_turn_rate`), `arm_delay` before any detonation, and four detonation triggers (contact, close proximity while armed, overshoot, max range). Close-proximity detonations snap onto the victim.
- Detection polls a shape cast along each physics frame's motion instead of relying on `area_entered` overlap events, so fast projectiles cannot tunnel through thin hitboxes.
- Friendly fire guard: a projectile never triggers on or damages its shooter, and never triggers on the shooter's allies.
- Speed resolution precedence: `ProjectileData.speed_override` (when nonzero) > `WeaponData.speed` (new field) > `GlobalRules.default_projectile_speed` (new field). No existing `.tres` needs editing; both new fields default to no-op values.
- `CombatComponent._fire_weapon` branches: resolvable projectile id spawns a projectile; anything else (broken reference, no projectile set) keeps the legacy hitscan path as a fallback. No weapon data changes required for the migration.
- Projectiles emit an `impacted(position)` signal for a future world-space FX spawner (#321). No FX hookup in this change.

Out of scope: arcing trajectories, bouncy projectiles, cluster/sub-projectiles, proximity fuses, trailer effects, dedicated LOS raycasts, terrain collision for projectiles, splash damage and distance falloff (tracked separately, lands on the shared damage helper in #323).

## Capabilities

### New Capabilities
- `projectile-runtime`: The runtime projectile node: spawn, flight model, target tracking, arming, detonation triggers, snap-to-victim, friendly-fire exclusion, tunneling-immune detection, damage payload, and self-freeing lifecycle.

### Modified Capabilities
- `combat-firing`: The "Hitscan damage application" requirement becomes conditional branching. Firing resolves `weapon.projectile`; on success it spawns a projectile and applies no direct damage. The direct-damage path survives as the fallback for unresolvable projectile ids. `get_damage_info` contract grows `source` and `position` fields.

## Impact

- Modified: `scripts/components/CombatComponent.gd` (`_fire_weapon` branch), `scripts/data/WeaponData.gd` (new `speed` export), `scripts/data/GlobalRules.gd` (new `default_projectile_speed` export).
- New: `scenes/components/Projectile.tscn`, `scripts/components/ProjectileController.gd` (+ `.uid` files, committed together).
- Untouched: all entity `.tscn` files, `EntityFactory`, `HitboxComponent` (already implements the receiver side), `ProjectileData.gd`, existing weapon and projectile `.tres` files.
- Tests: new unit tests in `test/unit/` for the contract, exclusion, arming, detonation triggers, snap, and speed precedence; existing combat tests must pass unchanged (hitscan regression via unresolvable-id fallback).
- No autoload registration. Projectiles parent to the gameplay root and self-free; a map reload frees them with the scene.
