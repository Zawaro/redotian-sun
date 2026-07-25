## Context

`MouseHandler._handle_left_click_normal()` contains hardcoded order dispatch: sell mode check, repair mode check, `_try_interact()` for harvest/dock, deploy check, selection, and movement fallback. Each new order type requires adding another branch. Cursor resolution is already component-driven via `get_cursor_for_target()`, but order execution is not — creating a split where cursor and order can disagree.

`SelectionManager` holds `request_move()`, `request_harvest()`, `request_dock()`, `request_deploy()`, each manually iterating `selected_entities` and calling component methods directly. This couples selection management with order execution.

The goal is to unify cursor resolution and order creation into a single trait-declared system: components declare what they can do (cursor + order), a resolver picks the winner, and MouseHandler delegates to it.

## Goals / Non-Goals

**Goals:**
- Components declare both cursor AND order via a single `get_order_for_target()` method
- Central `OrderResolver` returns per-entity orders (one OrderResult per matching entity) for execution, and a single best result for cursor display
- `OrderGenerator` hierarchy allows mode-specific behavior (normal, sell, repair)
- `OrderSystem` autoload holds active generator, delegates from MouseHandler
- Modifier support: Ctrl (force attack), Alt (force move), Shift (queue) with typed constants
- Backward-compatible: existing cursor behavior preserved, order execution moves to components

**Non-Goals:**
- Network/multiplayer order serialization (no Order packets, no server validation)
- Order queuing UI (Shift sets `queued` flag, but visual queue display is separate)
- Attack-move, guard, patrol commands (future components, same pattern)
- Right-click orders (right-click stays deselect/cancel only)
- Animated cursor sprites (placeholder SVGs remain)

## Decisions

### 1. Single method returns both cursor and order

**Choice**: Components return `OrderResult` containing cursor type, priority, and execute callback — not separate `get_cursor_for_target()` and `get_order_for_target()` methods.

**Rationale**: Cursor and order are inseparable — if a component says "I can attack this target," it must also provide the attack cursor AND the attack execution. Separate methods risk drifting (cursor says ATTACK, order does nothing). One return value enforces consistency.

**Alternatives considered**:
- Two separate methods (`get_cursor_for_target()` + `get_order_for_target()`): rejected — double iteration, risk of cursor/order mismatch
- Interface with `can_target()` + `get_cursor()` + `issue_order()`: rejected — three methods per component, more boilerplate for no benefit

### 2. OrderGenerator replaces hardcoded mode logic

**Choice**: Separate `OrderGenerator` subclasses for each mode (Unit, Sell, Repair). `OrderSystem` holds the active generator and delegates. MouseHandler never checks sell/repair mode directly.

**Rationale**: Sell and repair are global modes that override normal cursor/order behavior. Each mode has its own cursor logic (sell shows SELL on buildings, SELL_BLOCKED elsewhere) and order logic (sell issues sell order, repair issues repair order). Separate classes keep this clean — adding a new mode (e.g., waypoints) means adding a new generator, not modifying MouseHandler.

**Alternatives considered**:
- Flag on UnitOrderGenerator (`is_sell_mode`): rejected — mixes unrelated concerns, every method needs flag checks
- Mode enum on OrderSystem: rejected — same problem, just moved to a different file

### 3. Static OrderResolver with dual API

**Choice**: `OrderResolver` provides two static methods: `resolve_all()` returns `Array[OrderResult]` (one per matching entity, for order execution) and `resolve_single()` returns a single `OrderResult` (highest priority across all, for cursor display).

**Rationale**: Order execution needs per-entity results (all 3 tanks must attack). Cursor display needs only the winner (one cursor shown). Two methods serve both use cases without redundant allocation.

**Alternatives considered**:
- Single `resolve()` returning one result: rejected — breaks multi-unit orders
- Always returning full array and letting caller pick: rejected — cursor path would discard N-1 results every frame

### 4. Callable execute callback bound to entity

**Choice**: `OrderResult.execute` is a `Callable` closure that captures the component's parent node. When called, it operates on the specific entity instance.

**Rationale**: Components know how to execute their own orders on their own entity. The closure captures `get_parent()` at creation time, so execute.call() always operates on the correct entity. This avoids passing entity references through the resolver and prevents "execute on wrong entity" bugs.

**Alternatives considered**:
- Order ID string + central dispatch table: rejected — recreates the hardcoded switch statement we're trying to eliminate
- Component method name string + `call()`: rejected — fragile, no type safety
- Entity reference field on OrderResult: rejected — redundant with closure binding

### 5. SelectionManager keeps selection only

**Choice**: `request_move()`, `request_harvest()`, `request_dock()`, `request_deploy()` are removed from SelectionManager. It retains `selected_entities`, `select_entity()`, `deselect_all()`, and hover preview.

**Rationale**: SelectionManager should manage selection state, not order execution. Moving order logic to component execute callbacks means SelectionManager stays focused and small. The batch move processing (`_pending_moves`) moves to MovementController's execute callback.

### 6. Modifier constants prevent typos

**Choice**: Modifiers passed as `Dictionary` with string keys defined as constants on `OrderResult`: `MOD_FORCE_ATTACK`, `MOD_FORCE_MOVE`, `MOD_QUEUED`.

**Rationale**: Dictionary is extensible — adding a new modifier doesn't change the method signature. Constants prevent key typos (e.g., `"forceAttack"` vs `"force_attack"`) from causing silent failures. Components read the constants, not raw strings.

## Risks / Trade-offs

- **Existing tests reference SelectionManager.request_* methods** → Tests that call `request_move()`, `request_harvest()`, etc. need updating to use the new order flow. Mitigation: update tests in the same PR, verify all pass before merge.

- **Batch move processing migration** → `_pending_moves` and `_execute_move()` move from SelectionManager to MovementController. This is a significant code move. Mitigation: move as a block, don't rewrite — just change the entry point.

- **Sidebar sell/repair wiring** → Sidebar currently calls `sidebar.is_sell_mode()` / `sidebar.is_repair_mode()` checks. These become `OrderSystem.set_generator()` calls. Mitigation: Sidebar's `enter_action_mode()` / `exit_action_mode()` methods handle the generator swap.

- **Deploy-on-click bypasses SelectionManager** → Currently, clicking an already-selected deployable entity calls `deploy.execute_deploy()` directly in MouseHandler. This becomes a normal OrderResult from DeployComponent. Mitigation: DeployComponent's `get_order_for_target()` handles the "click self to deploy" case.

- **Transition period** → During migration, both `get_cursor_for_target()` and `get_order_for_target()` coexist on components. The old cursor path remains functional until full migration is verified. Old methods are removed in a final cleanup task.
