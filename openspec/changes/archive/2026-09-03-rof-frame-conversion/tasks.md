## 1. Regression test first (must fail on the current 60/ROF code)

- [x] 1.1 In `test/unit/test_combat_component.gd`, add `test_cooldown_uses_rof_frames_at_ts_logic_rate`: build a weapon with `rate_of_fire = 30`, fire it once via `_fire_weapon`, assert `_cooldowns[weapon_index]` is 1.0 seconds (today it computes 2.0 and the test fails)

## 2. Conversion fix

- [x] 2.1 Add `const TS_LOGIC_FPS: float = 30.0` to `CombatComponent` and change `_fire_weapon` to `_cooldowns[_current_weapon_index] = rof / TS_LOGIC_FPS`
- [x] 2.2 Fix the `WeaponData.rate_of_fire` doc comment to "TS ROF rearm-delay frames (logic 30 fps); seconds_between_shots = ROF / 30"

## 3. Data audit

- [x] 3.1 Diff every `resources/weapons/*.tres` `rate_of_fire` against the matching `[Weapon] ROF=` in `references/rules.ini` and confirm they still match verbatim (no hand-tuned values under the old formula)

## 4. Verification

- [x] 4.1 Run full suite `redot --headless -s test/run_tests.gd` — all tests pass, including the new cadence test
- [x] 4.2 Run `gdlint` and `gdformat --check` on touched scripts, then `grep -P '\t' scripts/**/*.gd` for tab contamination
- [ ] 4.3 Verify in-editor: light infantry fires roughly every 0.7 s (vs 2.86 s before); tank shells and rockets follow original-feel cadences
