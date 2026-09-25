## Context

This change polishes the archived `add-fx-system` MVP after its first in-game
run. It touches three seams: how a body-mounted muzzle position is computed,
how particles are sized, and whether an effect can carry light. The particle and
light changes extend `FxData`/`FxSystem`; the muzzle change is a one-line fix in
combat plus authored data.

## Goals / Non-Goals

- **Goals:** muzzle at gun height, a roughly one-unit impact, sparks sized in
  world units, and a transient point light on the muzzle flash.
- **Non-Goals:** per-unit `ArtData.primary_fire_offset` FLH (owned by #326),
  FX pooling (#456), persistent fire/burning (#457).

## Decisions

### Body muzzle offset is entity-local

`_body_muzzle_origin` becomes `shooter.global_transform * weapon.fire_offset`
instead of `shooter.global_position + weapon.fire_offset`. The archived
`combat-firing` spec already describes the body muzzle as "the entity transform
offset by `WeaponData.fire_offset`", and `face_toward` makes the body face the
target, so a local offset keeps the flash in front of the gun as the unit turns.
An identity-transform shooter (the existing tests) computes the same point, so
placement is preserved. `ProjectileController`'s no-spawn-origin fallback uses
the same composition so the visual and the projectile agree.

The Light Infantry minigun authors `fire_offset = Vector3(0, 0.5, -0.15)`:
0.5 up (the ~1 unit placeholder's gun height) and 0.15 forward (−Z is forward).

### Particle size is authored, not implicit

`QuadMesh` defaults to 1×1 world units; the MVP relied on `scale_min` alone and
so produced near-body-sized sparks. `FxData.quad_size` (default 0.1) sizes the
draw quad directly, so a particle effect is authored in world units and every
future effect inherits a sane default instead of a metre-wide quad. Process
`scale_min`/`scale_max` then remain a per-particle variation knob.

### Effect light is optional and data-driven

`FxData.light_energy` (0 = no light), `light_color`, and `light_range` let an
effect opt into an `OmniLight3D` child. `FxSystem` adds the light to the effect
node after build, so it is freed with the effect and is killed by the fog-freeze
`visible = false` (a Light3D's `visible_in_tree` gates its contribution).
Shadows are off — a one-shot flash does not need shadow maps, and the low-res
Forward+ viewport should not pay for them. The light lives on layer 1 so the
pixel-art camera (`cull_mask = 0b01`) sees it.

Tuning is a calibration knob: `light_energy`/`light_range` on the muzzle `.tres`
are guessed (3.0 / 2.0) and are expected to be adjusted while looking at the
game, which headless tests cannot validate.

### Impact art fills its cell

`pixel_size` stays 0.06 (16 px → 0.96 units). The PNG is redrawn so the flash
grows from a small core to fill the 16×16 cell, putting the peak at roughly one
unit as intended. Redrawing shared art requires a re-import
(`redot --headless --import`) before the imported texture reflects the change.

## Risks / Trade-offs

- **Transient lights multiply.** Each shot adds an `OmniLight3D` for its short
  lifetime; many simultaneous shooters add many lights. This is bounded by the
  shot count and effect lifetime, and pooling (#456) is the scale-out path.
  `# ponytail: one transient point light per shot`.
- **Redrawn art changes all small-arms hits.** `bullet_hit_small` is shared by
  the SA warhead, so the larger impact applies wherever SA is used; that is the
  intent of the fix.

## Migration Plan

Additive fields default to the old behaviour (`quad_size` 0.1 is the only
size change and is the fix; `light_energy` defaults to 0 = no light), so no data
migration is required.

## Open Questions

- Final muzzle light energy/range are placeholders until checked in the editor.
