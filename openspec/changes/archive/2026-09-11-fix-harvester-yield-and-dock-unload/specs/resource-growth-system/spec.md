## ADDED Requirements

### Requirement: Growth and spread amounts use the bale scale
`ResourceGrowthSystem` SHALL convert bale amounts to health through the target cell's bale capacity (`ResourceType.bales_per_cell`) when spawning resources via trees or spread. A spawn or spread amount of X bales SHALL create a cell at `X / bales_per_cell` of max health (clamped to at least 1 health).

#### Scenario: Spread seeds at the intended bale amount
- **WHEN** a tree with `spread_amount = 0.5` bales spawns a tiberium cell (`bales_per_cell = 11`)
- **THEN** the spawned cell's health ratio SHALL be approximately `0.5 / 11`, not 0.5

#### Scenario: Growth is unchanged in ratio terms
- **WHEN** a resource cell grows by `grow_rate` of its max health
- **THEN** its remaining bales SHALL increase by `grow_rate x bales_per_cell`

#### Scenario: Regrown cell reaches full bale capacity
- **WHEN** a partially grown cell heals to full health
- **THEN** `ResourceComponent.get_amount()` SHALL equal `bales_per_cell`

#### Scenario: Map-editor brush scales by bales
- **WHEN** the map editor adds or removes 50% strength on an existing resource cell
- **THEN** its remaining bales SHALL change by `0.5 x bales_per_cell`
