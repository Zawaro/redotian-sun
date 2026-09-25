## Why

The MVP gave the small-arms warhead a `BulletHitSmall` SPRITE effect: an
animated billboard drawn as a growing warm flash. In game it reads as a fire or
explosion, which is wrong for a rifle round. Tiberian Sun-style bullet impacts
are small, short-lived debris shards — a flat spray of yellow/gray/brown
triangle particles — with no glow or flash.

`FxData` only draws particles as a camera-facing quad, so there is no way to
author triangle shards. This change adds a triangle draw primitive and reworks
the SA impact into a flat triangle-particle spray.

## What Changes

- `FxData` gains `particle_shape: ParticleShape` (`QUAD` default, or
  `TRIANGLE`) selecting the `GPUParticles3D` draw primitive.
- `FxSystem` builds a triangle `ArrayMesh` for `TRIANGLE` and a `QuadMesh`
  otherwise, both sized by `quad_size`, with the effect's draw material.
- The SA warhead's `BulletHitSmall` becomes a PARTICLES effect: a flat
  (zero-height box) spawner of small triangle shards coloured from a
  yellow/gray/brown `color_initial_ramp`, with gravity and tumble, no light.
  Its sprite art is removed.
- Tests cover the triangle primitive, the light sitting on the effect/muzzle
  transform, and the reworked impact content; the `fx-system` spec gains the
  draw-shape requirement.

## Capabilities

### Modified Capabilities
- `fx-system`: particle effects can be drawn as a quad or a flat triangle.

## Impact

- **Modified code**: `scripts/data/FxData.gd` (`ParticleShape`, `particle_shape`),
  `scripts/core/FxSystem.gd` (`_build_particle_mesh`).
- **Modified content**: `games/ts/fx/bullet_hit_small.tres` (rewritten as
  particles); `games/ts/assets/fx/bullet_hit.png` removed.
- **Tests**: `test/unit/test_fx_system.gd` (triangle primitive, light position),
  `test/unit/test_fx_content.gd` (impact debris), `test_asset_browser_data.gd`
  message fix.
- **Compatibility**: additive with a `QUAD` default, so existing particle
  effects are unchanged.
