## ADDED Requirements

### Requirement: Weapon muzzle FX
On each successful weapon dispatch, `CombatComponent` SHALL play `WeaponData.muzzle_fx` through `FxSystem.play` at the weapon's world muzzle transform. The muzzle transform SHALL be the same one used for projectile spawn: the firing socket's world transform composed with socket yaw and extended by `barrel_length` for turret-mounted weapons, or the entity transform offset by `WeaponData.fire_offset` for body-mounted weapons. A `null` `muzzle_fx` SHALL play nothing. The effect SHALL play exactly once per shot, whether the weapon spawned a projectile or applied fallback hitscan damage. Fog gating is delegated to `FxSystem` (see the `fx-system` capability).

#### Scenario: Turret-mounted muzzle FX at the socket
- **WHEN** a turret-mounted weapon with a non-null `muzzle_fx` fires
- **THEN** the effect is played at the firing socket's muzzle world transform

#### Scenario: Body-mounted muzzle FX at the body muzzle
- **WHEN** a body-mounted weapon with a non-null `muzzle_fx` fires
- **THEN** the effect is played at the entity transform offset by `WeaponData.fire_offset`

#### Scenario: No muzzle FX is silent
- **WHEN** a weapon whose `muzzle_fx` is `null` fires
- **THEN** no effect node is spawned

#### Scenario: Muzzle FX plays once per shot
- **WHEN** a weapon with a non-null `muzzle_fx` fires
- **THEN** exactly one effect is played for that shot

#### Scenario: Muzzle FX on both dispatch paths
- **WHEN** a weapon with a non-null `muzzle_fx` fires via projectile spawn, and another fires via fallback hitscan damage
- **THEN** both shots play the muzzle effect exactly once
