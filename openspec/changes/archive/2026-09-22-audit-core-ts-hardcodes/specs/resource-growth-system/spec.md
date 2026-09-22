## ADDED Requirements

### Requirement: Tree regrowth is feature-gated
The tree-seeded resource growth model SHALL run only when the active game declares the `resource_tree_regrowth` feature and the existing `GlobalRules.resource_grows`/`resource_spreads` booleans. With the feature off, no trees are scanned and no crystals are spawned from trees, without errors.

#### Scenario: Feature on
- **WHEN** the active game declares `resource_tree_regrowth = true`, `resource_grows = true`
- **THEN** tree timers tick and spawn crystals within `tree_spawn_radius`

#### Scenario: Feature off
- **WHEN** the active game does not declare `resource_tree_regrowth`
- **THEN** tree processing is skipped and no crystals are spawned, and self-growth/spread of existing crystals is governed by the growth booleans

### Requirement: Generic resource identifiers
`ResourceGrowthSystem` SHALL use generic resource identifiers (`res_*`) rather than Tiberian Sun abbreviations (`tib_*`) in its internal code.

#### Scenario: No tib_ identifiers
- **WHEN** `ResourceGrowthSystem.gd` is linted
- **THEN** it contains no `tib_` identifier
