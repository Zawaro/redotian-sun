## 1. DockHostComponent

- [x] 1.1 Rename exported `dock_wait_ticks: int = 10` to `dock_wait_seconds: float = 0.2`; update its doc comment and remove the stale ponytail note about frame-based timing.
- [x] 1.2 Rename `_wait_counter: int` to `_wait_seconds: float`; update its doc comment.
- [x] 1.3 In `_process`, accumulate `_wait_seconds += delta` and compare against `dock_wait_seconds`; reset to `0.0` on promotion and at the other reset sites (`request_dock`, `_clear_queue`).

## 2. MovementController

- [x] 2.1 Rename `_repair_frames: int` to `_repair_time: float`; add a `REPAIR_INTERVAL` seconds constant derived from the old 10-frame value.
- [x] 2.2 In `_handle_moving_movement`, accumulate `_repair_time += delta` and fire the waypoint re-check when it reaches `REPAIR_INTERVAL`, resetting to `0.0`.
- [x] 2.3 Rename `_wait_frames: int` to `_wait_time: float` and reinterpret `_wait_threshold` as seconds; set `_wait_threshold` in `_ready` from the old 10–25 frame range converted to seconds.
- [x] 2.4 Give `_handle_wait` a `delta` parameter (passed from the `State.WAIT` branch of `_physics_process`); accumulate `_wait_time += delta`, fire the mid-wait scatter once on the tick that crosses its threshold, and reroute when `_wait_time` exceeds `_wait_threshold`.
- [x] 2.5 Reset `_wait_time` and `_repair_time` to `0.0` at the `set_target_position` reset site.

## 3. Tests

- [x] 3.1 Update `test/unit/test_dock_host_component.gd` and `test/unit/test_dock_queue_step.gd` to use `dock_wait_seconds` / `_wait_seconds` (map existing step counts to matching seconds thresholds).
- [x] 3.2 Add a delta-scaling assertion proving dock promotion depends on accumulated seconds, not tick count (small deltas below threshold do not promote; a delta at/above threshold does).

## 4. Quality gate

- [x] 4.1 `gdformat` + `gdformat --check` clean; no tabs in multiline strings.
- [x] 4.2 `gdlint` clean.
- [x] 4.3 Headless test suite passes with 0 failures.
