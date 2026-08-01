## 1. MovementController API

- [x] 1.1 Add `movement_started` signal
- [x] 1.2 Add `get_target_position() -> Vector3` (last waypoint, or parent position when idle)
- [x] 1.3 Add `is_moving() -> bool` (`_state != State.IDLE`)
- [x] 1.4 Emit `movement_started` at the end of `set_target_position()` once a path is committed, gated on an `is_order := false` param so only genuine player-order entry points (not internal re-paths or scatter/nudge) fire it

## 2. SelectComponent move target line

- [x] 2.1 Add fields: move line mesh, movement controller reference, timer
- [x] 2.2 In `_ready()`, find sibling `MovementController`; create the green mesh (reuse rally line material treatment) and a 1s one-shot `Timer`; connect `movement_started` and `timeout`
- [x] 2.3 Add helpers to show/redraw and to hide the line; redraw draws the line to the destination cell center with a small filled rectangle marker
- [x] 2.4 Exclude the move line mesh and timer from the shared `_update_visibility()` child loop; handle selection edges (show when selected+moving, hide+stop on deselect)
- [x] 2.5 Add `movement_started` handler that shows/restarts the line when selected, and a timeout handler that hides it
- [x] 2.6 Add `_process()` that redraws the line each frame while it is visible

## 3. Tests

- [x] 3.1 Unit-test `MovementController.get_target_position()` (waypoint vs idle) and `is_moving()`
- [x] 3.2 Run the headless suite; ensure all tests pass
