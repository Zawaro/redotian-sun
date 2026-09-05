## 1. Data & Foundation

- [x] 1.1 Add `pip_color: Color` export (default white, `##` doc comment) to `scripts/data/EntityData.gd`
- [x] 1.2 Add `unload_interval: float` field to `scripts/data/GlobalRules.gd` (sensible TS-like default) and wire into `resources/global_rules.tres`
- [x] 1.3 Create `scripts/components/PassengerComponent.gd` — `configure(data)` captures `pip_color`; `get_cursor_for_target`/`get_order_for_target` return ENTER (priority 10) only for friendly, stationary transports with free seats; order lambda issues a plain move order to the transport's cell
- [x] 1.4 Update `EntityFactory._add_components` to attach PassengerComponent when `entity_type == INFANTRY` and update entity validation if component list validation applies
- [x] 1.5 Add GLOSSARY.md rows: `load`/`unload` (TS terms) and `pip_color`

## 2. Boarding

- [x] 2.1 Add passenger storage to TransportComponent: `Array[Node3D]` passengers + parallel `Array[Color]` pip colors; `board(node)` detaches the node, records color, calls `add_passenger()`, removes node from SelectionManager first
- [x] 2.2 Implement arrival-board check: when the ordered infantry finishes its move, board only if the transport is still valid, friendly, stationary, and has a free seat; otherwise idle
- [x] 2.3 Delete the transport→transport ENTER stub from TransportComponent (`get_cursor_for_target`/`get_order_for_target`)
- [x] 2.4 Unit tests: ENTER cursor/order gating (stationary/moving/full/enemy/self), no-queue multi-infantry boarding with overflow idling, detach removes node from `entities`/`selectable`/`drag_selectable` groups, stale-selection cleanup on board, passenger state (health/veterancy) preserved across ride

## 3. Unload

- [x] 3.1 Add `can_unload()` to TransportComponent: has passengers, MovementController not moving, `TerrainSystem.get_land_type` on transport cell is not water
- [x] 3.2 Add self-hover DEPLOY cursor + click order to TransportComponent (priority 15, DeployComponent pattern) gated on `can_unload()`
- [x] 3.3 Extend MouseHandler deploy-hotkey path to call `execute_unload()` on selected transports
- [x] 3.4 Implement sequential eject in TransportComponent `_physics_process`: accumulator timer, one passenger per `GlobalRules.unload_interval`, re-add at nearest free land cell with sub-slot assignment
- [x] 3.5 Implement interrupts: move-order detection via `MovementController.is_moving()` poll and stop-command hook cancelling the eject sequence
- [x] 3.6 Unit + integration tests: hotkey and hover-self unload starts, DEPLOY cursor hidden while moving/on water, one-per-interval pacing (known-example timing), move/stop interrupts retain remaining passengers, ejected passenger restores at free land cell with state intact

## 4. Death Eject

- [x] 4.1 Connect TransportComponent to HealthComponent `health_zero`: re-add all held passengers at nearest free land cells (fallback: transport's own cell) before teardown; `_exit_tree` backstop releases any still-held nodes
- [x] 4.2 Unit tests: death eject spawns all passengers at valid land cells with state intact, no free cell falls back to transport cell, `_exit_tree` with held nodes does not leak or crash

## 5. Seat Pips

- [x] 5.1 Extend `SelectionOverlay._make_pip` with an optional color field; `_gather_pips` fills passenger pips with per-seat colors from TransportComponent's parallel color array; `_draw_pips` uses per-pip color with white fallback
- [x] 5.2 Unit tests: mixed-color passengers draw per-passenger colors, unset `pip_color` falls back white, partial load shows filled + unfilled seats, harvester cargo pips unchanged

## 6. Verification & Lint

- [x] 6.1 Run full suite: `redot --headless -s test/run_tests.gd`
- [x] 6.2 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`; fix findings; check for tab introduction in multi-line strings after gdformat
- [x] 6.3 Verify existing suites still pass: test_transport_cargo.gd (update expectations only where the deleted ENTER stub was the subject), test_harvest_dock.gd, test_stop_command equivalents
