## ADDED Requirements

### Requirement: FactoryComponent declares queue types
FactoryComponent SHALL have `produces: Array[String]` field listing queue types this building handles (e.g., `["infantry"]`, `["vehicle"]`). FactoryComponent SHALL read this from EntityData.buildable_queue at configure time.

#### Scenario: Barracks produces infantry
- **WHEN** EntityData has `buildable_queue = "infantry"`
- **THEN** FactoryComponent `produces` SHALL contain `["infantry"]`

#### Scenario: War factory produces vehicles
- **WHEN** EntityData has `buildable_queue = "vehicle"`
- **THEN** FactoryComponent `produces` SHALL contain `["vehicle"]`

### Requirement: FactoryComponent registers in factories group
FactoryComponent SHALL add itself to the `"factories"` group on `_ready()`. ProductionManager SHALL query this group to find factories.

#### Scenario: Factory registered in group
- **WHEN** a building with FactoryComponent enters the scene tree
- **THEN** FactoryComponent SHALL be in the `"factories"` group

#### Scenario: ProductionManager queries factories group
- **WHEN** ProductionManager needs to find a factory for queue type "infantry" and player_id 1
- **THEN** ProductionManager SHALL query `"factories"` group
- **THEN** ProductionManager SHALL filter by `produces` containing "infantry" and matching `player_id`

### Requirement: FactoryComponent orchestrates exit process
FactoryComponent SHALL have `on_unit_produced(entity_data: EntityData, player_id: int)` method. When called, FactoryComponent SHALL:
1. Create the unit via EntityFactory
2. If ExitComponent exists, call `ExitComponent.on_unit_produced(unit)`
3. Else, find nearest free cell and spawn unit there
4. Emit `exit_in_progress` signal

#### Scenario: Unit exits via ExitComponent
- **WHEN** FactoryComponent.on_unit_produced() is called on building with ExitComponent
- **THEN** FactoryComponent SHALL create the unit
- **THEN** FactoryComponent SHALL call ExitComponent.on_unit_produced(unit)
- **THEN** FactoryComponent SHALL emit `exit_in_progress`

#### Scenario: Unit exits without ExitComponent
- **WHEN** FactoryComponent.on_unit_produced() is called on building without ExitComponent
- **THEN** FactoryComponent SHALL create the unit
- **THEN** FactoryComponent SHALL find nearest free cell
- **THEN** FactoryComponent SHALL spawn unit at that cell
- **THEN** FactoryComponent SHALL emit `exit_in_progress`
- **THEN** a warning SHALL be logged

### Requirement: FactoryComponent dead code removed
FactoryComponent SHALL NOT have `free_unit` field or `can_produce()` method. These are dead code.

#### Scenario: No free_unit field
- **WHEN** FactoryComponent is inspected
- **THEN** there SHALL be no `free_unit` field

#### Scenario: No can_produce method
- **WHEN** FactoryComponent is inspected
- **THEN** there SHALL be no `can_produce()` method

### Requirement: ProductionManager signals FactoryComponent
ProductionManager SHALL call `FactoryComponent.on_unit_produced()` when production completes. ProductionManager SHALL listen to `exit_in_progress` signal to find next free factory.

#### Scenario: Production completes
- **WHEN** ProductionManager._complete_item() finishes for a unit
- **THEN** ProductionManager SHALL call FactoryComponent.on_unit_produced(entity_data, player_id)

#### Scenario: Factory busy, find next
- **WHEN** ProductionManager receives `exit_in_progress` from FactoryComponent
- **THEN** ProductionManager SHALL find next free factory of same type for next queued item
