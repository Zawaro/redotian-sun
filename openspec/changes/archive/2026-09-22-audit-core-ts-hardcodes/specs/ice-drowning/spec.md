## ADDED Requirements

### Requirement: Breakable-surface behavior is feature-gated
The breakable-surface (ice) mechanic SHALL be active only when the game declares `breakable_ice`. Movement SHALL NOT apply weight-based surface damage and pathfinding SHALL NOT grant ice footing when the flag is off. No ice group membership or cell bookkeeping SHALL occur when off.

#### Scenario: Flag on
- **WHEN** a game declares `breakable_ice = true` and a heavy unit enters an intact breakable surface
- **THEN** the surface takes weight-based damage and can break, drowning occupants

#### Scenario: Flag off
- **WHEN** a game does not declare `breakable_ice`
- **THEN** movement across the cell applies no damage and pathfinding treats it by its terrain land type

### Requirement: Ice pathfinding footing gated
`Pathfinder` SHALL treat intact ice as footing over water only when `breakable_ice` is enabled; otherwise water remains impassable for ground locomotors.

#### Scenario: Footing on
- **WHEN** `breakable_ice` is on and intact ice occupies a water cell
- **THEN** a ground locomotor can path across that cell

#### Scenario: Footing off
- **WHEN** `breakable_ice` is off
- **THEN** a water cell with an ice entity is still impassable for ground locomotors
