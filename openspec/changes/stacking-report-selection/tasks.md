## 1. Regression tests first (must fail on the current random-pick code)

- [x] 1.1 In `test/integration/test_audio_voice_routing.gd`, rewrite `test_weapon_fire_parses_comma_report` to assert the first entry plays when unstacked: register two distinct committed audio ids, fire a weapon with `sound_report = "A,B"`, assert exactly `A` gained a live player (via a read-only `AudioManager.get_active_count(id)` helper) and `B` gained none
- [x] 1.2 Add `test_report_rotates_when_first_entry_saturated`: seed `REPORT_STACK_PER_ID` live copies of entry `A` via `AudioManager.play_sound`, fire the weapon, assert `B` gains a player and `A`'s count did not grow
- [x] 1.3 Add `test_report_all_saturated_plays_last_entry`: seed both ids at threshold, fire, assert the last entry gained a player
- [x] 1.4 Add `test_report_skips_unknown_id`: fire with `sound_report = "NO_SUCH_ID,B"`, assert `B` plays and no crash/warning failure
- [x] 1.5 Add `test_single_entry_report_unchanged`: single-entry list behaves like `play_sound` (one player spawned for that id)
- [x] 1.6 Run `redot --headless -s test/run_tests.gd` and confirm the new tests fail against the current random-pick implementation for the intended reason

## 2. AudioManager: stacking-driven report selection

- [x] 2.1 Add `REPORT_STACK_PER_ID: int = 3` constant with ponytail knob comment
- [x] 2.2 Add `get_active_count(id: String) -> int` read-only helper backed by `_active_players_by_id`
- [x] 2.3 Implement `play_report(ids: PackedStringArray, position: Vector3)`: strip edges, skip unknown ids with warning, play first entry below threshold via `play_sound`, fall back to last entry when all saturated; no-op on an empty list

## 3. CombatComponent rewiring

- [x] 3.1 Replace the `randi()` pick in `_play_fire_sound` with a `sound_report.split(",", false)` + `AudioManager.play_report(ids, global_position)` call, keeping the empty-report early return

## 4. Verification

- [x] 4.1 Run full suite `redot --headless -s test/run_tests.gd` — all tests pass, including the audio voice routing suite
- [x] 4.2 Run `gdlint` and `gdformat --check` on touched scripts, then `grep -P '\t' scripts/**/*.gd` for tab contamination
- [ ] 4.3 Verify in-editor: lone light infantry repeatedly fires with `INFGUN3`; a stacked squad firefight mixes in `GOSTGUN1`/`SLVKGUN1`
