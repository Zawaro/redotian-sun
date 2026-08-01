## Why

When a selected unit is moving, the player has no visual confirmation of where it is headed. Buildings already show a rally line to their rally point, but ordering a unit to move gives no equivalent feedback. A brief green line from the unit to its destination makes move orders legible at a glance.

## What Changes

- Add a **move target line** to `SelectComponent`: a green line from the selected unit to the final cell of its current move order, with a small filled marker at the destination cell center.
- The line appears when a selected unit starts (or is already executing) a move order, stays visible for 1 second, then hides automatically.
- Deselecting resets and hides the line immediately; reselecting a still-moving unit restarts the 1-second window.
- Expose the current move destination and an "is moving" check from `MovementController`, plus a `movement_started` signal so the line can react to newly issued orders.
- Reuse the rally line's layer treatment (unshaded green, `no_depth_test`, `render_priority = 100`) so both feedback lines render consistently over terrain.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `select-component`: adds a move target line visual, driven by the selected unit's movement state and a 1-second timer.

## Impact

- `scripts/components/SelectComponent.gd` — new mesh, timer, and visibility logic for the move target line.
- `scripts/components/MovementController.gd` — new `movement_started` signal, `get_target_position()` and `is_moving()` getters.
- No `.tscn` changes: the mesh and timer are created at runtime (same as the existing rally line), so packed scenes remain backward compatible.
