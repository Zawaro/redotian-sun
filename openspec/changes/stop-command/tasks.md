## 1. Input Setup

- [x] 1.1 Add `stop` input action to `project.godot` (Ctrl+S, physical_keycode 83)

## 2. MovementController Stop Logic

- [x] 2.1 Add `stop()` method — handle IDLE (no-op), ROTATING (immediate stop), WAIT (stop if at cell center), MOVING (truncate path to next cell center)
- [x] 2.2 Add `_finish_stop()` method — clear waypoints, state; release cell; clear debug path
- [x] 2.3 MOVING truncation: project one cell-length forward along movement direction to find the actual next cell center (handles smoothed paths that skip intermediate waypoints)

## 3. Stop Hotkey Handler

- [x] 3.1 Add Ctrl+S stop hotkey handler in `MouseHandler._process()` — cancel harvesting and stop movement for selected entities

## 4. Testing

- [x] 4.1 Run `gdlint` and `gdformat` on modified files
- [x] 4.2 Run test suite (`redot --headless -s test/run_tests.gd`)
