## ADDED Requirements

### Requirement: Armor-modified damage
`HealthComponent.take_damage()` SHALL reduce incoming damage by the modifier for the target's armor type, looked up in `GlobalRules.armor_types`, and SHALL always let at least 1 point of positive damage through. When the `GlobalRules` singleton is unavailable, damage SHALL be applied unmodified.

#### Scenario: Heavy armor reduces damage
- **WHEN** an entity with `armor = "heavy"` (modifier 0.4) takes 100 base damage
- **THEN** its health drops by 40

#### Scenario: No armor is identity
- **WHEN** an entity with `armor = "none"` (modifier 1.0) takes 25 base damage
- **THEN** its health drops by 25

#### Scenario: Minimum one damage
- **WHEN** an entity with `armor = "concrete"` (modifier 0.3) takes 2 base damage
- **THEN** its health drops by at least 1

#### Scenario: Rules unavailable
- **WHEN** `take_damage(30)` is called and no `GlobalRules` singleton is loaded
- **THEN** health drops by 30

### Requirement: Veterancy multipliers
`GlobalRules` SHALL expose helper methods that convert a veteran level (clamped to `veteran_cap`) into combat, speed, and armor multipliers. Incoming damage SHALL be further reduced by the veteran armor multiplier, unit movement speed SHALL be increased by the veteran speed multiplier, and combat damage SHALL be increased by the veteran combat multiplier.

#### Scenario: Veteran combat multiplier
- **WHEN** `veteran_combat_multiplier(1)` is called with `veteran_combat = 0.25`
- **THEN** it returns 1.25

#### Scenario: Veteran level clamped to cap
- **WHEN** `veteran_speed_multiplier(9)` is called with `veteran_cap = 2` and `veteran_speed = 0.30`
- **THEN** it returns the level-2 result (1.60), not a level-9 result

#### Scenario: Veteran armor reduces damage taken
- **WHEN** a level-1 unit with `veteran_armor = 0.25` and `armor = "none"` takes 100 base damage
- **THEN** its health drops by 75

#### Scenario: Zero level is neutral
- **WHEN** any veteran multiplier is queried at level 0
- **THEN** it returns 1.0

### Requirement: Movement slope coefficients
`MovementController` SHALL receive its `locomotor` from `EntityData` and SHALL scale movement speed by an uphill/downhill coefficient derived from the local terrain grade and the unit's locomotor. `GlobalRules` SHALL expose `movement_slope_coefficient(locomotor, grade)` returning the tracked or wheeled uphill/downhill value; an unrecognized locomotor SHALL return 1.0.

#### Scenario: Tracked uphill is slower
- **WHEN** `movement_slope_coefficient("Track", grade)` is queried for a positive (uphill) grade with `tracked_uphill = 0.5`
- **THEN** the coefficient is less than 1.0 and no lower than `tracked_uphill`

#### Scenario: Wheeled downhill is faster
- **WHEN** `movement_slope_coefficient("Wheel", grade)` is queried for a negative (downhill) grade with `wheeled_downhill = 1.2`
- **THEN** the coefficient is greater than 1.0 and no higher than `wheeled_downhill`

#### Scenario: Flat terrain is neutral
- **WHEN** `movement_slope_coefficient("Track", 0.0)` is queried
- **THEN** the coefficient is 1.0

#### Scenario: Non-vehicle locomotor unaffected
- **WHEN** `movement_slope_coefficient("Foot", grade)` is queried for any grade
- **THEN** the coefficient is 1.0

### Requirement: Production constants from rules
`ProductionManager` SHALL derive production speed from `GlobalRules`: per-item build time SHALL scale with `build_speed`, and having multiple factories of the same type SHALL apply the `multiple_factory` bonus via `GlobalRules.production_speed_multiplier(factory_count)`. `EntityData.get_build_time()` SHALL accept an optional build-speed argument defaulting to its existing constant.

#### Scenario: Single factory has no bonus
- **WHEN** `production_speed_multiplier(1)` is called
- **THEN** it returns 1.0

#### Scenario: Extra factories add bonus
- **WHEN** `production_speed_multiplier(3)` is called with `multiple_factory = 0.5`
- **THEN** it returns 2.0

#### Scenario: Build time scales with build speed
- **WHEN** `get_build_time(0.8)` is called for an item whose `build_time` is unset (cost-derived)
- **THEN** the returned time reflects the 0.8 factor, matching the previous constant behavior

### Requirement: Repair step from rules
`BuildingManager.repair_building()` SHALL heal the building by `GlobalRules.repair_step` HP per repair action (bounded by remaining missing health) instead of a hardcoded value, falling back to its prior amount when the singleton is unavailable.

#### Scenario: Repair heals by repair_step
- **WHEN** a damaged building missing at least `repair_step` HP is repaired with `repair_step = 8`
- **THEN** its health increases by 8

#### Scenario: Repair does not overheal
- **WHEN** a building missing 3 HP is repaired with `repair_step = 8`
- **THEN** its health increases by 3 and never exceeds max health
