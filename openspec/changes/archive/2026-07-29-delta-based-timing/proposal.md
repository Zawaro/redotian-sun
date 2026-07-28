## Why

Game speed is driven by `Engine.time_scale`, which scales the `delta` passed to `_process`/`_physics_process`. Timers that accumulate `delta` scale with game speed and stay frame-rate independent; timers that increment an integer once per frame do not — they count real frames and ignore both game speed and frame rate. Three component timers still use per-frame integer counters, so their delays drift with frame rate and will not respond when game speed is added.

## What Changes

- Convert `DockHostComponent` queue-promotion delay from a per-frame counter (`_wait_counter` / `dock_wait_ticks`) to a delta-seconds accumulator (`_wait_seconds` / `dock_wait_seconds`).
- Convert `MovementController` path-repair re-check (`_repair_frames`) and blocked-wait timers (`_wait_frames` / `_wait_threshold`) to delta-seconds accumulators.
- **BREAKING** (editor-facing only): the `DockHostComponent.dock_wait_ticks` exported property becomes `dock_wait_seconds` (float). No packed scene or resource currently sets it, so no `.tscn`/`.tres` changes are required.
- Establish a project-wide invariant: component timers accumulate delta seconds, matching the pattern already used by `DockClientComponent._retry_cooldown`, harvest/growth timers, and stale/vacate timers.

## Capabilities

### New Capabilities
- `frame-rate-independent-timing`: All gameplay component timers accumulate elapsed delta seconds (not per-frame counts) so delays are stable across frame rates and scale with game speed via `Engine.time_scale`.

### Modified Capabilities

## Impact

- `scripts/components/DockHostComponent.gd` — export rename, accumulator conversion.
- `scripts/components/MovementController.gd` — two accumulator conversions; `_handle_wait` now receives `delta`.
- Tests: `test/unit/test_dock_host_component.gd`, `test/unit/test_dock_queue_step.gd` reference the renamed field and counter; updated plus a new delta-scaling assertion.
- No new dependencies. No runtime API changes for callers (internal timers only).
