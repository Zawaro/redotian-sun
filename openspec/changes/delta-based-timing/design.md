## Context

Redot passes a per-tick `delta` (seconds since last tick) to `_process` and `_physics_process`. When game speed is applied through `Engine.time_scale`, the engine multiplies that `delta` by the scale factor, so any timer expressed as an accumulation of `delta` automatically follows game speed and is independent of the actual frame rate.

Most timing in the project already follows this pattern — build progress, growth timers, stale/vacate timers, and `DockClientComponent._retry_cooldown` all accumulate or decrement by `delta`. Three timers were left as integer per-frame counters:

- `DockHostComponent._wait_counter` (compared against `dock_wait_ticks`) — queue promotion delay.
- `MovementController._repair_frames` (compared against `10`) — periodic re-check of the next waypoint cell.
- `MovementController._wait_frames` (compared against `15` and `_wait_threshold`) — blocked-unit scatter/reroute wait.

Integer counters increment once per tick regardless of tick duration, so they measure frames, not time. They neither scale with `Engine.time_scale` nor stay constant when frame rate varies.

## Goals / Non-Goals

**Goals:**
- Every remaining component timer accumulates `delta` seconds, so delays are frame-rate independent and scale with game speed.
- Preserve current real-world delay durations at 60 FPS (the rate the existing frame thresholds were tuned for).
- Keep tuning knobs visible where they already were (an exported property for the dock delay; named constants for the movement delays).

**Non-Goals:**
- Implementing the game-speed control itself (`Engine.time_scale` wiring / UI). This change only makes the timers ready for it.
- Introducing a fixed-timestep or lockstep simulation loop. The project uses Redot's variable-delta loop; scaling `delta` is sufficient.
- Touching timers that already accumulate `delta`.

## Decisions

**Convert each counter to a seconds accumulator, comparing against a seconds threshold.** This mirrors the existing `_retry_cooldown` pattern already in `DockClientComponent`, so the codebase stays internally consistent. Alternative considered: a shared `Timer` node or a reusable timer helper class — rejected as over-built for three independent scalar accumulators that live inside already-running `_process`/`_physics_process` loops.

**Rename `dock_wait_ticks: int` to `dock_wait_seconds: float`.** The property's unit changes from frames to seconds, so keeping the old name would be misleading. No packed scene or resource sets this property (verified by grep), so the rename has no scene-migration cost. Alternative considered: keep the name and reinterpret it as seconds — rejected because a property named `_ticks` holding seconds is a future foot-gun.

**Derive the new seconds thresholds from the old frame counts at 60 FPS** (e.g. `10 frames → 10/60 s`, `15 → 15/60`, `25 → 25/60`). Expressed as `x / 60.0` constants so the origin stays legible and the values remain easy to retune. The exact durations are cosmetic debounce/scatter delays, not gameplay-critical, but preserving them avoids behavioural drift.

**`_handle_wait` gains a `delta` parameter** so it can accumulate time; it is only called from the `State.WAIT` branch of `_physics_process`, which already has `delta`.

**One-shot mid-wait scatter via a boundary check.** The old code fired the mid-wait scatter exactly once at frame 15 using integer equality. With a float accumulator, equality is unreliable, so it fires on the tick that crosses the threshold: `time >= T and time - delta < T`. This needs no extra state variable.

## Risks / Trade-offs

- [Float boundary in tests] Existing dock tests step `_process(0.1)` a fixed number of times and expect promotion on a specific step. → Test helpers map the step count to a matching seconds threshold (`steps * 0.1`) so the accumulator crosses exactly on the intended step; `>=` comparison keeps the boundary tick inclusive.
- [Behavioural drift if run far from 60 FPS previously] Old delays were frame-count based, so at non-60 FPS the real duration already differed. The new values fix the duration in seconds, which is the intended correction, not a regression. → Documented; durations chosen to match the 60 FPS baseline the thresholds were tuned at.
- [Very large `delta` spikes] A single huge tick could cross a threshold immediately. This already applies to every existing delta timer and is acceptable for these non-critical debounce timers. → No mitigation needed.
