## ADDED Requirements

### Requirement: FactoryComponent has is_primary flag
FactoryComponent SHALL have `is_primary: bool` field. Only one factory per queue type per player SHALL be primary at a time.

#### Scenario: Default primary state
- **WHEN** a factory is created
- **THEN** `is_primary` SHALL be `false`

#### Scenario: Setting primary building
- **WHEN** player sets a factory as primary via FactoryComponent.set_primary()
- **THEN** `is_primary` SHALL be set to `true`
- **THEN** all other factories with same `produces` type and same `player_id` SHALL have `is_primary` set to `false`

#### Scenario: Only one primary per queue type
- **WHEN** player has 2 barracks (both `produces = ["infantry"]`)
- **WHEN** player sets barracks A as primary
- **THEN** barracks A `is_primary` SHALL be `true`
- **THEN** barracks B `is_primary` SHALL be `false`

### Requirement: ProductionManager prefers primary factory
ProductionManager SHALL prefer the primary factory when spawning units. If no primary is set, ProductionManager SHALL use the newest factory of matching type.

#### Scenario: Primary factory selected for spawn
- **WHEN** player has 2 barracks, barracks A is primary
- **WHEN** infantry production completes
- **THEN** ProductionManager SHALL select barracks A for unit spawn

#### Scenario: No primary set, newest factory used
- **WHEN** player has 2 barracks, neither is primary
- **WHEN** infantry production completes
- **THEN** ProductionManager SHALL select the newest barracks (highest ActorID equivalent)

### Requirement: Primary building toggle queries same-type factories
FactoryComponent.set_primary() SHALL query all nodes in `"factories"` group with matching `produces` type and `player_id`, then clear their `is_primary` flag.

#### Scenario: Toggle clears siblings
- **WHEN** FactoryComponent.set_primary() is called on barracks A
- **THEN** all FactoryComponent nodes with `produces` containing "infantry" and matching `player_id` SHALL have `is_primary = false`
- **THEN** barracks A SHALL have `is_primary = true`
