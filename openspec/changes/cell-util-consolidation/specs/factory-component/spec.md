## MODIFIED Requirements

### Requirement: ProductionManager signals FactoryComponent
ProductionManager SHALL call `FactoryComponent.on_unit_produced()` when production completes. ProductionManager SHALL listen to `exit_in_progress` signal to find next free factory. ProductionManager SHALL use `CellUtil.spiral_first_free()` for `_find_exit_cell()` instead of an inline spiral loop.

#### Scenario: Production completes
- **WHEN** ProductionManager._complete_item() finishes for a unit
- **THEN** ProductionManager SHALL call FactoryComponent.on_unit_produced(entity_data, player_id)

#### Scenario: Factory busy, find next
- **WHEN** ProductionManager receives `exit_in_progress` from FactoryComponent
- **THEN** ProductionManager SHALL find next free factory of same type for next queued item

#### Scenario: Exit cell search consolidated
- **WHEN** `_find_exit_cell()` is called
- **THEN** it delegates to `CellUtil.spiral_first_free()` with max radius 6
