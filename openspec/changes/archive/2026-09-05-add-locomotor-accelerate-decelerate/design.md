# Design: Speed Ramp

## Approach: Closed-Form Braking Envelope

Speed is computed as `v = min(accel_ramp, braking_envelope)` where the braking envelope is the closed-form `sqrt(2 × decel_rate × remaining_path_distance)` floored at a crawl fraction of cruise speed. This makes Zeno creep and overshoot structurally impossible; short moves collapse to a triangular profile. The existing `approach_step` limit-length branch at arrival stays the exact-landing snap.

**Key fix:** The ramp now targets `move_speed` directly (not the full product). All per-unit factors (`_vertical_split_factor()`, `_veteran_speed_mult`, `_slope_coefficient()`, `_terrain_speed_factor()`) multiply on top via the step chain — just like `_speed_jitter` and `speed_factor` (neighbor slowdown). This avoids double-counting and simplifies the math.

## State & Reset Edges

- **Stored scalar:** `_ramp_speed: float` in MovementController
- **Reset only in:** `_finish_stop()` and both arrival-to-IDLE blocks (lines 944 and 1025)
- **Carry-forward default:** `set_target_position` stays untouched — re-targets (internal or player) automatically carry
- **Frozen during:** ROTATING (accel doesn't advance) and WAIT (freeze frame)
- **Decel-only init:** When `decelerate=true` and `accelerate=false` (TS semantics: no Accelerate = immediate cruise), `_ramp_speed` starts at `move_speed` on fresh moves; when `accelerate=true` (regardless of decelerate), it starts at 0

## Floor Application

Crawl floor (`ramp_crawl_fraction ≈ 15%`) applies **only while the braking envelope is the limiting term** (`decel_limit < move_speed`). This lets fresh accel moves start from 0, while still preventing Zeno creep near arrival where the envelope would otherwise asymptote.

## Constants (GlobalRules)

- `ramp_accel_time ≈ 0.75s` (time to reach full speed from 0)
- `ramp_decel_time ≈ 0.5s` (time to crawl from full speed)
- `ramp_crawl_fraction ≈ 0.15` (15% of cruise speed as floor)

## Test Strategy (Behavior-Not-Implementation)

1. **Monotone rise:** per-frame displacement increases toward target when accelerating
2. **Anti-Zeno bound:** `arrived` emitted within ⌈path_length/crawl_speed⌉ + K ticks
3. **Triangular peak:** short moves peak at `L·decel/(accel+decel)` derived independently
4. **No-regression:** default-off locomotors produce bit-identical displacement
5. **Carry-across-retarget:** internal re-target mid-move preserves ramped speed
6. **Exact landing:** final position equals target sub-slot within 0.001
