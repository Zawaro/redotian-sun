## ADDED Requirements

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
