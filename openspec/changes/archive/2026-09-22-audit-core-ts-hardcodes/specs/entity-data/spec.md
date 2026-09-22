## ADDED Requirements

### Requirement: EntityData breakable surface flag
`EntityData` SHALL expose `breakable_surface: bool` (default false). Entities flagged breakable SHALL receive the ice (breakable-surface) component, replacing detection by a legacy-id prefix.

#### Scenario: Flagged entity
- **WHEN** an entity's data has `breakable_surface = true` and the game enables `breakable_ice`
- **THEN** the entity receives the breakable-surface component

#### Scenario: Unflagged TS ice-like id
- **WHEN** an entity id ends in an ice-like suffix but `breakable_surface` is false
- **THEN** no breakable-surface component is attached

### Requirement: EntityData resource spawner flag
`EntityData` SHALL expose `resource_spawner: bool` (default false) identifying entities that seed resource crystals, replacing the `"tiberium_tree"` category string branch.

#### Scenario: Spawner flagged
- **WHEN** an entity's data has `resource_spawner = true`
- **THEN** it joins the `resource_trees` group and receives the resource-tree component

#### Scenario: Non-spawner
- **WHEN** an entity's data has `resource_spawner = false`
- **THEN** it does not join `resource_trees` and does not receive the resource-tree component

### Requirement: EntityData procedural resource visual flag
`EntityData` SHALL expose a flag indicating a resource entity that renders via the procedural resource component and therefore needs no art component, replacing the `"tiberium"` category check.

#### Scenario: Procedural resource
- **WHEN** an entity's data flags a procedural resource visual
- **THEN** no ArtComponent is added and the ResourceComponent renders it

#### Scenario: Ordinary resource entity
- **WHEN** an entity's data does not flag a procedural visual
- **THEN** an ArtComponent is added when the data has art

### Requirement: EntityData harvestable categories
`EntityData` SHALL expose `harvestable_categories: PackedStringArray`; `HarvestComponent` SHALL configure its `harvestable_types` from this field. An empty list SHALL mean the harvester accepts every resource category.

#### Scenario: Restricted harvester
- **WHEN** harvester data sets `harvestable_categories = ["ore"]`
- **THEN** the harvester ignores resource cells whose category is not `"ore"`

#### Scenario: Unrestricted harvester
- **WHEN** harvester data leaves `harvestable_categories` empty
- **THEN** the harvester accepts every resource category

### Requirement: Neutral resource defaults
`ResourceComponent.resource_type_id` and `ResourceTreeComponent.resource_type_id` SHALL default to `""` and SHALL be set only through `configure` from entity data, not to a TS resource id.

#### Scenario: Unconfigured resource
- **WHEN** a resource component is created without data
- **THEN** `resource_type_id` is `""` and no tiberium-tinted fallback colour is applied
