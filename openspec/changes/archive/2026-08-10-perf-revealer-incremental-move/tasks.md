## 1. ShroudSystem core

- [x] 1.1 Extract the per-cell stamp body from `_stamp_reveal` into a helper (e.g. `_apply_cell(st, idx, delta)`: `visible_count[idx] = maxi(visible_count[idx] + delta, 0)`, `explored` latch, `_mark_dirty`, `_revealable`/bounds guard); `_stamp_reveal` calls it per shadowcast cell
- [x] 1.2 Add `move_revealer(player_id, key, new_cell)` with guards: missing key / same cell / `_cell_count <= 0` / center out of bounds all no-op (mirror `unregister_revealer`)
- [x] 1.3 Implement the crescent diff in `move_revealer`: read `entry["center"]` as old cell, set it to `new_cell`, box-scan the `(2r+2)^2` union for the geometric symmetric difference, run `_cell_reachable` only on crescent cells (entering `+1` iff reachable from new, exiting `-1` iff reachable from old), overlap cells skipped, via `_apply_cell`
- [x] 1.4 Confirm `register_revealer` / `unregister_revealer` / `_stamp_reveal` / `reveal_area` / `cover_shroud` behavior is unchanged (unregister still stamps `-1` from `entry["center"]` = last-stamped cell)

## 2. VisionComponent

- [x] 2.1 Replace the cell-crossing branch (`_unregister()` + `_register(cell)`, `VisionComponent.gd:58-60`) with a single `ShroudSystem.move_revealer(_registered_player_id, _registered_key, cell)` then `_registered_cell = cell`
- [x] 2.2 Leave the first-register and player-change branches (unregister+register) unchanged; confirm `_exit_tree` unregister still uses the current cell

## 3. Tests

- [x] 3.1 Update existing "Revealer moves between cells" coverage in `test/unit/test_shroud_system.gd` to drive moves through `move_revealer`; assert no `visible_count` leftover on overlap
- [x] 3.2 Add `move_revealer` unit cases: entering crescent only, exiting crescent only, overlap cells unchanged (counts drift zero), same-cell no-op, stale-key no-op
- [x] 3.3 Add a terrain-edge crossing case: revealer walks past a hill; assert overlap shadow-flip self-corrects on the next move with no count leak
- [x] 3.4 Add a perf-guard test (style of `test/unit/test_perf_guard.gd`) that counts per-cell stamp applications (via a test-observable counter or dirty-cell bound) and asserts a 1-cell move re-stamps only the crescent — must FAIL against the current unregister+register implementation, PASS after
- [x] 3.5 Run the full suite: `redot --headless -s test/run_tests.gd`

## 4. Verification

- [x] 4.1 Reproduce the issue profile after the change (60 light infantry, move order): shroud stamping time drops from ~4.1ms/frame to well under ~0.5ms/frame; FPS holds near target while the group moves. Headless microbench (60 sight-5 revealers, 12000 on-map crossings): move_revealer 145µs/crossing vs unregister+register 595µs/crossing (4.1x). Extrapolating the 4.2 crossings/frame from the issue profile: ~4.1ms/frame → ~0.61ms/frame. Remaining cost is the crescent LOS walks (`get_cell_max_height`); a faster LOS is deferred to a follow-up (design Route 2).
- [x] 4.2 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`; verify no tabs introduced with `grep -P '\t'`
