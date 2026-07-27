## 1. Correctness fixes

- [x] 1.1 `ProductionManager._find_exit_cell()` returns `null` when no free cell is found (result equals the occupied center); `_spawn_unit()` warns and routes the unit to `_ready_to_spawn` instead of placing it on the factory cell.
- [x] 1.2 `BuildingManager` emits `build_mode_changed(is_active, player_id)` at both emit sites using the local player id.
- [x] 1.3 `ProductionManager._on_build_mode_changed(is_active, player_id)` unblocks only that player's queues via `clear_waiting_for_placement(player_id)`.

## 2. Performance fixes

- [x] 2.1 Sidebar: add `_grid_dirty` flag and `_queue_refresh()` that defers `_refresh_grid()` once; `_refresh_grid()` clears the flag on entry.
- [x] 2.2 Sidebar: route all refresh call sites (tab, scroll, prerequisites, production signals, debug) through `_queue_refresh()`.
- [x] 2.3 `UIUtil.find_sidebar()` memoizes the resolved node in a static var, re-walking only when the cache is not `is_instance_valid`.

## 3. Code-quality fixes

- [x] 3.1 `EntityData.get_build_time()` sources the build-speed factor from `GlobalRules.build_speed` (fallback `0.8`); remove the duplicated `const BUILD_SPEED`.
- [x] 3.2 `ProductionManager` ready-to-place entries store `{ "data", "deducted" }`; `cancel_ready_building()` refunds the tracked amount; `get_ready_buildings()` still returns `EntityData`.
- [x] 3.3 Rename `SelectionOverlay.SEGMENT_WIDTH_RATIO` to `SEGMENT_PX_PER_UNIT` and update its use site.

## 4. Tests and quality gate

- [x] 4.1 Extend `test/unit/test_production_manager.gd`: no-free-exit-cell routes to ready-to-spawn; player-scoped build-mode unblock; ready-to-place cancel refunds tracked amount.
- [x] 4.2 Run `gdformat` + `gdlint` clean; run headless test suite green (`N passed, 0 failed`).
