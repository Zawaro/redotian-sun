## 1. Muzzle FLH

- [x] 1.1 `CombatComponent._body_muzzle_origin` returns `shooter.global_transform * weapon.fire_offset` (entity-local); mirror in `ProjectileController._ready()`'s no-spawn-origin fallback
- [x] 1.2 Author `fire_offset = Vector3(0, 0.5, -0.15)` on `games/ts/weapons/minigun.tres`
- [x] 1.3 Update `test_fx_triggers.gd` so the body muzzle assertion uses the entity-local composition and covers a rotated shooter
- [x] 1.4 Verify the turret body-muzzle test still passes

## 2. Particle quad size

- [x] 2.1 Add `quad_size: float = 0.1` to `scripts/data/FxData.gd`
- [x] 2.2 `FxSystem._build_particles` sizes the draw quad from `fx.quad_size`
- [x] 2.3 Set `quad_size` on `games/ts/fx/muzzle_flash_small.tres` so sparks are centimetres, not metres
- [x] 2.4 `test_fx_system.gd` asserts the built quad's size matches `quad_size`; `test_fx_content.gd` asserts the muzzle quad is a small fraction of a unit

## 3. Effect light

- [x] 3.1 Add `light_energy` (0 = none), `light_color`, `light_range` to `FxData`
- [x] 3.2 `FxSystem` adds an `OmniLight3D` (no shadows, layer 1) when `light_energy > 0`, as a child so it frees with the effect and is disabled by the fog-freeze visibility toggle
- [x] 3.3 Author a warm, short-lived light on `muzzle_flash_small.tres`
- [x] 3.4 `test_fx_system.gd` asserts a light is present only when energy > 0 and follows the effect

## 4. Impact size

- [x] 4.1 Redraw `games/ts/assets/fx/bullet_hit.png` so the 4-frame flash grows to fill the 16×16 cell
- [x] 4.2 Re-import (`redot --headless --import`) and assert in `test_fx_content.gd` the impact peaks at roughly one world unit

## 5. Specs and verification

- [x] 5.1 Add the `fx-system` deltas (particle quad size; effect point light) and the `combat-firing` delta (entity-local body muzzle)
- [x] 5.2 Run `redot --headless -s test/run_tests.gd`; run `gdlint` and `gdformat --check`
- [x] 5.3 `openspec validate fix-fx-visuals --strict`, then archive the change
