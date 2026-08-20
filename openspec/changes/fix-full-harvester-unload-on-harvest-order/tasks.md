## 1. Regression tests (repro-first)

- [x] 1.1 Add TS-lock test to `test/unit/test_harvest_dock.gd`: a full harvester given a harvest order enters SEEK_NODE (walks to the field), and on arrival routes to DELIVERING (dock) — asserting the TS-authentic walk-to-field-then-unload behavior is preserved
- [x] 1.2 Add strand-repro test to `test/unit/test_harvest_dock.gd`: a full harvester in DELIVERING whose `seek_dock` cannot engage (dock client non-IDLE or retry cooldown) SHALL schedule a dock retry and reach the refinery instead of stopping idle — assert it fails on current code before the fix
- [x] 1.3 Run `redot --headless -s test/run_tests.gd` and confirm the strand-repro test fails for the intended reason (harvester strands)

## 2. Production fix

- [x] 2.1 Change `DockClientComponent.seek_dock()` return type to `bool`; return `true` when it engages (enters MOVING or QUEUED), `false` on the busy guard, retry-cooldown guard, and no-host-found paths
- [x] 2.2 Update `HarvestComponent._deliver_cargo()`: when `seek_dock()` returns false, set `_deliver_retry = DELIVER_RETRY` so the DELIVERING retry branch re-seeks
- [x] 2.3 Apply the same retry safety net in `HarvestComponent.set_target_refinery()` for player-ordered docks

## 3. Spec sync

- [x] 3.1 Correct the `resource-harvesting` spec "Full cargo" scenario (HARVEST cursor + walk-to-field, not ENTER/direct-to-refinery) in `openspec/changes/fix-full-harvester-unload-on-harvest-order/specs/resource-harvesting/spec.md` if it drifted from proposal

## 4. Verification

- [x] 4.1 Run full test suite: `redot --headless -s test/run_tests.gd` — all green, including new 1.1/1.2 tests and existing `test_dock_client_component`/`test_dock_queue_step` suites
- [x] 4.2 Run `gdlint scripts/components/HarvestComponent.gd scripts/components/DockClientComponent.gd test/unit/test_harvest_dock.gd` and `gdformat --check` on touched files
- [x] 4.3 Run `grep -P '\t'` on touched `.gd` files to confirm no tabs were introduced
- [x] 4.4 `openspec validate` the change

## 5. In-flight dock cancel (Variant A+)

- [x] 5.1 Add regression test `test_full_harvester_harvest_order_cancels_inflight_dock` to `test/unit/test_harvest_dock.gd`: full harvester with a busy dock client (mid auto-deliver) issued a harvest order via `get_order_for_target` + execute — assert the dock client is reset to IDLE and the harvester walks to the field, then re-engages the dock after arrival; assert it fails on current code
- [x] 5.2 Update the HARVEST closure in `HarvestComponent.get_order_for_target()`: when cargo is full and `dock_client` exists, call `dock_client.cancel()` before `set_target_node(target)`
- [x] 5.3 Run `redot --headless -s test/run_tests.gd` — all green
- [x] 5.4 Re-run `gdlint` + `gdformat --check` + tab check on touched files, then `openspec validate`

## 6. MouseHandler fall-through fix (root cause)

- [x] 6.1 Add regression test upgrade to `test_full_harvester_harvest_order_cancels_inflight_dock`: mount harvester + refinery in the real scene tree (`_pm.get_tree().root.add_child`) so `find_nearest_host`'s group scan runs — assert the dock re-engages MOVING toward the refinery after the walk (full walk→deliver chain), not just DELIVERING state
- [x] 6.2 Fix `MouseHandler._handle_left_click_normal` pass 2 (interact hitboxes): `return` when `_try_execute_orders` issued an order, so a harvest/dock click does NOT fall through to the "no entity → move" block which issues a MOVE order that calls `cancel_harvest()` and strands the full harvester
- [x] 6.3 Remove temporary `[HARV]`/`[DOCK]` debug prints from `HarvestComponent.gd` / `DockClientComponent.gd`
- [x] 6.4 Run `redot --headless -s test/run_tests.gd` — all green
- [x] 6.5 Re-run `gdlint` + `gdformat --check` + tab check on touched files, then `openspec validate`
