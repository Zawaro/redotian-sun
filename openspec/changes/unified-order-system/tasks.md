## 1. Core Types

- [x] 1.1 Create `scripts/orders/OrderResult.gd` — class with cursor, priority, target, target_pos, queued, execute fields; modifier constants (MOD_FORCE_ATTACK, MOD_FORCE_MOVE, MOD_QUEUED); execute is a Callable bound to entity instance
- [x] 1.2 Create `scripts/orders/OrderResolver.gd` — static `resolve_all()` returns Array[OrderResult] (one per matching entity), `resolve_single()` returns one best result (for cursor); uses has_method("get_order_for_target") to detect targeter-capable components; tie-breaking by entity index then child index
- [x] 1.3 Create `scripts/orders/OrderGenerator.gd` — base class with virtual `get_cursor()`, `get_orders()`, `cancel()` methods; accesses selection via SelectionManager autoload

## 2. Order Generators

- [x] 2.1 Create `scripts/orders/UnitOrderGenerator.gd` — extends OrderGenerator, stateless singleton, delegates to OrderResolver using SelectionManager.selected_entities
- [x] 2.2 Create `scripts/orders/SellOrderGenerator.gd` — extends OrderGenerator, SELL cursor on sellable buildings (FoundationComponent + not under construction + no active production), sell execute callback
- [x] 2.3 Create `scripts/orders/RepairOrderGenerator.gd` — extends OrderGenerator, REPAIR cursor on damaged buildings, repair execute callback

## 3. OrderSystem Autoload

- [x] 3.1 Create `scripts/core/OrderSystem.gd` — autoload with active_generator, get_cursor(), get_orders(), set_generator(), cancel() (reuses UnitOrderGenerator singleton)
- [x] 3.2 Register OrderSystem in `project.godot` autoload section

## 4. Component Targeters

- [x] 4.1 Add `get_order_for_target()` to MovementController — MOVE order for terrain, priority 5
- [x] 4.2 Add `get_order_for_target()` to CombatComponent — ATTACK order for enemy actors, priority 30, respects force_attack modifier
- [x] 4.3 Add `get_order_for_target()` to HarvestComponent — HARVEST for resources (priority 20), ENTER for dock hosts (priority 15); harvesters do not have CombatComponent
- [x] 4.4 Add `get_order_for_target()` to TransportComponent — ENTER for friendly transports, priority 10
- [x] 4.5 Add `get_order_for_target()` to DeployComponent — DEPLOY for self (priority 15), MOVE for undeploy to terrain; undeploy callback computes own offset from selection center at execution time

## 5. MouseHandler Refactor

- [x] 5.1 Delegate `_update_cursor()` to `OrderSystem.get_cursor()` — replace `_resolve_cursor_for_selection()` with OrderSystem call
- [x] 5.2 Delegate `_handle_left_click_normal()` to `OrderSystem.get_orders()` — iterate results and call execute.call() on each
- [x] 5.3 Remove `_try_interact()` from MouseHandler — harvest/dock now handled by component targeters
- [x] 5.4 Remove hardcoded DeployComponent check from `_handle_left_click_normal()` — deploy handled by component targeter
- [x] 5.5 Remove hardcoded sell/repair mode checks from `_handle_left_click_normal()` — delegated to SellOrderGenerator/RepairOrderGenerator
- [x] 5.6 Pass modifiers Dictionary from MouseHandler to OrderSystem — use OrderResult constants (MOD_FORCE_ATTACK, MOD_FORCE_MOVE, MOD_QUEUED)

## 6. SelectionManager Cleanup

- [x] 6.1 Remove `request_move()` from SelectionManager — movement execution moves to MovementController's OrderResult.execute callback
- [x] 6.2 Remove `request_harvest()` from SelectionManager — harvest execution moves to HarvestComponent's OrderResult.execute callback
- [x] 6.3 Remove `request_dock()` from SelectionManager — dock execution moves to HarvestComponent's OrderResult.execute callback; DockHostComponent.request_dock() stays
- [x] 6.4 Remove `request_deploy()` from SelectionManager — deploy execution moves to DeployComponent's OrderResult.execute callback
- [x] 6.5 Move batch move processing (`_pending_moves`, `_execute_move()`) to MovementController

## 7. Rally Point

- [x] 7.1 Keep `request_set_rally_point()` in SelectionManager as-is — Alt+click rally point is not part of this refactor (simple enough to remain hardcoded)

## 8. Sidebar Integration

- [x] 8.1 Wire sell mode toggle in Sidebar to `OrderSystem.set_generator(SellOrderGenerator.new())`
- [x] 8.2 Wire repair mode toggle in Sidebar to `OrderSystem.set_generator(RepairOrderGenerator.new())`
- [x] 8.3 Wire sell/repair exit to `OrderSystem.cancel()` (restores UnitOrderGenerator singleton)

## 9. Remove Old Cursor Methods

- [x] 9.1 Remove `get_cursor_for_target()` from HarvestComponent — replaced by get_order_for_target()
- [x] 9.2 Remove `get_cursor_for_target()` from DeployComponent — replaced by get_order_for_target()
- [x] 9.3 Keep `get_cursor_for_target()` on CombatComponent, TransportComponent, MovementController temporarily — remove after full migration verified; both methods coexist during transition

## 10. Tests

- [x] 10.1 Unit test: OrderResolver.resolve_all() returns one OrderResult per matching entity
- [x] 10.2 Unit test: OrderResolver.resolve_all() returns empty array when no components match
- [x] 10.3 Unit test: OrderResolver.resolve_single() returns highest priority across all entities
- [x] 10.4 Unit test: UnitOrderGenerator.get_cursor() delegates to OrderResolver.resolve_single()
- [x] 10.5 Unit test: UnitOrderGenerator.get_orders() delegates to OrderResolver.resolve_all()
- [x] 10.6 Unit test: SellOrderGenerator returns SELL on sellable buildings, SELL_BLOCKED elsewhere
- [x] 10.7 Unit test: RepairOrderGenerator returns REPAIR on damaged buildings, REPAIR_BLOCKED elsewhere
- [x] 10.8 Unit test: CombatComponent.get_order_for_target() returns ATTACK for enemies, respects force_attack
- [x] 10.9 Unit test: HarvestComponent.get_order_for_target() returns HARVEST for resources, ENTER for dock
- [x] 10.10 Unit test: DeployComponent.get_order_for_target() returns DEPLOY for self, MOVE for terrain undeploy
- [x] 10.11 Update existing tests in test_selection_manager.gd, test_harvest_dock.gd, test_deploy_component.gd, test_dock_host_component.gd — replace references to removed SelectionManager.request_* methods

## 11. Verification

- [x] 11.1 Run full test suite — all tests pass
- [ ] 11.2 Manual test: cursor changes correctly for all unit types x target combinations
- [ ] 11.3 Manual test: click orders execute correctly for multiple selected units (move, attack, harvest, dock, deploy, sell, repair)
- [ ] 11.4 Manual test: modifiers work (Ctrl = force attack, Alt = force move)
- [ ] 11.5 Manual test: sell/repair mode toggle works correctly
