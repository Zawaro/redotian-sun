## ADDED Requirements

### Requirement: ProductionManager manages per-player production queues
`ProductionManager` SHALL be an autoload singleton managing production queues keyed by `player_id:factory_type`. It emits `production_started`, `production_progress`, `production_completed`, `production_cancelled`, and `production_paused` signals.

#### Scenario: Queue key format
- **WHEN** player 0 builds infantry
- **THEN** queue key is `"0:infantry"`

### Requirement: Start production
`start_production(player_id, entity_data, count)` SHALL add items to the queue after verifying prerequisites (via PrerequisiteSystem) and affordability (via EconomyManager). Returns false if checks fail.

#### Scenario: Start production — success
- **WHEN** player has prerequisites, can afford, and queue is empty
- **THEN** item is added, `production_started` emits, returns true

#### Scenario: Start production — prerequisite fails
- **WHEN** player lacks required buildings
- **THEN** returns false, no item added

#### Scenario: Start production — insufficient funds
- **WHEN** player cannot afford the entity
- **THEN** returns false

#### Scenario: Stack incrementing
- **WHEN** last queue item is the same entity type
- **THEN** count increments (up to MAX_STACK = 25) instead of adding new item

### Requirement: Gradual cost deduction
During production, credits SHALL be deducted gradually over the build time at rate `cost / build_time * speed`. A fractional accumulator prevents rounding loss. On completion, any remaining balance is deducted.

#### Scenario: Gradual deduction during production
- **WHEN** a 1000-credit entity with 10s build time is producing
- **THEN** approximately 100 credits are deducted per second

#### Scenario: Remaining balance on completion
- **WHEN** production completes and deducted total < cost
- **THEN** the remaining balance is deducted to reach exact cost

### Requirement: Production speed bonus from multiple factories
Production speed SHALL be `1.0 + (factory_count - 1) * 0.25` where `factory_count` is the number of matching-type factories owned by the player. Primary factory is preferred for spawning.

#### Scenario: Single factory
- **WHEN** player owns 1 infantry factory
- **THEN** production speed is 1.0

#### Scenario: Three factories
- **WHEN** player owns 3 vehicle factories
- **THEN** production speed is 1.5

### Requirement: Cancel production with refund
`cancel_production(player_id, queue_key, index, count)` SHALL remove items and refund only the amount already deducted. If count >= item count, entire item is removed.

#### Scenario: Cancel full item
- **WHEN** item has 500 deducted and is fully cancelled
- **THEN** 500 credits are refunded, item removed

#### Scenario: Cancel partial count
- **WHEN** stacked item has count 5 and count=1 is cancelled
- **THEN** count decrements to 4, no refund (waiting items not yet deducted)

### Requirement: Pause and resume production
`pause_production(queue_key, index)` and `resume_production(queue_key, index)` SHALL toggle the `is_paused` flag on queue items. Paused items do not advance.

#### Scenario: Pause production
- **WHEN** `pause_production()` is called on active item
- **THEN** `item.is_paused = true`, timer stops advancing

#### Scenario: Resume production
- **WHEN** `resume_production()` is called on paused item
- **THEN** `item.is_paused = false`, timer resumes

### Requirement: Building completion enters placement mode
When a building completes, it enters ready-to-place state. `get_ready_buildings(player_id)` returns the list of ready `EntityData`. Each ready entry SHALL track the amount already deducted for that building. `place_ready_building(player_id, entity_id)` triggers BuildingManager build mode with skip deduction. `cancel_ready_building(player_id, entity_id)` SHALL refund the tracked deducted amount for that entry.

#### Scenario: Building completes
- **WHEN** production reaches 100% for a building
- **THEN** building is added to `_ready_to_place` with its deducted amount recorded, `_waiting_for_placement` blocks queue

#### Scenario: Place ready building
- **WHEN** `place_ready_building()` is called
- **THEN** BuildingManager enters build mode with skip deduction flag

#### Scenario: Cancel ready building
- **WHEN** `cancel_ready_building()` is called
- **THEN** the amount recorded as deducted for that entry is refunded, and the player's waiting queues unblock

#### Scenario: Build mode exited without placing
- **WHEN** BuildingManager exits build mode without placing, emitting `build_mode_changed(false, player_id)`
- **THEN** only the exiting player's `_waiting_for_placement` queues unblock, leaving other players' queues untouched

### Requirement: Unit spawning on completion
When a unit completes, ProductionManager SHALL find a free factory via `_find_factories()` and call `FactoryComponent.on_unit_produced()`. If no factory is free, the unit enters ready-to-spawn state. When the fallback spawner cannot find a free exit cell near the factory, the unit SHALL NOT spawn inside the building; it SHALL enter ready-to-spawn state with a warning.

#### Scenario: Unit spawns via factory
- **WHEN** unit completes and free factory exists
- **THEN** FactoryComponent.on_unit_produced() is called

#### Scenario: No free factory
- **WHEN** unit completes but all matching factories are busy
- **THEN** unit enters `_ready_to_spawn` list

#### Scenario: No free exit cell in fallback spawn
- **WHEN** a unit completes at a factory without FactoryComponent and no free exit cell exists within the search radius
- **THEN** the unit is NOT placed on the factory's own cell
- **THEN** a warning is logged and the unit enters `_ready_to_spawn`

#### Scenario: Ready-to-spawn retry
- **WHEN** `retry_ready_spawn()` is called
- **THEN** spawn is attempted again

#### Scenario: Ready-to-spawn cancel
- **WHEN** `cancel_ready_spawn()` is called
- **THEN** full cost is refunded

### Requirement: Debug instant-build mode
When `debug_menu.no_build_time == true`, production SHALL complete instantly in one frame.

#### Scenario: Debug mode active
- **WHEN** `no_build_time` is true
- **THEN** production completes immediately, no timer advancement

### Requirement: Zero build time handling
If `entity_data.get_build_time()` returns 0 or negative, production SHALL complete immediately.

#### Scenario: Zero build time
- **WHEN** entity has build_time = 0
- **THEN** item completes in one frame
