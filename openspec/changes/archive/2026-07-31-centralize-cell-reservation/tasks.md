## 1. CellReservation autoload

- [x] 1.1 Create `scripts/core/CellReservation.gd` as a Node autoload; register it in `project.godot` (mirror SpatialHash entry); reuse `CellSubPositions.NUM_SLOTS`
- [x] 1.2 Implement the in-flight claim registry: `_claims: Dictionary` keyed by `cell_key`, each entry a 3-element owner array; API `reserve_sub_slot(cell, owner) -> int`, `release_sub_slot(cell, owner)`, `get_available_sub_slot(cell) -> int`, `get_owner(cell, slot)`, `is_cell_full(cell)`, `release_all(owner)`
- [x] 1.3 Idempotent same-cell retention: re-reserve of the same cell/owner returns the existing claim; reserve of a different cell releases the prior claim first
- [x] 1.4 Combined capacity: `is_cell_full(cell)` sums `SpatialHash.get_infantry_count(cell)` (physical idle) + in-flight claims on the cell
- [x] 1.5 Cleanup: connect `owner.tree_exited` once per owner → `release_all(owner)`; prune `!is_instance_valid` owners on every read
- [x] 1.6 Follow repo conventions: class_name + doc comments, typed hints, 4-space indent; gdformat clean

## 2. MovementController integration

- [x] 2.1 Rewrite `_assign_sub_slot_at_cell`: taken slots from (a) grid entries' `_assigned_slot` (no `_has_sub_slot` gate) and (b) `CellReservation` claims; set `_assigned_slot`/`_sub_slot_position`/`_has_sub_slot` from the reserve result
- [x] 2.2 Call reserve inside `set_target_position` (single path covers selection + combat); keep `_has_sub_slot`/`_assigned_slot` as the local claim cache only
- [x] 2.3 Spread fallback: when reserve returns -1, use `_find_nearest_free_cell(target_cell)` and re-claim there instead of settling at cell center
- [x] 2.4 Release on arrival and on `_finish_stop`; verify against `stop()` infantry branch (re-assigns sub-slot at current cell)
- [x] 2.5 Scope combined capacity to infantry: confirm vehicle paths in `_is_cell_occupied_by_idle`/`_build_blocked_cells` stay purely physical

## 3. SelectionManager refactor

- [x] 3.1 Remove `cell_occupancy` dict and `mc._assigned_slot = slot` write from `request_move`
- [x] 3.2 Update `_find_infantry_cell` to use `CellReservation.is_cell_full` (combined capacity) instead of `get_infantry_count` + local occupancy
- [x] 3.3 Confirm `_execute_move` needs no change (claim happens inside `set_target_position`)

## 4. EntityPlacer + ExitComponent delegation

- [x] 4.1 `EntityPlacer.place_entity`: replace the taken-slots loop with `CellReservation.reserve_sub_slot(cell, entity)`; set MC fields + position from the returned slot
- [x] 4.2 `ExitComponent._start_exit`: replace `mc._has_sub_slot = false` with a defensive `CellReservation.release_all(unit)` (no-op for fresh spawns)

## 5. Tests

- [x] 5.1 New `test/unit/test_cell_reservation.gd`: reserve/available/full/release, lowest-free-slot, idempotent same-cell, re-reserve releases prior, combined capacity (physical + claims), `tree_exited` cleanup, stale-owner pruning
- [x] 5.2 Movement tests: idle keeps slot visible (later arrival gets a different slot — the regression that fails on current code), full-cell spread fallback, arrival release, mid-path stop release, deterministic 0,1,2 in batch order, concurrent-orders spread
- [x] 5.3 Update selection-manager tests asserting `_assigned_slot` pre-assignment and `get_infantry_count`-based capacity
- [x] 5.4 Run `redot --headless -s test/run_tests.gd`; then `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check`; verify no tabs (`grep -P '\t' scripts/**/*.gd test/**/*.gd`)
