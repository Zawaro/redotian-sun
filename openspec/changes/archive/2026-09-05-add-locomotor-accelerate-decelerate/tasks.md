# Tasks: Speed Ramp

- [x] Add `accelerate`/`decelerate` to `Locomotor.gd` Behavior Flags group
- [x] Add ramp constants to `GlobalRules.gd` + `global_rules.tres`
- [x] Implement ramp core in `MovementController.gd`:
  - Add `_ramp_speed: float` state
  - Add `_get_ramp_factor()` and `_update_ramp_speed(delta)` helpers
  - Integrate into per-tick step chain
  - Integrate into final approach step
  - Add reset edges in `_finish_stop()` and arrival blocks
  - Add decel-only init on fresh start
- [x] Enable both flags in `resources/locomotors/Track.tres` and `Wheel.tres`
- [x] Add `test/unit/test_movement_ramp.gd` with acceptance scenarios
- [x] Add `speed ramp` to GLOSSARY.md Movement section
- [x] Verify: `gdlint` + `gdformat --check` — all checks pass
