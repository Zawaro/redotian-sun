## 1. EntityData Cleanup

- [x] 1.1 Add `refinery: bool = false` field to EntityData.gd (after dock_unload field)
- [x] 1.2 Update gdi_refinery.tres to set `refinery = true`

## 2. DockHostComponent — Stale Client Eviction

- [x] 2.1 Add `stale_timeout: float = 5.0` export to DockHostComponent.gd
- [x] 2.2 Add `signal dock_timeout(docker: Node)` to DockHostComponent.gd
- [x] 2.3 Add `_stale_timer: float = 0.0` private variable
- [x] 2.4 Implement stale detection in `_process()`: reset timer on docker_docked, increment when current_docker active, evict when exceeds stale_timeout
- [x] 2.5 On stale eviction: call `leave_dock()`, emit `dock_timeout(docker)`

## 3. DockClientComponent — Simplify to Thin Client

- [x] 3.1 Remove timeout variables: `_refinery_timeout`, `_docking_timeout`, `_queued_timeout`, `_retry_cooldown`, `_recheck_timer`
- [x] 3.2 Remove constants: `DOCK_TIMEOUT`, `RETRY_COOLDOWN`, `RECHECK_INTERVAL`
- [x] 3.3 Remove `_find_shorter_queue()` method
- [x] 3.4 Simplify `_process()` to only handle retry cooldown (keep `_retry_cooldown` for pathfinding failure retry)
- [x] 3.5 Simplify `seek_dock()`: remove timeout setup, remove queue fallback logic
- [x] 3.6 Simplify `_on_arrived()`: remove timeout handling
- [x] 3.7 Simplify `_cancel_dock()`: remove timeout references
- [x] 3.8 Simplify `reserve_at()`: remove timeout references
- [x] 3.9 Simplify `_on_dock_cancelled` path in `seek_dock()`: remove timeout setup
- [x] 3.10 Simplify queue recheck path in `_process()`: remove recheck logic, keep only timeout handling for _queued_host
- [x] 3.11 Add `on_dock_timeout()` handler: clear state, emit `dock_cancelled`

## 4. DockUnloadComponent — Cargo Validation

- [x] 4.1 Add `accepted_resource_categories: PackedStringArray = []` export to DockUnloadComponent.gd
- [x] 4.2 Add `_entity_data: EntityData` private variable
- [x] 4.3 Update `configure(data: EntityData)` to store entity data and copy accepted_resource_categories from EntityData
- [x] 4.4 Add cargo validation in `_process()`: check each cargo type's category against accepted_resource_categories before unloading (empty = accept all)
- [x] 4.5 On validation failure: call `dock.leave_dock(docker_node)` immediately

## 5. EntityFactory — Wire Refinery Flag

- [x] 5.1 Update `_add_dock_unload_component()` to pass accepted_resource_categories from EntityData to DockUnloadComponent
- [x] 5.2 Verify refinery flag is set on building entity data resources

## 6. Comprehensive Unit Tests

- [x] 6.1 Rewrite test_dock_host_component.gd: test stale client eviction with mock timer
- [x] 6.2 Add test_dock_host_component.gd: test dock_timeout signal emission
- [x] 6.3 Add test_dock_host_component.gd: test leave_dock promotes next and re-reserves cell
- [x] 6.4 Rewrite test_dock_client_component.gd: test thin client behavior (no timeout management)
- [x] 6.5 Add test_dock_client_component.gd: test on_dock_timeout handler clears state
- [x] 6.6 Update test_harvest_dock.gd: remove timeout-related test setup
- [x] 6.7 Add test_harvest_dock.gd: test cargo validation rejects unaccepted categories
- [x] 6.8 Add test_harvest_dock.gd: test full dock cycle with stale eviction
- [x] 6.9 Run full test suite and fix any failures

## 7. Follow-up Hardening (review-driven)

- [x] 7.1 Fix synchronous recursion in HarvestComponent delivery (schedule `DELIVER_RETRY`, don't re-seek in callstack)
- [x] 7.2 `set_target_refinery` enters `DELIVERING` so player-ordered docks resume the loop
- [x] 7.3 Add `DockClientComponent.cancel()`; route `cancel_harvest` through it (full reset from any sub-state)
- [x] 7.4 `_begin_unload` validates host before `UNLOADING`; `on_dock_undocked` clears `_queued_host`; MOVING retry uses `is_instance_valid`
- [x] 7.5 Reset stale timer on arrival (`reset_stale_timer` from client) so long approaches aren't evicted
- [x] 7.6 Add `HIBERNATE` state — exhausted+empty harvester re-scans on `HIBERNATE_INTERVAL`; `IDLE` reserved for player stop
- [x] 7.7 Add dock-unblock — hibernating harvester steps off the dock cell to a free wait cell
- [x] 7.8 Remove dead code: `refinery` flag, `refinery_storage`, `on_dock_timeout` + `dock_slot_reserved`, `State.SEEKING`, `RETRY_COOLDOWN`, debug prints, always-null transport lookup
- [x] 7.9 Remove `max_queue_length` cap (unbounded queue; occupancy penalty handles load-balancing)
- [x] 7.10 Add tests: cancel from queued/reserved, hibernate entry + timer, player-ordered DELIVERING, recursion-safe retry; run full suite (180 passing)

> Note: tasks 1.1/1.2 (add `refinery` flag) and 3.11 (`on_dock_timeout` handler) were completed then reverted in section 7 as dead code.
