## Why

The archived `add-fx-system` MVP ships a muzzle flash and a bullet-hit effect,
but its first in-game run exposed four visual defects:

- **Muzzle at the feet (FLH).** A body-mounted weapon's muzzle resolves to the
  entity origin offset by `WeaponData.fire_offset`, and the Light Infantry's
  minigun leaves that offset at zero. The entity origin is the unit's feet (the
  placeholder mesh is centred at `+half_height`), so the flash and projectile
  spawn at ground level instead of the gun.
- **Impact reads as a point.** The bullet-hit sprite's frames only fill a corner
  of their 16×16 cells (peak 11×12 px), so at `pixel_size = 0.06` the effect is
  0.24–0.66 world units instead of roughly one.
- **Muzzle is enormous.** `FxSystem` assigns a bare `QuadMesh`, whose default
  size is 1×1 metre. In a game where a cell is 2 units and a soldier is ~1 unit
  tall, a `scale_min` of 0.4 makes sparks roughly body-sized.
- **No light.** Effects are purely emissive; the muzzle flash cannot throw the
  point-light flash that sells a shot.

## What Changes

- **Body muzzle FLH**: `CombatComponent` SHALL resolve a body-mounted muzzle as
  the entity transform composed with `WeaponData.fire_offset` (entity-local, so
  the offset rotates with the body), and the Light Infantry minigun SHALL author
  a non-zero offset (height + small forward). The projectile's fallback spawn
  origin SHALL use the same composition.
- **Particle quad size**: `FxData` gains `quad_size` (world units of the particle
  quad, default 0.1); `FxSystem` SHALL size the draw quad from it, so a particle
  effect is authored in world units instead of inheriting a 1 m quad.
- **Effect light**: `FxData` gains `light_energy` (0 = no light), `light_color`,
  and `light_range`; when `light_energy > 0` `FxSystem` SHALL add an
  `OmniLight3D` to the effect node (no shadows). The muzzle flash SHALL carry a
  warm, short-lived point light.
- **Impact size**: the bullet-hit art SHALL be redrawn so the flash grows to
  fill its cell, giving a peak of roughly one world unit.
- **MVP tuning**: the muzzle effect's `quad_size`/light and the bullet-hit
  `pixel_size`/art are retuned; tests and the `fx-system` / `combat-firing`
  specs are updated.

## Capabilities

### Modified Capabilities
- `fx-system`: add the particle `quad_size` field and the optional effect light.
- `combat-firing`: body-mounted muzzle is the entity-*local* `fire_offset`
  composition, shared by the muzzle effect and the projectile spawn origin.

## Impact

- **Modified code**: `scripts/data/FxData.gd` (`quad_size`, light fields),
  `scripts/core/FxSystem.gd` (quad sizing, omni light),
  `scripts/components/CombatComponent.gd` and `ProjectileController.gd` (local
  muzzle composition).
- **Modified content**: `games/ts/weapons/minigun.tres` (`fire_offset`),
  `games/ts/fx/muzzle_flash_small.tres` (`quad_size`, light),
  `games/ts/fx/bullet_hit_small.tres` and `games/ts/assets/fx/bullet_hit.png`.
- **Tests**: `test_fx_system.gd` (quad size, light), `test_fx_content.gd`
  (muzzle scale, impact size, non-zero FLH), `test_fx_triggers.gd` (local
  muzzle).
- **Compatibility**: additive data fields with defaults; a body-mounted muzzle
  at the identity transform is unchanged, so existing placement is preserved.
- Not in scope: per-unit `ArtData.primary_fire_offset` FLH (deferred to #326),
  FX pooling (#456), persistent fire/burning (#457).
