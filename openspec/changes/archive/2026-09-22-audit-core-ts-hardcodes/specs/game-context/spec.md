## ADDED Requirements

### Requirement: GameDefinition resource includes feature toggles
The `GameDefinition` resource (`scripts/data/GameDefinition.gd`) SHALL include `features: Dictionary` (String→bool), in addition to `id`, `display_name`, `rules`, `data_sets` and `maps_dir`. The `features` dictionary SHALL default to empty, so an existing `game.tres` without the block remains valid.

#### Scenario: TS definition declares features
- **WHEN** `res://games/ts/game.tres` is loaded
- **THEN** `features` is a Dictionary and the TS game declares `breakable_ice` and `resource_tree_regrowth`

#### Scenario: Definition without features loads
- **WHEN** a `game.tres` omits the `features` block
- **THEN** the definition loads with `features == {}` and every `has_feature` query returns `false`

### Requirement: GameContext feature read-through
`GameContext` SHALL expose `has_feature(id: String) -> bool` delegating to the active definition, returning `false` when no game is loaded.

#### Scenario: Active game feature read
- **WHEN** the active definition declares `breakable_ice = true`
- **THEN** `GameContext.has_feature("breakable_ice")` returns `true`

#### Scenario: Unloaded context feature read
- **WHEN** `GameContext.current` is null
- **THEN** `GameContext.has_feature("breakable_ice")` returns `false` without error
