## 1. Sidebar counter

- [x] 1.1 `scripts/ui/Sidebar.gd`: add counter state (`displayed`, `target`), tuning constants (`GAIN_STEP_INTERVAL`, `SPEND_STEP_INTERVAL`, `STEP_DIVISOR`, `MIN_STEP`, `MAX_STEP` with `ponytail:` knob markers), and `_step_counter(delta)` implementing time-based accumulate → proportional clamped step → label update
- [x] 1.2 `scripts/ui/Sidebar.gd`: rework `_on_credits_changed` to store the target for the local player and enable processing (no instant text write); keep `_ready()` as a forced display (set `displayed`/label directly, no animation)
- [x] 1.3 `scripts/ui/Sidebar.gd`: play `ECON_INCOME`/`ECON_SPEND` via `AudioManager.play_sound` on each applied step by direction; disable `_process` whenever displayed == target

## 2. Remove event-driven listener

- [x] 2.1 Delete `scripts/core/EconomyAudioListener.gd` and remove the `EconomyAudioListener` entry from `project.godot` autoloads
- [x] 2.2 Update the autoload table in `AGENTS.md` (23 → 22)

## 3. Tests

- [x] 3.1 Rewrite `test/unit/test_economy_audio.gd` against the sidebar counter: forced display is silent and instant; gain animates up-ticks (`ECON_INCOME` per step), deduction animates slower down-ticks (`ECON_SPEND`); other-player events silent; counter idle (no step updates) when settled; step size follows divisor/clamp on small and large gaps; animation completes with a missing audio file id (warn-and-continue)
- [x] 3.2 Update `test/integration/test_sidebar_credits.gd`: ready shows balance instantly; `credits_changed` settles at the new target after stepping; non-local balances ignored
- [x] 3.3 Verify the old listener tests have no leftover references (`EconomyAudioListener`, `ECON_` reason allowlists) anywhere in `test/`

## 4. Verification

- [x] 4.1 `redot --headless -s test/run_tests.gd` — full suite green
- [x] 4.2 `gdlint` + `gdformat --check` on touched files; grep for tabs in multi-line strings after formatting
- [ ] 4.3 Manual: harvest a tiberium node and place a building — counter ticks up fast, down slower, settles exactly; debug add-credits animates

## 5. Regression fix — counter starving under gradual production deduction

- [x] 5.1 `scripts/ui/Sidebar.gd`: `_on_credits_changed` resets the cadence accumulator only when the counter is settled — per-frame `credits_changed` from gradual production deduction (`ProductionManager._process` drains cost/build_time per second) previously reset it every frame, freezing the label mid-drain until the drain stopped (looked like credits were only spent on pause)
- [x] 5.2 `test/unit/test_economy_audio.gd`: regression test driving a real `ProductionManager` drain alongside the counter — balance drains exactly cost/build_time per second while the counter tracks it, and settles at the drained balance
- [x] 5.3 `scripts/ui/Sidebar.gd`: clamp the cadence accumulator to one interval per frame (`minf(acc + delta, interval)`) — gain frames (interval 0) never drained it, so time stored during a long income animation burst out as extra steps on the first spend frame, collapsing the count-down to a jump; regression test drives an in-flight gain with ongoing income, then a spend, asserting no burst step on the first spend frame
