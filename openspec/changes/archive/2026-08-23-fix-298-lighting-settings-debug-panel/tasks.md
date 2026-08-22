## 1. Lighting controls group registration

- [x] 1.1 Add `add_to_group("lighting_controls")` in `LightingControls._ready()` (`scripts/environment/LightingControls.gd`, line 64), alongside the existing node captures.

## 2. Debug panel lookup + lazy resolve

- [x] 2.1 Replace `DebugMenu._ready()`'s parent-child lookup at `scripts/ui/DebugMenu.gd:75-77` with `get_tree().get_first_node_in_group("lighting_controls")`.
- [x] 2.2 Move the group resolve into `_init_lighting_sliders()` and make it lazy, re-checking the group if `lighting_controls` is null, guarded by a `_lighting_sliders_wired` flag to prevent double-wiring.
- [x] 2.3 Re-invoke `_init_lighting_sliders()` from `_toggle_section` when the Lighting section is opened, so wiring completes once `LightingControls` has readied.

## 3. Regression test

- [x] 3.1 Add `test/unit/test_lighting_controls.gd` (and `.uid`): instantiate the real `MapBase01`, wait for full ready, open the Lighting section, and assert a `lighting_controls.set(...)` (the slider handler) changes the real `DirectionalLight3D.light_energy` and `WorldEnvironment` fog density.
- [x] 3.2 Verify the test fails on pre-fix code (null `lighting_controls`) and passes after.

## 4. Verification

- [x] 4.1 Run the custom test runner: `redot --headless -s test/run_tests.gd`
- [x] 4.2 Run `gdlint` and `gdformat --check` on changed scripts and tests.
- [ ] 4.3 Manually confirm in the Redot editor that Debug-panel lighting sliders visibly alter the scene.