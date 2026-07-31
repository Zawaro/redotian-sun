## MODIFIED Requirements

### Requirement: Armor type database
GlobalRules SHALL contain `armor_types: Dictionary` mapping armor type id strings to `ArmorType` resources. The dictionary SHALL be customizable — unlimited armor types can be added by registering new ArmorType `.tres` files.

#### Scenario: Default armor types
- **WHEN** GlobalRules is loaded
- **THEN** `armor_types` contains ArmorType entries for "none", "wood", "light", "heavy", and "concrete"

#### Scenario: Custom armor type
- **WHEN** a mod adds a "flak" ArmorType and registers it in `armor_types`
- **THEN** entities with `armor = "flak"` can be looked up via `get_armor_type("flak")`

#### Scenario: Armor lookup
- **WHEN** damage is dealt to an entity with `armor = "heavy"`
- **THEN** the system resolves the warhead's multiplier for "heavy" and applies it to the damage calculation (see combat-firing spec)

### Requirement: Warhead definitions
GlobalRules SHALL contain `warheads: Dictionary` mapping warhead id strings to `WarheadData` resources, and SHALL expose `get_warhead(id: String) -> WarheadData`. Warheads define per-armor damage multipliers and effects.

#### Scenario: Warhead registry lookup
- **WHEN** `get_warhead("SA")` is called on a loaded GlobalRules
- **THEN** it returns the WarheadData for the small-arms warhead

#### Scenario: Unknown warhead lookup
- **WHEN** `get_warhead("UnknownWH")` is called
- **THEN** it returns `null`

#### Scenario: Warhead damage modification
- **WHEN** a weapon with `warhead = "HE"` fires at an entity
- **THEN** the HE warhead's per-armor multiplier is applied to the base damage

## ADDED Requirements

### Requirement: Minimum and maximum damage clamps
GlobalRules SHALL contain `min_damage: int = 1` and `max_damage: int = 1000` (from rules.ini [CombatDamage]). Final applied damage SHALL be clamped into `[min_damage, max_damage]` before application. A warhead that deals 0% against the target's armor SHALL bypass the minimum-damage floor and deal 0.

#### Scenario: Minimum damage floor
- **WHEN** a warhead's armor multiplier would reduce damage below `min_damage`
- **THEN** the applied damage SHALL be clamped to `min_damage` (1)

#### Scenario: Maximum damage cap
- **WHEN** a warhead's armor multiplier would push damage above `max_damage`
- **THEN** the applied damage SHALL be clamped to `max_damage` (1000)

#### Scenario: Zero-multiplier bypasses the floor
- **WHEN** a warhead's armor multiplier for the target's armor is 0.0
- **THEN** the applied damage SHALL be 0, ignoring `min_damage`

### Requirement: Warhead armor multiplier lookup
GlobalRules SHALL expose a helper that resolves a warhead's damage multiplier for a given armor type, defaulting to 1.0 (full damage) when the warhead or armor type is unknown.

#### Scenario: Multiplier for known armor
- **WHEN** querying the SA warhead's multiplier for armor "concrete"
- **THEN** it returns 0.10 (10%)

#### Scenario: Overkill warhead
- **WHEN** querying the Fire warhead's multiplier for armor "none"
- **THEN** it returns 6.0 (600%), allowing multipliers above 1.0

#### Scenario: Zero-damage armor pairing
- **WHEN** querying a warhead whose multiplier for a given armor is 0.0
- **THEN** it returns 0.0 and the entity takes no damage from that warhead against that armor

#### Scenario: Unknown armor defaults to full damage
- **WHEN** querying any warhead's multiplier for an armor id not in the registry
- **THEN** it returns 1.0

### Requirement: Veterancy damage reduction
StatsComponent SHALL contain `veteran_level: int = 0`. Incoming damage SHALL be reduced by the veteran armor multiplier for the entity's level (`veteran_armor` from GlobalRules, e.g. 0.25 = 25% reduction at level 1).

#### Scenario: Veteran reduces incoming damage
- **WHEN** a level-1 unit with `armor = "none"` and `veteran_armor = 0.25` takes 100 base damage
- **THEN** the applied damage SHALL be reduced by 25% (75) before the minimum-damage floor

#### Scenario: Rookie takes full damage
- **WHEN** a level-0 unit takes damage
- **THEN** no veteran armor reduction is applied

### Requirement: Veterancy speed and combat bonuses
MovementController SHALL scale `move_speed` by the veteran speed multiplier for the entity's level (`veteran_speed`). CombatComponent SHALL expose `get_effective_damage(weapon)` scaling weapon damage by the veteran combat multiplier (`veteran_combat`), clamped to the veteran cap.

#### Scenario: Veteran moves faster
- **WHEN** a level-1 unit with `veteran_speed = 0.30` and base speed 10 moves
- **THEN** its effective speed SHALL be 13 (10 × 1.30)

#### Scenario: Veteran combat bonus available
- **WHEN** `get_effective_damage()` is called for a level-1 unit with `veteran_combat = 0.25` and a 20-damage weapon
- **THEN** it returns 25 (20 × 1.25)

### Requirement: Movement slope coefficients
MovementController SHALL read `tracked_uphill`, `tracked_downhill`, `wheeled_uphill`, `wheeled_downhill` from GlobalRules and apply the coefficient for the unit's locomotor type and terrain slope direction while moving over graded terrain.

#### Scenario: Tracked uphill
- **WHEN** a tracked vehicle moves uphill over a slope
- **THEN** its speed is multiplied by `tracked_uphill` (0.5)

#### Scenario: Wheeled downhill
- **WHEN** a wheeled vehicle moves downhill over a slope
- **THEN** its speed is multiplied by `wheeled_downhill` (1.2)

#### Scenario: Flat terrain unchanged
- **WHEN** a vehicle moves over flat terrain
- **THEN** no slope coefficient is applied

### Requirement: Production constants consumption
ProductionManager SHALL read `build_speed` and `multiple_factory` from GlobalRules for build-time and multiple-factory bonuses. `EntityData.get_build_time()` SHALL accept an optional `build_speed` parameter, keeping a constant fallback for callers that pass none.

#### Scenario: Build speed applied
- **WHEN** production computes build time using `build_speed = 0.8`
- **THEN** the build time reflects the GlobalRules value rather than a hardcoded constant

#### Scenario: Multiple factory bonus
- **WHEN** a player owns 2+ factories of the same type
- **THEN** production speed is multiplied by `multiple_factory` (default 0.5 per extra factory)

### Requirement: Repair step consumption
BuildingManager SHALL heal `repair_step` hit points per repair action from GlobalRules instead of a hardcoded literal.

#### Scenario: Repair uses rules value
- **WHEN** a damaged building is repaired
- **THEN** it heals `GlobalRules.repair_step` (default 8) hit points per tick
