## Why

Units currently have no way to instantly halt all activity. In Tiberian Sun, pressing S (Stop) gracefully stops units mid-movement, mid-harvest, or any other activity. Without this, players cannot quickly recall units or cancel operations, which is critical for RTS gameplay.

## What Changes

- Add `stop` input action (Ctrl+S) to `project.godot`
- Add `stop()` method to `MovementController` that gracefully finishes current cell transition before stopping
- Add Ctrl+S hotkey handler in `MouseHandler` that cancels harvesting and stops movement for all selected entities
- Units stop at the nearest cell center on their path, not mid-path (no snapping/teleportation)

## Capabilities

### New Capabilities
- `stop-command`: Stop command that halts all unit activity (movement, harvesting) with graceful cell-aligned stopping

### Modified Capabilities

## Impact

- `project.godot`: New input action `stop`
- `scripts/components/MovementController.gd`: New `_stopping` flag, `stop()`, `_finish_stop()` methods; modified `_handle_moving_movement()` and `_handle_wait()`
- `scripts/hud/MouseHandler.gd`: New Ctrl+S hotkey handler in `_process()`
- `scripts/components/HarvestComponent.gd`: No changes (existing `cancel_harvest()` is reused)
