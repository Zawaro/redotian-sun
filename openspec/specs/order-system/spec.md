## ADDED Requirements

### Requirement: OrderResult data class
The system SHALL provide an `OrderResult` class with fields: `cursor` (CursorState.Type), `priority` (int), `target` (Node3D, nullable), `target_pos` (Vector3), `queued` (bool), `execute` (Callable). The `execute` callback SHALL be a Callable bound to the specific entity instance (closure capturing the component's parent node). Modifiers SHALL be defined as constants: `MOD_FORCE_ATTACK = "force_attack"`, `MOD_FORCE_MOVE = "force_move"`, `MOD_QUEUED = "queued"`.

#### Scenario: OrderResult creation
- **WHEN** a component creates an OrderResult
- **THEN** it MUST populate cursor, priority, and execute fields

#### Scenario: OrderResult with null target
- **WHEN** the order targets terrain (no entity)
- **THEN** target SHALL be null and target_pos SHALL contain the world position

#### Scenario: Execute is bound to entity
- **WHEN** execute.call() is invoked
- **THEN** it SHALL operate on the specific entity instance whose component created the OrderResult, not on any other entity

### Requirement: Component order targeter interface
Each order-capable component SHALL implement `get_order_for_target(target: Node3D, target_cell: Vector2i, target_pos: Vector3, modifiers: Dictionary) -> OrderResult`. Returns null if the component cannot handle the target.

#### Scenario: Component can handle target
- **WHEN** a component receives a valid target it can act on
- **THEN** it SHALL return an OrderResult with cursor, priority, and execute callback

#### Scenario: Component cannot handle target
- **WHEN** a component receives a target it cannot act on
- **THEN** it SHALL return null

#### Scenario: Modifier force_attack
- **WHEN** modifiers contains `force_attack: true`
- **THEN** CombatComponent SHALL be able to target allies and terrain

#### Scenario: Modifier force_move
- **WHEN** modifiers contains `force_move: true`
- **THEN** MovementController SHALL return a MOVE OrderResult even when CombatComponent would otherwise match (ALT+click ground near enemies)

#### Scenario: Modifier queued
- **WHEN** modifiers contains `queued: true`
- **THEN** the returned OrderResult SHALL have `queued = true`

### Requirement: OrderResolver returns per-entity orders
The `OrderResolver.resolve_all()` static method SHALL iterate all selected entities' components, collect one OrderResult per entity (the highest-priority from that entity's components), and return `Array[OrderResult]`. Priority convention: higher numeric value = higher priority (e.g., 20 > 10). The `OrderResolver.resolve_single()` static method SHALL return only the single highest-priority OrderResult across all entities (used for cursor resolution).

#### Scenario: Mixed selection, all entities match
- **WHEN** 3 tanks are selected and cursor is over an enemy
- **THEN** resolve_all() SHALL return 3 OrderResults, one per tank

#### Scenario: Mixed selection, partial match
- **WHEN** 2 tanks and 1 harvester are selected and cursor is over an enemy
- **THEN** resolve_all() SHALL return 2 ATTACK OrderResults (tanks) and 0 for harvester (no CombatComponent)

#### Scenario: No matching components
- **WHEN** no selected entity has a component that can handle the target
- **THEN** resolve_all() SHALL return an empty array

#### Scenario: Cursor uses single result
- **WHEN** resolve_single() is called for cursor resolution
- **THEN** it SHALL return the single highest-priority OrderResult across all entities, or null

#### Scenario: Tie-breaking
- **WHEN** two components return the same priority
- **THEN** the one with the earlier entity index in selected_entities wins (entity order is deterministic based on selection order)

### Requirement: OrderResolver uses has_method check
The OrderResolver SHALL use `has_method("get_order_for_target")` to detect targeter-capable components before calling the method.

#### Scenario: Component without targeter
- **WHEN** a selected entity has a component that does not implement get_order_for_target()
- **THEN** OrderResolver SHALL skip it without error

### Requirement: OrderSystem autoload
`OrderSystem` SHALL be an autoload singleton that holds the active `OrderGenerator`. It SHALL expose `get_cursor()`, `get_orders()`, `set_generator()`, and `cancel()`. UnitOrderGenerator SHALL be a stateless singleton reused across cancel() calls.

#### Scenario: Default generator
- **WHEN** OrderSystem starts
- **THEN** active_generator SHALL be the UnitOrderGenerator singleton

#### Scenario: Switch generator
- **WHEN** `set_generator(gen)` is called
- **THEN** active_generator SHALL be replaced with gen

#### Scenario: Cancel restores default
- **WHEN** `cancel()` is called
- **THEN** active_generator SHALL be restored to the UnitOrderGenerator singleton (not a new instance)

### Requirement: OrderGenerator base class
`OrderGenerator` SHALL be a base class with virtual methods: `get_cursor(target, target_cell, target_pos, modifiers) -> CursorState.Type`, `get_orders(target, target_cell, target_pos, modifiers) -> Array[OrderResult]`, `cancel()`. The generator SHALL access selection via the SelectionManager autoload.

#### Scenario: Base class defaults
- **WHEN** a subclass does not override a method
- **THEN** get_cursor() SHALL return DEFAULT, get_orders() SHALL return empty array

### Requirement: UnitOrderGenerator
`UnitOrderGenerator` SHALL extend OrderGenerator as a stateless singleton. `get_cursor()` SHALL delegate to `OrderResolver.resolve_single()` using the current selection from SelectionManager. `get_orders()` SHALL delegate to `OrderResolver.resolve_all()`.

#### Scenario: Cursor resolution
- **WHEN** get_cursor() is called with a target
- **THEN** it SHALL return the cursor from the single highest-priority OrderResult, or DEFAULT if none

#### Scenario: Order resolution
- **WHEN** get_orders() is called with a target
- **THEN** it SHALL return the array from resolve_all() — one OrderResult per matching entity

### Requirement: SellOrderGenerator
`SellOrderGenerator` SHALL extend OrderGenerator. It SHALL show SELL cursor on sellable buildings, SELL_BLOCKED elsewhere. A building is sellable if it has FoundationComponent, is not under construction, and has no active production queue. `get_orders()` SHALL return an OrderResult with a sell execute callback.

> **Note:** Sell/repair order generation is building management functionality, not order resolution infrastructure. This requirement is included here for completeness but may be moved to a dedicated sell-repair spec in the future.

#### Scenario: Sellable building under cursor
- **WHEN** target has FoundationComponent, is fully constructed, and has no active production
- **THEN** cursor SHALL be SELL and order SHALL sell the building

#### Scenario: Building under construction
- **WHEN** target has FoundationComponent but is under construction
- **THEN** cursor SHALL be SELL_BLOCKED

#### Scenario: Non-building under cursor
- **WHEN** target does not have FoundationComponent
- **THEN** cursor SHALL be SELL_BLOCKED

#### Scenario: No target
- **WHEN** cursor is over terrain with no entity
- **THEN** cursor SHALL be SELL_BLOCKED

### Requirement: RepairOrderGenerator
`RepairOrderGenerator` SHALL extend OrderGenerator. It SHALL show REPAIR cursor on damaged buildings, REPAIR_BLOCKED on healthy buildings or non-buildings. `get_orders()` SHALL return an OrderResult with a repair execute callback.

#### Scenario: Damaged building under cursor
- **WHEN** target has FoundationComponent and health < max_health
- **THEN** cursor SHALL be REPAIR and order SHALL repair the building

#### Scenario: Healthy building under cursor
- **WHEN** target has FoundationComponent and health >= max_health
- **THEN** cursor SHALL be REPAIR_BLOCKED

#### Scenario: Non-building under cursor
- **WHEN** target does not have FoundationComponent
- **THEN** cursor SHALL be REPAIR_BLOCKED
