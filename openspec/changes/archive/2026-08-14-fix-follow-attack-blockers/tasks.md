## 1. Chase leg invalidation (D1, D2)

- [x] 1.1 Add `_chase_leg_enemy_cell: Vector2i`, `_last_chase_replan_time: float`, `_chase_retry_after: float`, `_logged_unreachable: Node3D` to CombatComponent, plus constants `CHASE_REPLAN_MIN_INTERVAL` (0.15s) and `CHASE_RETRY_BACKOFF` (0.5s)
- [x] 1.2 Record `_chase_leg_enemy_cell` and `_last_chase_replan_time` at combat-move issue time in `_move_toward_target`
- [x] 1.3 Replace the `is_moving()` gate in `_move_toward_target` with `_should_replan()`: stale when the target's cell differs from `_chase_leg_enemy_cell`, throttle elapsed, and target out of range (out-of-range gate lives in `_physics_process`)
- [x] 1.4 Ensure a stationary target produces zero re-plans (cell unchanged → old behavior preserved)

## 2. Passable destination invariant (D3)

- [x] 2.1 In the ground (non-jumpjet) branch of `_move_toward_target`, clamp `stop_pos` through `MovementController.find_nearest_free_cell()` (returns the cell unchanged when passable) so the destination is never blocked before the move is issued
- [x] 2.2 Verify the jumpjet branch's existing range-circle clamp is untouched

## 3. State-machine hardening (D4, D5, D6)

- [x] 3.1 Change the gate to a `_should_replan()` predicate — false only for real MOVING/ROTATING legs; WAIT is replan-eligible (via `MovementController.is_waiting()`), and re-plans only fire when the target is out of range (`_physics_process`)
- [x] 3.2 In `_on_pathfinding_failed`, set `_chase_retry_after = now + CHASE_RETRY_BACKOFF`; `_should_replan()` skips approach attempts until it lapses; fire in place while in range; log once per target
- [x] 3.3 Confirm `_combat_move`/target preservation holds across re-plans WITHOUT `internal = true` — the existing flag is set before each combat move and consumed by that move's `movement_started`, so re-plans preserve the target (see design.md D6 decision)

## 4. Tests

- [x] 4.1 Regression: building cell registered; attacker chases a live target behind it → re-plan fires and no chase path waypoint enters the building cell
- [x] 4.2 Positive: stationary target → exactly one move issued, no re-plans (assert no extra `set_target_position`/`find_path` calls)
- [x] 4.3 Boundary: target jitter within throttle interval → at most one re-plan per interval; cell change beyond interval → re-plan
- [x] 4.4 Destination clamp: stop position computed on a blocked cell → move issued to a nearby passable cell
- [x] 4.5 WAIT deadlock: attacker in WAIT with target out of range → issues a new approach move; target in range → fires without re-planning
- [x] 4.6 Pathfinding failure: unreachable target → retry delayed by backoff; in-range target still fires; no per-tick A* retry
- [x] 4.7 Target preservation: re-plan during `movement_started` keeps `_target`; player move order still clears it
- [x] 4.8 Run `redot --headless -s test/run_tests.gd` until green; run `gdlint` + `gdformat --check` on changed files

## 5. Documentation

- [ ] 5.1 Archive the openspec change after merge (CI requires no open changes)
