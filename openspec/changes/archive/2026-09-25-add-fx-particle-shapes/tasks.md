## 1. Triangle particle primitive

- [x] 1.1 Add `enum ParticleShape { QUAD, TRIANGLE }` and `particle_shape: ParticleShape = QUAD` to `scripts/data/FxData.gd`
- [x] 1.2 Add `FxSystem._build_particle_mesh`: `QuadMesh` for `QUAD`, one-triangle `ArrayMesh` for `TRIANGLE`, sized by `quad_size`, with the draw material attached per mesh type
- [x] 1.3 `test_fx_system.gd`: a `TRIANGLE` effect builds a one-surface `ArrayMesh` with the draw material; `QUAD` still builds a `QuadMesh`

## 2. SA impact rework

- [x] 2.1 Rewrite `games/ts/fx/bullet_hit_small.tres` as a PARTICLES effect: flat box spawner (`emission_box_extents.y = 0`), small triangle shards, gravity + tumble, `color_initial_ramp` of yellow/gray/brown, no light
- [x] 2.2 Delete `games/ts/assets/fx/bullet_hit.png` and its `.import`
- [x] 2.3 `test_fx_content.gd`: assert the impact is a flat triangle-particle spray (kind, shape, flat box, colour ramp, no light)
- [x] 2.4 Fix the `test_asset_browser_data.gd` message that called `BulletHitSmall` a sprite effect

## 3. Muzzle light/offset follow-up

- [x] 3.1 Push the Light Infantry `fire_offset` slightly further forward in XZ (`Vector3(0, 0.5, -0.35)`)
- [x] 3.2 `test_fx_system.gd`: assert the effect light sits on the effect (muzzle) transform, not the entity origin

## 4. Specs and verification

- [x] 4.1 Add the `fx-system` deltas (particle draw shape; corrected sprite example id)
- [x] 4.2 Run `redot --headless -s test/run_tests.gd`; run `gdlint` and `gdformat --check`
- [x] 4.3 `openspec validate add-fx-particle-shapes --strict`, then archive the change
