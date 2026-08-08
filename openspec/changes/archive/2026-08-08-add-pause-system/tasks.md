# Implementation Tasks

## 1. Input Action

- [x] 1.1 Add `pause` input action to `project.godot` bound to KEY_ESCAPE (physical_keycode 4194305)

## 2. Pause Menu Scene & Script

- [x] 2.1 Create `scenes/ui/PauseMenu.tscn`: full-rect `Control`, `visible = false`, `process_mode = PROCESS_MODE_ALWAYS`
- [x] 2.2 Add dim `ColorRect` overlay (full-rect, semi-transparent, `mouse_filter = MOUSE_FILTER_STOP`)
- [x] 2.3 Add `CenterContainer`/`VBoxContainer` with two `Button`s: "Return to game", "Quit to desktop", wired to `pressed` signals
- [x] 2.4 Create `scripts/ui/PauseMenu.gd` (extends Control): `_ready` hides menu + connects buttons
- [x] 2.5 Implement `_unhandled_input`: on `pause` action, skip if `_esc_busy()`, else toggle pause
- [x] 2.6 Implement `_esc_busy()` guard: `BuildingManager.is_build_mode` or `Sidebar.is_sell_mode()` / `is_repair_mode()` / `is_debug_place_mode()`
- [x] 2.7 Implement `_toggle_pause()` (swap `get_tree().paused` + `visible`) and the two button handlers (resume / `get_tree().quit()`)

## 3. Scene Wiring

- [x] 3.1 Add public `is_debug_place_mode() -> bool` getter to `scripts/ui/Sidebar.gd`
- [x] 3.2 Instance `PauseMenu` under the `HUD` in `scenes/maps/MapBase01.tscn`

## 4. Tests

- [x] 4.1 Create `test/integration/test_pause_menu.gd` with `InputMap.has_action("pause")` guard assertion
- [x] 4.2 Test ESC (real `InputEventKey`) through `_unhandled_input` pauses tree + shows menu; pausable sibling `can_process()` false, menu `can_process()` true; toggles back clean
- [x] 4.3 Test guard: build mode active → ESC does not pause; reset build mode
- [x] 4.4 Test "Return to game" and "Quit to desktop" buttons wired to their handlers
- [x] 4.5 Ensure every pause test unpauses before returning (protect the shared runner)

## 5. Verification

- [x] 5.1 Run `redot --headless -s test/run_tests.gd` — all suites green
- [x] 5.2 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check` on changed files

## 6. Robustness & Docs (post-research)

- [x] 6.1 MouseHandler resets drag/selection-rect state on `NOTIFICATION_PAUSED`
- [x] 6.2 Correct `design.md` audio note (default players auto-pause; music-through-pause deferred to #255) and document the WHEN_PAUSED-vs-ALWAYS rationale (D2)
- [x] 6.3 Test: pause resets mouse drag state
- [x] 6.4 Force default cursor while paused (D8) + test + spec requirement
- [x] 6.5 Unpause input debounce so the resume click does not pass through as an order (D9) + tests + spec requirement
