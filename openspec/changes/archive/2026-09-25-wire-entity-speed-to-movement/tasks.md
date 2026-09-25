## 1. Conversion helper (GlobalRules)

- [x] 1.1 Add `LEPTONS_PER_CELL` / `TS_SPEED_FACTOR` constants and `speed_to_units_per_second(speed: float) -> float` to `scripts/data/GlobalRules.gd`, deriving from `logic_fps` and `CellUtil.CELL_SIZE`
- [x] 1.2 Add unit tests asserting `speed_to_units_per_second(5.0) == 3.0` at `logic_fps = 30`, `== 1.5` at `logic_fps = 15`, and `== 0.0` for `speed = 0.0` (derive the expected values from 256 leptons/cell, independent of the helper body)
- [x] 1.3 Run `redot --headless -s test/run_tests.gd` and confirm the new conversion tests pass

## 2. Wire per-unit speed into MovementController

- [x] 2.1 Add a private `_speed_leptons` field and an idempotent `_apply_speed()` to `scripts/components/MovementController.gd`; set `move_speed = _rules.speed_to_units_per_second(_speed_leptons)` when rules resolve, else keep the export default
- [x] 2.2 In `configure(data: EntityData)`, store `_speed_leptons = data.speed` and call `_apply_speed()` (do not read `_rules`, which is unresolved at this point)
- [x] 2.3 Call `_apply_speed()` in `_ready()` after `_rules` is resolved, so the converted speed is in force before the first movement step
- [x] 2.4 Correct the `EntityData.speed` doc comment in `scripts/data/EntityData.gd` to "TS Speed, leptons per frame" (remove "cells per tick")

## 3. Regression test — behavior, not formula

- [x] 3.1 Add a test that builds two controllers from `EntityData` with `speed = 6.0` and `speed = 10.0` on a non-ramping locomotor (Hover/Amphibious/Ship), sets `_speed_jitter = 1.0`, steps movement over the same flat clear path, and asserts the two rates are in ratio 6:10
- [x] 3.2 Assert each measured rate matches the independently derived expectation (`speed * 2.56 * logic_fps * CELL_SIZE / 256` u/s) within tolerance, with the expected value computed from TS lepton geometry rather than copied from the production helper
- [x] 3.3 Add a non-vacuity control proving the same setup at a flat `move_speed = 8.0` would fail the ratio/rate assertion
- [x] 3.4 Assert a controller constructed without `configure()` keeps its export `move_speed` (existing mechanics tests unaffected)

## 4. Docs and spec hygiene

- [x] 4.1 Add GLOSSARY rows for `Speed` (TS leptons per frame) and the movement time base, linking to `entity-data` / `global-rules` / `locomotor` specs
- [x] 4.2 Run `openspec validate --change wire-entity-speed-to-movement` (or `openspec status`) and confirm all artifacts validate

## 5. Verification

- [x] 5.1 Run `redot --headless -s test/run_tests.gd` and confirm the full suite passes
- [x] 5.2 Run `gdlint` on changed scripts and `gdformat --check`; then `grep -P '\t' scripts/**/*.gd` for tab introduction in multi-line strings
- [x] 5.3 Confirm two units of different `speed` traverse the same path at different rates matching the chosen base — covered by automated tests (`test_per_unit_speed_traverses_at_different_rates`, `test_entity_factory_wires_converted_speed`, `test_pursuing_projectile_catches_fastest_unit`); no manual smoke left outstanding

## 10. Review fixes

- [x] 10.1 Raise `GlobalRules.default_projectile_speed` to `24.0` (2× base) so the default outruns the fastest unit; spec-authors the parity requirement in `projectile-runtime`
- [x] 10.2 Add `test_default_projectile_outruns_fastest_unit` and behavioral `test_pursuing_projectile_catches_fastest_unit`
- [x] 10.3 Rewrite the non-vacuity control to force both controllers to flat `8.0`, run `_travel`, and assert the measured rate ratio is `1.0` (so the 10:6 assertion provably fails pre-fix)
- [x] 10.4 Add `EntityFactory.create_entity` integration tests: `speed = 6` → `move_speed = 3.6`; `speed = 0` → no `MovementController`
- [x] 10.5 Rename `_speed_units` → `_speed_leptons`; document `_apply_speed()`'s `_rules` fallback side effect
- [x] 10.6 Correct the proposal's dead-scene rationale and the 2.56 "clamp factor" wording (linear scale factor; engine clamp intentionally not modeled)
