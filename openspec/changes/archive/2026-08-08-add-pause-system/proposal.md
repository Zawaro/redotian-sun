## Why

There is no pause: `get_tree().paused` is never set anywhere, no pause menu exists, and no input action triggers one. Players cannot suspend an in-progress game (units keep moving, production/economy keep running), which is a core RTS expectation and a prerequisite for the GDI Mission 01 playable loop.

## What Changes

- Add a `pause` input action bound to ESC (Key) in `project.godot`.
- New `PauseMenu` scene (`scenes/ui/PauseMenu.tscn`) + script (`scripts/ui/PauseMenu.gd`), instantiated under the gameplay HUD in `scenes/maps/MapBase01.tscn` so every map scene gets it.
- ESC toggles pause: `get_tree().paused = true` (show menu) / `false` (hide menu). The pause menu itself runs with `process_mode = PROCESS_MODE_ALWAYS` so it stays interactive while everything else freezes.
- Pause menu UI: dim full-screen overlay plus two plain `Button`s — "Return to game" (resume) and "Quit to desktop" (`get_tree().quit()`).
- ESC guard: ESC first cancels an active build / sell / repair / debug-place mode (existing behavior wins); only when none is active does it open the pause menu. Requires a small public `is_debug_place_mode()` getter on `Sidebar`.
- Integration tests under `test/integration/test_pause_menu.gd`.

## Capabilities

### New Capabilities

- `pause-system`: ESC toggles a game-wide pause; the pause menu is interactive while paused; resume and quit-to-desktop actions; ESC conflict with existing cancel-modes is resolved.

### Modified Capabilities

<!-- None: no existing spec's requirements change. -->

## Impact

- `project.godot` — new `pause` input action (ESC).
- `scenes/maps/MapBase01.tscn` — PauseMenu instance added to the HUD (all map scenes inherit it).
- `scenes/ui/PauseMenu.tscn` + `scripts/ui/PauseMenu.gd` — new.
- `scripts/ui/Sidebar.gd` — one new public getter `is_debug_place_mode()` (guard support; no behavior change).
- Autoloads consulted by the guard: `BuildingManager` (`is_build_mode`), `Sidebar` (`is_sell_mode()` / `is_repair_mode()` / `is_debug_place_mode()`).
- Tests: `test/integration/test_pause_menu.gd`.
