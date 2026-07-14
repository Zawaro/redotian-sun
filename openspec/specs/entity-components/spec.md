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
The system SHALL provide a `TransportComponent.gd` (.gd only) for entities that carry passengers or harvest resources. Cargo SHALL be stored as `cargo: Dictionary = {}` with format `{resource_type_id: amount}`. Cargo capacity SHALL use `storage: int = 0`.

#### Scenario: APC transport
- **WHEN** a TransportComponent is configured with `passengers = 5`, `dock = ""`
- **THEN** the entity can carry up to 5 infantry units

#### Scenario: Harvester
- **WHEN** a TransportComponent is configured with `passengers = 0`, `dock = "PROC"`, `harvester = true`, `storage = 1`
- **THEN** the entity harvests tiberium, docks with refinery, stores up to 1 bale

#### Scenario: Multi-type cargo
- **WHEN** `add_cargo("tiberium_green", 100)` and `add_cargo("tiberium_blue", 50)` are called
- **THEN** `cargo = {"tiberium_green": 100, "tiberium_blue": 50}` and `get_cargo_total()` returns 150

#### Scenario: Cargo value calculation
- **WHEN** `get_cargo_value(global_rules)` is called with `cargo = {"tiberium_green": 300, "tiberium_blue": 100}`
- **THEN** returns `300 * 1.0 + 100 * 2.0 = 500` (using ResourceType.value)

#### Scenario: Cargo changed signal
- **WHEN** `add_cargo()` or `remove_cargo()` is called
- **THEN** `cargo_changed(current: float, capacity: int, type_id: String)` is emitted

### Requirement: SpecialAbilityComponent
The system SHALL provide a `SpecialAbilityComponent.gd` (.gd only) for entities with special abilities (cloak, C4, engineer, disguise, etc.).

#### Scenario: Cloakeable unit
- **WHEN** a SpecialAbilityComponent is configured with `cloakeable = true`
- **THEN** the entity can activate/deactivate cloaking

#### Scenario: Engineer unit
- **WHEN** a SpecialAbilityComponent is configured with `engineer = true`
- **THEN** the entity can capture or repair enemy buildings

### Requirement: HitboxComponent size from EntityData
The system SHALL allow EntityData to specify a custom hitbox size via `hitbox_size: Vector3`. When non-zero, EntityFactory passes this size to the HitboxComponent. When zero, the default BoxShape3D size (2, 2, 2) is used.

#### Scenario: Harvester truck-shaped hitbox
- **WHEN** a harvester EntityData has `hitbox_size = Vector3(1.5, 1.5, 3.0)`
- **THEN** the HitboxComponent BoxShape3D is 1.5 wide, 1.5 tall, 3.0 long (truck proportions)

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

### Requirement: ResourceTreeComponent
The system SHALL provide a `ResourceTreeComponent.gd` (.gd only) for persistent resource spawner entities. See `resource-tree` spec for full requirements.

#### Scenario: Tree spawns crystals
- **WHEN** a ResourceTreeComponent is configured with `spawned_entity_id = "TIB"`, `radius_cells = 8`
- **THEN** it spawns crystal entities within the radius

### Requirement: ResourceComponent
The system SHALL provide a `ResourceComponent.gd` (.gd only) for harvestable resource crystal entities with pseudo-foundation. See `resource-harvesting` spec for full requirements.

#### Scenario: Crystal with 3 visual stages
- **WHEN** a ResourceComponent is configured with `resource_type_id = "tiberium_green"`
- **THEN** visual stage is determined by health ratio (backed by HealthComponent)

### Requirement: HarvestComponent
The system SHALL provide a `HarvestComponent.gd` (.gd only) for harvester behavior. See `resource-harvesting` spec for full requirements.

#### Scenario: Harvester auto-seeks crystal
- **WHEN** a HarvestComponent is idle with empty cargo
- **THEN** it seeks the nearest resource crystal with available amount

### Requirement: DockHostComponent
The system SHALL provide a `DockHostComponent.gd` (.gd only) for buildings with docking capability. See `resource-harvesting` spec for full requirements.

#### Scenario: Refinery dock with queue
- **WHEN** a DockHostComponent is configured with `dock_types = ["harvest"]`, `max_queue_length = 3`
- **THEN** it accepts one harvester at a time and queues up to 3 additional ones

### Requirement: DockClientComponent
The system SHALL provide a `DockClientComponent.gd` (.gd only) for entities that dock at DockHostComponent buildings. See `resource-harvesting` spec for full requirements.

#### Scenario: Harvester seeks refinery
- **WHEN** a DockClientComponent has `can_dock_with = ["PROC"]` and the harvester is full
- **THEN** it finds the nearest PROC refinery and reserves a dock slot

### Requirement: DockUnloadComponent
The system SHALL provide a `DockUnloadComponent.gd` (.gd only) for buildings that unload cargo from docked entities. See `resource-harvesting` spec for full requirements.

#### Scenario: Refinery unloads harvester
- **WHEN** a harvester is docked at a refinery with DockUnloadComponent
- **THEN** cargo is drained at `unload_rate` per second and credits are added via EconomyManager

### Requirement: RefineryComponent
The system SHALL provide a `RefineryComponent.gd` (.gd only) for buildings that accept resource cargo. See `resource-harvesting` spec for full requirements.

#### Scenario: Refinery accepts tiberium
- **WHEN** a RefineryComponent has `accepted_resource_categories = ["tiberium"]`
- **THEN** it accepts cargo with resource types in the tiberium category

### Requirement: FreeUnitComponent
The system SHALL provide a `FreeUnitComponent.gd` (.gd only) that spawns a free unit when its parent enters the scene tree. See `free-unit` spec for full requirements.

#### Scenario: Refinery spawns harvester
- **WHEN** a building with `free_unit = "HARV"` is placed
- **THEN** a HARV entity is spawned in an adjacent free cell
