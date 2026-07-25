## Why

Cursor resolution and order creation are decoupled. Components declare `get_cursor_for_target()` for cursor display, but order execution is hardcoded in `MouseHandler._handle_left_click_normal()` — a chain of if/else blocks checking for sell mode, repair mode, interact targets, deploy, and movement. This makes adding new unit behaviors (attack-move, guard, patrol) require MouseHandler changes, and cursor+order behavior can drift apart. Unifying both into a single trait-declared composition system ensures components own their full order lifecycle — cursor, validation, and execution.

## What Changes

- **New `OrderResult` data class** — combines cursor type, priority, order ID, and execute callback into a single return value from components
- **New `get_order_for_target()` method on components** — each order-capable component (MovementController, CombatComponent, HarvestComponent, TransportComponent, DeployComponent) declares what orders it can issue and at what priority
- **New `OrderResolver` static class** — central resolver that iterates selected entities' components, collects OrderResults, and picks the highest-priority winner
- **New `OrderGenerator` base class + subclasses** — `UnitOrderGenerator` (normal gameplay, uses OrderResolver), `SellOrderGenerator` (sell mode), `RepairOrderGenerator` (repair mode). Each provides both cursor and order resolution.
- **New `OrderSystem` autoload** — holds the active OrderGenerator, delegates cursor and order resolution from MouseHandler
- **Refactor `MouseHandler`** — delegates cursor resolution to `OrderSystem.get_cursor()` and order creation to `OrderSystem.get_orders()`. Removes hardcoded sell/repair/deploy/interact logic.
- **Simplify `SelectionManager`** — removes `request_move()`, `request_harvest()`, `request_dock()`, `request_deploy()`. Execution moves to component `OrderResult.execute` callbacks. SelectionManager retains selection management only.
- **Modifier support** — Ctrl (force attack), Alt (force move), Shift (queue) passed as Dictionary to component targeters

## Capabilities

### New Capabilities
- `order-system`: Unified cursor + order resolution via trait-declared component targeters, OrderGenerator hierarchy, OrderSystem autoload, and modifier support

### Modified Capabilities
- `entity-components`: Components gain `get_order_for_target()` method — new interface contract for order-capable components
- `resource-harvesting`: HarvestComponent gains order targeter — returns HARVEST/ENTER orders via get_order_for_target()
- `dock-host-client`: Dock interaction moves from SelectionManager.request_dock() to HarvestComponent order targeter
- `deploy-undeploy`: Deploy order moves from MouseHandler hardcoded check to DeployComponent order targeter

## Impact

- **New files (7)**: `scripts/orders/OrderResult.gd`, `scripts/orders/OrderResolver.gd`, `scripts/orders/OrderGenerator.gd`, `scripts/orders/UnitOrderGenerator.gd`, `scripts/orders/SellOrderGenerator.gd`, `scripts/orders/RepairOrderGenerator.gd`, `scripts/core/OrderSystem.gd`
- **Modified files (8)**: `scripts/hud/MouseHandler.gd` (delegate to OrderSystem), `scripts/core/SelectionManager.gd` (remove request_* methods), `scripts/components/MovementController.gd`, `scripts/components/CombatComponent.gd`, `scripts/components/HarvestComponent.gd`, `scripts/components/TransportComponent.gd`, `scripts/components/DeployComponent.gd`, `scripts/ui/Sidebar.gd` (wire sell/repair to OrderSystem)
- **Modified**: `project.godot` — register OrderSystem autoload
- **No scene changes** — all script-level; no `.tscn` files affected
- **No breaking changes to existing tests** — current tests use SelectionManager.request_* which will be replaced, but test assertions still hold via new execution path
