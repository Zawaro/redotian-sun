# ice-drowning Specification

## Purpose

Ice is a damageable terrain entity sitting on a water cell. While intact it provides footing for ground units (pathable and occupiable); units entering its cell deal one-time weight-based damage, and when the ice breaks its occupants drown and the cell reverts to water passability.
## Requirements
### Requirement: Ice as a terrain entity
Ice SHALL be modeled as a damageable terrain entity (like trees/rocks) with a `HealthComponent`, not as a LandType surface. An ice entity SHALL occupy a cell whose underlying land type is `water`. While the ice entity is alive, ground locomotors SHALL be able to path onto and occupy its cell (the ice provides footing); when it is destroyed, the cell reverts to water passability.

#### Scenario: Ground unit stands on intact ice
- **WHEN** a wheeled unit is ordered onto a water cell occupied by an intact ice entity
- **THEN** the cell is pathable and the unit moves onto it

#### Scenario: Broken ice reverts to water
- **WHEN** the ice entity on a water cell is destroyed
- **THEN** the cell becomes impassable to ground locomotors again

### Requirement: Weight-based ice damage on occupancy
MovementController SHALL deal one-time damage to an ice entity on a cell when a unit enters it. The damage SHALL be derived from `EntityData.weight`, anchored to `GlobalRules` ice thresholds (`IceCrackingWeight`), and SHALL occur once per cell entry, not continuously. Lighter units below the cracking threshold SHALL deal no damage.

#### Scenario: Heavy unit cracks ice
- **WHEN** a `weight = 3.0` vehicle enters a cell with an ice entity
- **THEN** the ice entity takes weight-proportional damage (>= the cracking threshold)

#### Scenario: Light unit damages nothing
- **WHEN** a `weight = 0.5` unit enters the same ice cell
- **THEN** the ice entity takes no damage

#### Scenario: Damage occurs once per entry
- **WHEN** a heavy unit sits on an ice cell for several seconds
- **THEN** the ice entity takes ice damage only on the entry transition, not per tick

### Requirement: Ice breakage kills its occupants
When an ice entity's health reaches zero, the entity SHALL be destroyed and any units occupying its cell SHALL be destroyed (drowned). Units on adjacent cells SHALL be unaffected.

#### Scenario: Occupant drowns
- **WHEN** an ice entity's health reaches zero while a unit occupies its cell
- **THEN** the occupying unit is killed and the ice entity is destroyed

#### Scenario: Adjacent units survive
- **WHEN** an ice entity is destroyed
- **THEN** units on neighboring cells are not killed

#### Scenario: Multiple ice hits break
- **WHEN** an ice entity receives cumulative damage that reaches its `strength`
- **THEN** it is destroyed and its occupants drown

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

### Requirement: Ice takes warhead damage
An ice entity SHALL take warhead damage only when both the game declares the `breakable_ice` feature and the warhead sets `WarheadData.can_damage_walls`. When either condition fails, ice SHALL take no warhead damage. Ice is reached through the cell-overlay pass of shot resolution: a force-fire shot with no entity target, or collateral from a shot that did have one. This gate is independent of the existing weight-based surface damage, which is driven by occupancy rather than warheads.

#### Scenario: Ice damaged when the feature and flag are both present
- **WHEN** the game declares `breakable_ice` and a shot whose warhead sets `can_damage_walls` resolves over an ice cell
- **THEN** that ice entity's health SHALL decrease

#### Scenario: Ice untouched without the warhead flag
- **WHEN** the game declares `breakable_ice` and a shot whose warhead clears `can_damage_walls` resolves over an ice cell
- **THEN** that ice entity's health SHALL be unchanged

#### Scenario: Ice untouched when the feature is off
- **WHEN** the game does not declare `breakable_ice` and a shot whose warhead sets `can_damage_walls` resolves over an ice cell
- **THEN** that ice entity's health SHALL be unchanged

#### Scenario: Warhead-killed ice drowns its occupants
- **WHEN** warhead damage drives an ice entity's health to zero while the `breakable_ice` feature is on and units occupy its cell
- **THEN** the ice SHALL be destroyed and those occupants SHALL drown, per the existing breakage requirement

