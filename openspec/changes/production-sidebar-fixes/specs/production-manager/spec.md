## MODIFIED Requirements

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
