## 1. RadarComponent state signal

- [x] 1.1 Add `signal radar_state_changed(is_active: bool)` to `scripts/components/RadarComponent.gd`; track an internal `_is_active` and emit only on an actual flip
- [x] 1.2 In `_ready`, resolve the sibling `PowerComponent` and connect its `power_state_changed` to a private re-evaluation method; guard with `is_instance_valid`
- [x] 1.3 Evaluate the initial state on `_ready`/after `configure` so a component that registers already powered-down starts inactive without a spurious signal
- [x] 1.4 Keep `has_radar()` as the single query; verify it agrees with `_is_active`
- [x] 1.5 Unit test (`test/unit/test_radar_component.gd`): power flip emits `radar_state_changed(false)` then `(true)` once each; no-power-component entity reports true and emits nothing; `radar = false` reports false regardless

## 2. RadarSystem autoload

- [x] 2.1 Create `scripts/core/RadarSystem.gd` (no `class_name`; autoload name is the global) with `signal radar_availability_changed(player_id: int)`, `var force_online: bool = false`, and a per-player online count
- [x] 2.2 Register/unregister `RadarComponent` via `get_tree().node_added` / `node_removed`; resolve owner id from the parent's `StatsComponent.player_id` (mirror `PowerGrid._owner_id`)
- [x] 2.3 At registration, seed the count from the component's current `has_radar()`; connect `radar_state_changed` to increment/decrement the count and emit `radar_availability_changed` only when the player's availability flips
- [x] 2.4 Implement `player_has_radar(player_id: int) -> bool` returning `force_online or count > 0`; expose per-player counts for tests
- [x] 2.5 Register the autoload in `project.godot` after `PowerGrid` (consumers connect in `_ready`)
- [x] 2.6 Unit test (`test/unit/test_radar_system.gd`): placement makes a player available; destroying the last radar makes them unavailable; a second radar for an already-available player does not re-emit; per-player isolation; non-radar nodes are ignored
- [x] 2.7 Unit test power path: a radar-owned player entering low power emits `radar_availability_changed` false, and recovery emits true
- [x] 2.8 Unit test override: `force_online = true` makes `player_has_radar` true with no radar; setting it false restores the computed result
- [x] 2.9 Integration test against `EntityFactory` + real `GDI_RADAR`/power-plant `.tres` mirroring `test/integration/test_power_grid_integration.gd`: place radar → available, trigger deficit via power plant removal → unavailable, restore → available

## 3. Minimap radar gate and offline placeholder

- [x] 3.1 Add `_radar_online` state to `scripts/ui/Minimap.gd`; initialize from `RadarSystem.player_has_radar(local_player_id)` and connect `radar_availability_changed` to update it (filter to the local player id)
- [x] 3.2 Early-return in `_refresh()` while offline (no fog/overlay/entity composition) and skip `_draw_view_rect()` in `_draw()`
- [x] 3.3 Draw the offline placeholder in `_draw()`: filled black rect over the control with a centered `OFFLINE` label (use the existing UI font)
- [x] 3.4 Guard `_gui_input` so no click is processed while offline; keep `mouse_filter = STOP` so `UIUtil.is_mouse_over_minimap()` continues to shield the region from world handlers
- [x] 3.5 Add pure static helpers for the gate predicate (e.g. `radar_gate_online(force, count)`) so the state logic is headless-testable
- [x] 3.6 Extend `test/unit/test_minimap.gd`: gate helper truth table; local-available → live path, local-unavailable → offline path
- [x] 3.7 Verify the runtime MapEditor still shows no gameplay minimap and radar-less maps start offline, not crashing on a null `RadarSystem`

## 4. Static transition

- [x] 4.1 Create `shaders/ui/RadarStatic.gdshader`: a `TIME`-driven GPU noise shader with a `uniform float intensity` (0 = transparent/no contribution)
- [x] 4.2 Build the static overlay as a full-rect child `Control`/`ColorRect` with a `ShaderMaterial` in `Minimap._ready` (runtime construction, no `.tscn` structural change — `FogRenderer` precedent)
- [x] 4.3 Drive `intensity` from an eased transition value: ease toward 1 when availability flips false, toward 0 when it flips true, using an exponential ease with a snap threshold (mirror `PowerBar._advance`)
- [x] 4.4 Ensure the overlay settles to zero contribution when the transition completes (no residual static in either steady state)
- [x] 4.5 Extend `test/unit/test_minimap.gd` for the pure easing helper: values move toward the target and snap on arrival; a settled transition yields zero intensity
- [x] 4.6 Hold the pre-flip panel under the rising static and swap content only at full coverage (`shows_offline_panel` predicate) in both directions, so the destination panel never flashes; a flip mid-rise keeps the held panel; truth-table and state-level tests

## 5. Debug override

- [x] 5.1 Add a `Force radar online` `CheckBox` to `CheatsContent` in `scenes/ui/DebugMenu.tscn`
- [x] 5.2 In `scripts/ui/DebugMenu.gd`, add the `@onready` ref, connect `toggled` to set `RadarSystem.force_online`, and include it in `reset_state()` (uncheck + `force_online = false`)
- [x] 5.3 Test (`test/unit/test_debug_menu.gd` or existing): toggling sets `RadarSystem.force_online`; scene-change reset clears it

## 6. Docs and cleanup

- [x] 6.1 Add a `radar gate` entry (and `RadarSystem`) to `GLOSSARY.md` in the appropriate cluster, anchored to the `radar` spec
- [x] 6.2 Run `gdlint` and `gdformat --check` on all changed `.gd` files; confirm no tabs were introduced in multi-line strings
- [x] 6.3 Run the full test suite (`redot --headless -s test/run_tests.gd`) and confirm no regressions
- [ ] 6.4 Manual check in-editor: build a radar → minimap comes online; sell it → static transition to `OFFLINE`; toggle `Force radar online` → minimap returns; verify minimap clicks are inert while offline
