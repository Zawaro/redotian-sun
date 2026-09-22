## ADDED Requirements

### Requirement: Harvest categories from data
`HarvestComponent` SHALL obtain its harvestable categories from `EntityData.harvestable_categories` via a `configure` method, rather than a compile-time `["tiberium"]` default. An empty list SHALL mean the harvester accepts every resource category.

#### Scenario: Configure from data
- **WHEN** a harvester is created from data with `harvestable_categories = ["tiberium"]`
- **THEN** `harvestable_types` is `["tiberium"]`

#### Scenario: No restrictive default
- **WHEN** harvester data leaves `harvestable_categories` empty
- **THEN** the harvester accepts every category
