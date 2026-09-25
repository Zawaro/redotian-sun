## 1. FxData resource

- [x] 1.1 Create `scripts/data/FxData.gd` (`class_name FxData extends Resource`) with `enum Kind { SPRITE, PARTICLES }`, `id`, `kind`, `duration`, sprite fields (`sprite_frames`, `animation`, `pixel_size`, `modulate`), particle fields (`process_material`, `draw_material`, `amount`, `lifetime`, `explosiveness`, `local_coords`), and `validate() -> PackedStringArray`
- [x] 1.2 Add `test/unit/test_fx_data.gd`: defaults, empty-id error, sprite-without-frames error, particles-without-process-material error, valid effect passes
- [x] 1.3 Run `redot --headless -s test/run_tests.gd` and confirm the new unit tests pass

## 2. FxSystem autoload

- [x] 2.1 Create `scripts/core/FxSystem.gd`: `play(fx: FxData, global_transform: Transform3D) -> Node3D`; parent to `get_tree().current_scene` (fallback: caller root); null/invalid `fx` warns and returns `null`
- [x] 2.2 Build per kind: SPRITE → `AnimatedSprite3D` with frames/animation/pixel_size/modulate, billboard on, nearest filter, layer 1; PARTICLES → `GPUParticles3D` with process/draw materials, amount, lifetime, explosiveness, local_coords, emitting on, layer 1
- [x] 2.3 Deterministic cleanup: free after `duration` when > 0, else derive (sprite frame time / particle `lifetime`) via FxSystem's per-frame lifetime accumulator; never rely solely on GPU `finished`
- [x] 2.4 Fog gating: skip spawn when `ShroudSystem.is_cell_visible_to_local(cell)` is false; subscribe live effects to `ShroudSystem.state_changed`, freeze while not visible, resume when visible; no gating when fog is disabled
- [x] 2.5 Register `FxSystem` as an autoload in `project.godot` after the existing entries (keep `GameContext` first); commit `scripts/core/FxSystem.gd.uid`
- [x] 2.6 Add `test/unit/test_fx_system.gd`: sprite build, particle build, auto-free on duration, invalid no-op, skipped spawn under shroud, freeze/resume on state change

## 3. Data fields

- [x] 3.1 Add `muzzle_fx: FxData` to `scripts/data/WeaponData.gd` (default `null`)
- [x] 3.2 Add `impact_fx: FxData` to `scripts/data/WarheadData.gd` (default `null`)
- [x] 3.3 Extend the existing data unit tests (or add small ones) to assert both default to `null` and accept an assigned `FxData`

## 4. Triggers

- [x] 4.1 In `CombatComponent._fire_weapon`, play `weapon.muzzle_fx` via `FxSystem.play` at the world muzzle transform (socket muzzle for turret-mounted, entity + `fire_offset` for body-mounted); no-op when null
- [x] 4.2 In `EntityFactory._on_entity_damaged`, resolve the warhead and play `warhead.impact_fx` at the victim's `global_position`; no-op on empty `damage_type`, unknown warhead, or null effect
- [x] 4.3 Add integration tests: muzzle effect spawns at the muzzle on fire (turret and body paths); warhead impact effect spawns on a damaging hit through both projectile and hitscan paths

## 5. MVP content

- [x] 5.1 Add muzzle-flash and bullet-hit textures under `games/ts/assets/fx/` and author `games/ts/fx/*.tres` (`FxData`), keeping the bullet hit flat, ~1 cell, and very short (~0.15–0.3 s)
- [x] 5.2 Assign `muzzle_fx` on the Light Infantry weapon (`minigun.tres`) and `impact_fx` on the small-arms warhead (`sa.tres`)
- [x] 5.3 Verify the effects load, validate, and are wired (automated content test); the on-screen look is confirmed manually in the editor (headless runner cannot render)

## 6. AssetBrowser preview

- [x] 6.1 Add an `FxData` category and effect preview mode to the asset browser (play once on the preview stage; replay action)
- [x] 6.2 Add an asset-browser test: the category lists an `FxData`, selection plays it, replay plays again, invalid effect shows the empty state

## 7. Validation and docs

- [x] 7.1 Run `gdlint` and `gdformat --check` on changed scripts; run the tab check after formatting
- [x] 7.2 Run the full `redot --headless -s test/run_tests.gd` suite green
- [x] 7.3 Add `FxData` / `FxSystem` (and the effect/FX term) to `GLOSSARY.md`, or note in the Undecided section if names are not yet settled

## 8. Review fixes

- [x] 8.1 Thread the muzzle socket basis into `FxSystem.play` so directional particle FX aim along the barrel
- [x] 8.2 Set `vertex_color_use_as_albedo` on particle draw materials (muzzle) so `ParticleProcessMaterial.color` is visible; document it as required
- [x] 8.3 Drop the dead `FxData.one_shot` field
- [x] 8.4 Read the authored id past the 512-byte header cap in the asset browser
- [x] 8.5 Bound frozen-effect retention (frozen-age cap) and free particles early on the engine `finished` signal
- [x] 8.6 Give the particle derived duration the `2 * lifetime` emission-tail ceiling
- [x] 8.7 Skip warhead impact FX/sound on a zero applied-damage hit
- [x] 8.8 Ungate FX when no shroud grid exists yet (`ShroudSystem.is_grid_ready()`)
- [x] 8.9 Update `AGENTS.md` autoload count and table for `FxSystem`
