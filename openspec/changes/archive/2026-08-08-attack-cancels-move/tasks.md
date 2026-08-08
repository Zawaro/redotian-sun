## 1. CombatComponent: stop ground unit on attack

- [x] 1.1 In `set_target()` (`scripts/components/CombatComponent.gd`), branch the MovementController halt: `cancel_move_retain_vertical()` when `mc.is_airborne_jumpjet()`, else `mc.stop()` for ground units
- [x] 1.2 Add a `force: bool = false` parameter to `_move_toward_target()` and change the guard to `if mc and (force or not mc.is_moving())`
- [x] 1.3 In `set_target()`, after the halt, when the horizontal distance to the target exceeds `weapon.attack_range * CellUtil.CELL_SIZE`, call `_move_toward_target(true)` so the approach path supersedes the residual stop-glide in the same frame

## 2. Regression tests

- [x] 2.1 Add test: moving ground unit + in-range attack → old move destination abandoned, unit settles to IDLE and fires from current position
- [x] 2.2 Add test: moving ground unit + out-of-range attack → move destination becomes an approach point within weapon range of the target (not the old destination)
- [x] 2.3 Verify existing tests still pass: `test_player_move_clears_attack_target`, `test_combat_move_preserves_attack_target`, jumpjet interrupt tests (updated `test_jumpjet_attack_interrupts_airborne_move` to assert the new immediate-approach behavior per the "Attack cancels player move" requirement)

## 3. Verification

- [x] 3.1 Run unit tests: `redot --headless -s test/run_tests.gd`
- [x] 3.2 Run lint and format: `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`
