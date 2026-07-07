## ADDED Requirements

### Requirement: StatsComponent
The system SHALL provide a `StatsComponent.gd` (.gd only, no .tscn) that holds entity identity data: id, display_name, entity_type, armor, cost, tech_level, sight, owner, points.

#### Scenario: StatsComponent holds identity
- **WHEN** a StatsComponent is configured with EntityData
- **THEN** it exposes `id`, `display_name`, `entity_type`, `armor`, `cost`, `tech_level`, `sight`, `owner`, `points` as readable properties

### Requirement: FoundationComponent
The system SHALL provide a `FoundationComponent.gd` (.gd only) that holds footprint and height for ANY entity type (buildings, terrain objects, etc.).

#### Scenario: Building foundation
- **WHEN** a FoundationComponent is configured with `foundation = Vector2i(3,3)` and `height = 2.0`
- **THEN** the entity occupies a 3x3 cell footprint with visual height 2.0

#### Scenario: Terrain foundation
- **WHEN** a FoundationComponent is configured with `foundation = Vector2i(1,1)` and `height = 1.0`
- **THEN** the terrain object occupies a 1x1 cell footprint

### Requirement: PowerComponent
The system SHALL provide a `PowerComponent.gd` (.gd only) that holds power output/consumption for ANY entity type.

#### Scenario: Power plant
- **WHEN** a PowerComponent is configured with `power = 100`, `powered = false`
- **THEN** the entity generates 100 power and does not require power to function

#### Scenario: Powered structure
- **WHEN** a PowerComponent is configured with `power = -50`, `powered = true`
- **THEN** the entity consumes 50 power and requires power to function

### Requirement: RadarComponent
The system SHALL provide a `RadarComponent.gd` (.gd only) that provides radar capability to ANY entity type.

#### Scenario: Radar building
- **WHEN** a RadarComponent is configured with `radar = true`
- **THEN** the entity provides radar/minimap functionality to its owner

### Requirement: FactoryComponent
The system SHALL provide a `FactoryComponent.gd` (.gd only) that enables unit production. Buildings AND vehicles can have factory capability.

#### Scenario: War factory
- **WHEN** a FactoryComponent is configured with `factory_type = "VehicleType"`, `free_unit = ""`
- **THEN** the entity can produce vehicle units

#### Scenario: Refinery with free harvester
- **WHEN** a FactoryComponent is configured with `factory_type = "HarvesterType"`, `free_unit = "HARV"`
- **THEN** the entity spawns a free harvester on placement

### Requirement: TransportComponent
The system SHALL provide a `TransportComponent.gd` (.gd only) for entities that carry passengers or harvest resources.

#### Scenario: APC transport
- **WHEN** a TransportComponent is configured with `passengers = 4`, `dock = ""`
- **THEN** the entity can carry up to 4 infantry units

#### Scenario: Harvester
- **WHEN** a TransportComponent is configured with `passengers = 0`, `dock = "PROC"`, `harvester = true`, `storage = 28`
- **THEN** the entity harvests tiberium, docks with refinery, stores up to 28 bails

### Requirement: SpecialAbilityComponent
The system SHALL provide a `SpecialAbilityComponent.gd` (.gd only) for entities with special abilities (cloak, C4, engineer, disguise, etc.).

#### Scenario: Cloakeable unit
- **WHEN** a SpecialAbilityComponent is configured with `cloakeable = true`
- **THEN** the entity can activate/deactivate cloaking

#### Scenario: Engineer unit
- **WHEN** a SpecialAbilityComponent is configured with `engineer = true`
- **THEN** the entity can capture or repair enemy buildings

### Requirement: CombatComponent (updated)
The CombatComponent SHALL support unlimited weapons via `weapons: Array[WeaponData]`. It SHALL be a .tscn scene (may need turret mesh child).

#### Scenario: Multiple weapons
- **WHEN** a CombatComponent is configured with `weapons = [cannon, missile, machine_gun]`
- **THEN** the entity can fire all three weapons independently

#### Scenario: No weapons
- **WHEN** an EntityData has `weapons = []`
- **THEN** CombatComponent is NOT added to the entity

### Requirement: ArtComponent
The system SHALL provide an `ArtComponent.gd` + `.tscn` that links to ArtData and manages visual representation. The .tscn MAY contain an AnimationPlayer/3D for active animations.

#### Scenario: ArtComponent with animations
- **WHEN** an ArtComponent is configured with ArtData containing `active_anims = [anim1, anim2]`
- **THEN** the AnimationPlayer plays the specified animations

### Requirement: MovementController (updated)
The MovementController SHALL be extended with `locomotor: String` and `movement_zone: String` exports. Existing movement behavior is preserved.

#### Scenario: Locomotor setting
- **WHEN** a MovementController is configured with `locomotor = "Track"`, `movement_zone = "Normal"`
- **THEN** the entity uses tracked locomotion and normal movement zone
