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

### Requirement: Starting credits constant
GlobalRules SHALL contain `starting_credits: int` for the default credit balance at game start.

#### Scenario: Skirmish starting credits
- **WHEN** GlobalRules is loaded with `starting_credits = 0`
- **THEN** players start with 0 credits (skirmish default)

#### Scenario: Campaign starting credits
- **WHEN** a mission overrides `starting_credits = 2000`
- **THEN** the player starts that mission with 2000 credits

### Requirement: Resource type registry
GlobalRules SHALL contain `resource_types: Dictionary` mapping resource type IDs to ResourceType resources. This replaces the legacy `tiberium_value` field.

#### Scenario: Default resource types
- **WHEN** GlobalRules is loaded
- **THEN** `resource_types` contains entries for "tiberium", "tiberium_green", "tiberium_blue", "tiberium_red", and "vein"

#### Scenario: Get resource type by ID
- **WHEN** `GlobalRules.get_resource_type("tiberium_green")` is called
- **THEN** it returns the ResourceType for tiberium_green

#### Scenario: Get resource category
- **WHEN** `GlobalRules.get_resource_category("tiberium_green")` is called
- **THEN** it returns "tiberium" (the parent category)

#### Scenario: Get sub-types
- **WHEN** `GlobalRules.get_subtypes("tiberium")` is called
- **THEN** it returns an array of IDs for all resource types where `category == "tiberium"` or `parent_type == "tiberium"`

### Requirement: Harvester fill rate constant
GlobalRules SHALL contain `harvester_fill_rate: float` defining resource units collected per second from a node.

#### Scenario: Default fill rate
- **WHEN** GlobalRules is loaded with `harvester_fill_rate = 2.0`
- **THEN** a harvester collects 2 resource units per second from a node

### Requirement: Resource growth constants
GlobalRules SHALL contain resource growth configuration fields for the ResourceGrowthSystem autoload.

#### Scenario: Tree growth rate
- **WHEN** GlobalRules is loaded with `tree_growth_rate = 3.0`
- **THEN** the tree timer fires every 3 minutes to spawn/grow resources around trees

#### Scenario: Tree spawn radius
- **WHEN** GlobalRules is loaded with `tree_spawn_radius = 3`
- **THEN** trees spawn new resources in a circular area of radius 3 cells (7x7) around themselves

#### Scenario: Resource growth rate
- **WHEN** GlobalRules is loaded with `growth_rate = 5.0`
- **THEN** the resource timer fires every 5 minutes for resource self-growth

#### Scenario: Growth batch sizes
- **WHEN** GlobalRules is loaded with `growth_batch_trees = 10` and `growth_batch_crystals = 500`
- **THEN** only 10 trees and 500 resource entities are processed per timer tick, preventing frame spikes

#### Scenario: Spread configuration
- **WHEN** GlobalRules is loaded with `spread_amount = 0.5`, `spread_max = 3`
- **THEN** resources spread with 0.5 bales, max 3 spreads per entity
