## 1. Data & Registry

- [x] 1.1 Add `speed: float = 0.0` export to `WeaponData.gd` and `default_projectile_speed: float = 12.0` plus `projectiles: Dictionary` + `get_projectile(id)` to `GlobalRules.gd` (mirror `get_warhead`)
- [x] 1.2 Wire the existing `resources/projectiles/*.tres` files (20, not 24) into `global_rules.tres`'s `projectiles` dictionary in the Redot editor
- [x] 1.3 Unit test: registry resolves every weapon's projectile id (scan `resources/weapons/*.tres` → `get_projectile` non-null); speed precedence test (override > weapon > default)

## 2. Projectile Scene & Controller

- [x] 2.1 Create `scenes/components/Projectile.tscn` (root `ProjectileController` + placeholder visual child) and `scripts/components/ProjectileController.gd`; commit both `.uid` files together
- [x] 2.2 Implement payload: `get_damage_info()` returning `{amount, type, source, position}`; `impacted(position)` signal; `setup(projectile_data, weapon, shooter, target)` initialization
- [x] 2.3 Implement invisible teleport-detonate: skip flight, position at target coordinate, detonate through `HitboxComponent` pipeline at dispatch (same tick as legacy hitscan, no physics-frame dependency)
- [x] 2.4 Implement visible flight: straight-line advance at resolved speed; homing heading slerp capped at `homing_turn_rate` when `is_guided`; visual faces heading when `rotates_to_face`, tinted with `tint_color`
- [x] 2.5 Implement shape-cast detection along per-frame motion segment (`collide_with_areas = true`), closest valid hit wins
- [x] 2.6 Implement friendly-fire filter in the cast result: skip shooter and shooter's allies (PlayerManager team check); neutrals/civilians trigger normally
- [x] 2.7 Implement arming (`arm_delay` frames suppress all detonation) and the four detonation triggers (contact, close proximity, overshoot, max range from `attack_range * CELL_SIZE`) with snap-to-victim on close detonations; `queue_free` on terminal states; target-death handling (continue to last known position)

## 3. Combat Dispatch Branch

- [x] 3.1 Extend `get_damage_info` contract handling in `CombatComponent._fire_weapon`: resolve `weapon.projectile` via `GlobalRules.get_projectile`; on success instantiate/configure/parent the projectile at shooter position + `fire_offset` and skip direct damage; on failure keep the legacy hitscan path untouched
- [x] 3.2 Unit tests: payload contract keys and armor-multiplied amount (SA vs heavy = 0.25×), clamps, zero-multiplier pairing, teleport-detonate tick parity with legacy hitscan damage

## 4. Integration Tests (headless, synchronous manual `_physics_process` ticks)

- [x] 4.1 Tunneling test: projectile moving >1 cell/frame across a thin enemy hitbox still detonates on it (motion-segment cast)
- [x] 4.2 Exclusion tests: point-blank shooter spawn never detonates on shooter; motion through allied hitbox passes through; enemy/civilian hitbox detonates
- [x] 4.3 Trigger tests: unarmed projectile passes through; guided projectile detonates on overshoot when target dodges; max-range fizzle frees without `impacted`; target-death in flight continues to last known position and frees
- [x] 4.4 Regression: weapon with unresolvable projectile id applies legacy hitscan damage; existing combat tests pass unchanged

## 5. Validation & Wrap-up

- [x] 5.1 Run `redot --headless -s test/run_tests.gd` — full suite green
- [x] 5.2 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check` (fix tabs in multi-line strings if gdformat introduces any); fix findings
- [ ] 5.3 Tune `default_projectile_speed` sanity pass: guided heatseeker visibly catches a moving buggy in a test map scene (manual, editor)
- [ ] 5.4 Update GLOSSARY.md anchors for new terms (`teleport-detonate`, `detonation trigger`, `flight model`) to the archived spec paths after merge; verify no Undecided-term guesses were used
- [x] 5.5 Archive the change via `openspec archive projectile-system` before PR merge (CI gate)
