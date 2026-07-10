## ADDED Requirements

### Requirement: GlobalRules resource
The system SHALL provide a `GlobalRules.gd` resource class containing all default game values from rules.ini [General] section. GlobalRules SHALL be stored as `resources/global_rules.tres`.

#### Scenario: Load global rules
- **WHEN** the game starts
- **THEN** GlobalRules is loaded with default values (veteran_ratio=10.0, build_speed=0.8, refund_percent=0.5, etc.)

### Requirement: Armor type database
GlobalRules SHALL contain `armor_types: Dictionary` mapping armor type strings to damage modifiers. The dictionary SHALL be customizable — unlimited armor types can be added.

#### Scenario: Default armor types
- **WHEN** GlobalRules is loaded
- **THEN** `armor_types` contains: "none" (1.0), "wood" (0.7), "light" (0.6), "heavy" (0.4), "concrete" (0.3)

#### Scenario: Custom armor type
- **WHEN** a mod adds `"flak": { "modifier": 0.5 }` to `armor_types`
- **THEN** entities with `armor = "flak"` take 50% damage from all sources

#### Scenario: Armor lookup
- **WHEN** damage is dealt to an entity with `armor = "heavy"`
- **THEN** the system looks up `armor_types["heavy"]["modifier"]` (0.4) and applies it to damage calculation

### Requirement: Warhead definitions
GlobalRules SHALL contain warhead data (from rules.ini [Warheads] section). Warheads define damage types and modifiers.

#### Scenario: Warhead damage modification
- **WHEN** a weapon with `warhead = "HE"` hits an entity
- **THEN** the warhead's damage modifier is applied to the base damage

### Requirement: Veterancy multipliers
GlobalRules SHALL contain veterancy multipliers per level (combat, speed, sight, armor, ROF bonuses).

#### Scenario: Veteran combat bonus
- **WHEN** a unit reaches veteran status
- **THEN** its combat damage is increased by `veteran_combat` multiplier (default 0.25 = 25% bonus)

### Requirement: Movement coefficients
GlobalRules SHALL contain movement coefficients for tracked and wheeled vehicles (uphill/downhill modifiers).

#### Scenario: Tracked uphill movement
- **WHEN** a tracked vehicle moves uphill
- **THEN** its speed is multiplied by `tracked_uphill` coefficient (default 0.5)

### Requirement: Production constants
GlobalRules SHALL contain production constants (multiple factory bonus, min production speed, max queued objects).

#### Scenario: Multiple factory bonus
- **WHEN** a player has 2 war factories
- **THEN** production speed is multiplied by `multiple_factory` coefficient (default 0.5 per extra factory)
## ADDED Requirements

### Requirement: Starting credits constant
GlobalRules SHALL contain `starting_credits: int` for the default credit balance at game start.

#### Scenario: Skirmish starting credits
- **WHEN** GlobalRules is loaded with `starting_credits = 0`
- **THEN** players start with 0 credits (skirmish default)

#### Scenario: Campaign starting credits
- **WHEN** a mission overrides `starting_credits = 2000`
- **THEN** the player starts that mission with 2000 credits

### Requirement: Tiberium value constant
GlobalRules SHALL contain `tiberium_value: float` defining credits earned per unit of tiberium refined.

#### Scenario: Default tiberium value
- **WHEN** GlobalRules is loaded with `tiberium_value = 1.0`
- **THEN** each tiberium unit refined into credits adds 1 credit

#### Scenario: Modified tiberium value
- **WHEN** a mod sets `tiberium_value = 1.5`
- **THEN** each tiberium unit refined adds 1.5 credits

### Requirement: Harvester fill rate constant
GlobalRules SHALL contain `harvester_fill_rate: float` defining tiberium units collected per second from a node.

#### Scenario: Default fill rate
- **WHEN** GlobalRules is loaded with `harvester_fill_rate = 2.0`
- **THEN** a harvester collects 2 tiberium units per second from a node
