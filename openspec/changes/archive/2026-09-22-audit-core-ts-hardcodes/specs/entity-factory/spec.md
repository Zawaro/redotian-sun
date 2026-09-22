## ADDED Requirements

### Requirement: Factory content branches keyed on data flags
`EntityFactory` and `EntityPlacer` SHALL select resource-spawner, procedural-resource and breakable-surface behavior from `EntityData` boolean flags, and SHALL NOT compare against Tiberian Sun category or id strings such as `"tiberium"`, `"tiberium_tree"` or an `"ICE"` legacy-id prefix.

#### Scenario: Spawner by flag
- **WHEN** an entity's data has `resource_spawner = true`
- **THEN** the factory adds the resource-tree component and the `resource_trees` group without matching a category string

#### Scenario: Procedural resource by flag
- **WHEN** an entity's data flags a procedural resource visual
- **THEN** the factory omits the ArtComponent without matching `"tiberium"`

#### Scenario: Breakable surface by flag
- **WHEN** an entity's data has `breakable_surface = true` and the game enables `breakable_ice`
- **THEN** the factory attaches the breakable-surface component without inspecting `legacy_id`

### Requirement: Ice component gated by feature flag
`EntityFactory` SHALL attach the breakable-surface component only when `GameContext.has_feature("breakable_ice")` is true. When the flag is off the entity SHALL spawn normally with no ice group membership.

#### Scenario: Ice disabled
- **WHEN** an entity with `breakable_surface = true` spawns in a game without `breakable_ice`
- **THEN** it has no IceComponent and is not in the `ice` group
