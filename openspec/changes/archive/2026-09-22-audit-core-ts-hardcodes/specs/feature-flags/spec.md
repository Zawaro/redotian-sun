## ADDED Requirements

### Requirement: GameDefinition feature toggles
`GameDefinition` SHALL expose `features: Dictionary` mapping feature id strings to booleans, and SHALL expose `has_feature(id: String) -> bool`. A feature id absent from the dictionary SHALL evaluate to `false`. Feature ids SHALL be kebab-free snake_case identifiers describing a mechanic (e.g. `breakable_ice`, `resource_tree_regrowth`).

#### Scenario: Declared feature on
- **WHEN** a game definition has `features = {"breakable_ice": true}`
- **THEN** `has_feature("breakable_ice")` returns `true`

#### Scenario: Declared feature off
- **WHEN** a game definition has `features = {"breakable_ice": false}`
- **THEN** `has_feature("breakable_ice")` returns `false`

#### Scenario: Undeclared feature
- **WHEN** a game definition has no `breakable_ice` key
- **THEN** `has_feature("breakable_ice")` returns `false`

### Requirement: Feature-flagged behavior is inert when off
When a feature toggle is off or undeclared, the mechanic it gates SHALL be absent: no entities are created, no group membership is added, no damage or movement effect occurs, and no error is pushed. Gated code SHALL NOT rely on the presence of TS content to avoid errors.

#### Scenario: Ice mechanic off
- **WHEN** a game with `breakable_ice` off spawns an entity whose data sets `breakable_surface`
- **THEN** no `IceComponent` is attached, the entity is not added to the `ice` group, and movement across that cell is unaffected

#### Scenario: Ice mechanic on
- **WHEN** a game with `breakable_ice` on spawns an entity whose data sets `breakable_surface`
- **THEN** the `IceComponent` is attached and the entity joins the `ice` group

### Requirement: Null-safe feature access
`GameContext.has_feature(id: String) -> bool` SHALL return `false` when no game is loaded or the active definition has no such feature, and SHALL never raise an error.

#### Scenario: No active game
- **WHEN** `GameContext.has_feature("breakable_ice")` is called while `GameContext.current` is null
- **THEN** it returns `false`
