## 1. Supersede the frontier

- [x] 1.1 Drop the reverse-frontier spec deltas: remove `specs/pathfinder/spec.md` and `specs/selection-manager/spec.md` from `openspec/changes/perf-279-shared-move-lines-group-path` (keep `move-line-renderer` and `select-component` deltas); confirm its `tasks.md` no longer references `compute_frontier`/`reconstruct_path`
- [x] 1.2 Delete bench leftovers `test/_bench_tmp.gd` and `test/unit/test_bench_tmp.gd`
- [x] 1.3 Delete frontier tests from `test/integration/test_pathfinder_terrain.gd` (lines ~294–397: `test_frontier_covers_many_starts`, `test_frontier_matches_per_unit_search_on_flat_terrain`, `test_frontier_unreachable_start_returns_empty`, `test_frontier_respects_passability`)
- [x] 1.4 Delete frontier tests from `test/unit/test_selection_manager.gd` (lines ~489–end: `test_sharer_only_group_uses_frontier`, mixed-selection fallback test)

## 2. Pathfinder: per-cell terrain cost cache (safe constant win)

- [x] 2.1 Add a per-call memo of cell terrain cost data (height via the 4-corner minimum, land type, bib status, blocked status) inside `find_path`; first neighbor probe of a cell fills it, later probes read the cache
- [x] 2.2 Verify `test/integration/test_pathfinder_terrain.gd` passes UNMODIFIED with the per-call cache (byte-identical output proof)
- [x] 2.3 Add a generation counter for blocked/reservation state changes; cache entries are invalidated (cleared or generation-checked) when the generation bumps
- [x] 2.4 Extend the cache to batch lifetime: SelectionManager passes one cache context through its 8-per-frame drain so all 50 units of an order share cost data
- [x] 2.5 Add a diff test asserting `find_path` output with the cache enabled equals output without it on a fixed map + blocked set

## 3. Pathfinder: greedy step primitive

- [x] 3.1 Implement `Pathfinder.try_greedy_step(from_cell, target_cell, blocked_cells, locomotor) -> Vector2i`: returns the best strictly-improving passable 8-neighbor using the same cost model as `find_path` (octile step, terrain speed multiplier, height penalty, bib penalty, per-locomotor passability, climb tolerance, `ignores_height` for fly/jumpjet), or an out-of-range stall sentinel
- [x] 3.2 Deterministic tie-break: prefer target-direction, then previous heading, so plateau cases keep moving instead of oscillating
- [x] 3.3 Unit tests: best-improving-neighbor on open terrain, stall sentinel when all neighbors worse/blocked, water skipped for foot, cliff skipped for foot (allowed for fly/jumpjet)

## 4. MovementController: greedy-first resolution

- [x] 4.1 In `set_target_position`, run bounded greedy descent (step budget, e.g. 64) via `try_greedy_step` toward the destination before `find_path`; on stall or budget exhaustion, run `find_path` from the stalled cell
- [x] 4.2 Remove `get_locomotor_data()` and the `precomputed_path` parameter from `set_target_position`; restore the plain signature
- [x] 4.3 Ensure path post-processing (sub-slot lane offset, line-of-sight collapse) still applies to both greedy and fallback results
- [x] 4.4 Regression tests: open-terrain move produces a path with no `find_path` call (observable via a call counter or stub); concave-pocket unit still escapes via A* fallback; flyer crosses height steps greedily

## 5. SelectionManager: plain dispatch

- [x] 5.1 Remove `_frontier_eligible`, `_frontier_memo`, `_frontier_path`, `_sharer_blocked_cells` and the sharer/locomotor eligibility gating in `request_move`
- [x] 5.2 Restore `_execute_move` to call `mc.set_target_position(position, false, false, false)` with no precomputed path; own the batch-lifetime terrain-cost cache context (create in `request_move`, pass through the drain)
- [x] 5.3 Verify batched dispatch (8/frame), sharer cell pre-assignment, and sub-slot behavior are unchanged; existing selection-manager tests still pass

## 6. Verification

- [x] 6.1 Run full suite: `redot --headless -s test/run_tests.gd` — all pass, no frontier references remain
- [x] 6.2 Lint + format: `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`; grep for tab introduction after format
- [x] 6.3 Profile: 50-infantry select + move order in-game — Process-time spike ≤ ~2ms/frame (greedy covers open terrain, cache trims remaining A*)
