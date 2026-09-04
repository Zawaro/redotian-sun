## 1. rotation_speed rewire

- [x] 1.1 `MovementController.configure()` adopts `data.rotation_speed`; scene export stays as fallback
- [x] 1.2 Regression test: two units with distinct `rotation_speed` values slew the same arc in proportionally distinct times

## 2. face_toward API on MovementController

- [x] 2.1 Implement `face_toward(target_pos, delta) -> bool` (XZ yaw, `angle_difference` step at `rotation_speed`, `_apply_facing`, `instant_turn` snap, `rotation_angle_threshold` tolerance, no waypoints/signals)
- [x] 2.2 Unit test: instant-turn unit snaps and returns true same call
- [x] 2.3 Unit test: Track unit slews at configured rate, returns false until within tolerance, emits no `movement_started`

## 3. Combat fire gate

- [x] 3.1 `CombatComponent._physics_process` in-range branch: skip `face_toward` during live `MOVING`/`ROTATING` leg; skip gate when no MC sibling; distance deadzone (`CELL_SIZE`) fires regardless; else hold fire until aligned
- [x] 3.2 Regression test: stationary vehicle holds fire out-of-arc, yaws, fires once aligned (yaw within tolerance at fire time)
- [x] 3.3 Regression test: stationary infantry snaps and fires same tick; building fires with no MC and no rotation
- [x] 3.4 Regression test: close-range target (inside `CELL_SIZE`) fires without turning; vertical separation does not affect yaw

## 4. Verify and close

- [x] 4.1 `redot --headless -s test/run_tests.gd` green; `gdlint` / `gdformat --check` clean; no tabs in edited files
- [x] 4.2 File follow-up issues: vehicle turret yaw + pivot convention (multi-turret deferred), `deploy_to_fire` / `no_moving_fire` enforcement
