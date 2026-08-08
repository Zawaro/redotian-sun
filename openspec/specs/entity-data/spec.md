# entity-data Specification

## Purpose

EntityData is the single resource class describing every entity type (infantry, vehicle, building, aircraft, terrain). It carries identity, stats, combat, movement, docking, and build-requirement fields with sensible defaults, names the unit's Locomotor, and drives how EntityFactory composes an entity.

## Requirements

### Requirement: EntityData resource class
The system SHALL provide a single `EntityData.gd` resource class containing ALL properties for ALL entity types (infantry, vehicle, building, aircraft, terrain). Properties SHALL have sensible defaults (0, false, "") so unused fields can be ignored. The class SHALL include a `buildable: bool` field (default `false`) to indicate whether an entity can be placed by the player via the build menu. The class SHALL include a `deploys_into: String` field (default `""`) to specify the entity id this entity can deploy into. The class SHALL include an `undeploys_into: String` field (default `""`) to specify the entity id this entity can undeploy into.

#### Scenario: Create infantry entity data
- **WHEN** an EntityData resource is created with `entity_type = INFANTRY`, `strength = 125`, `speed = 5.0`, `weapons = [WeaponData("minigun")]`
- **THEN** the resource contains all fields with defaults for unused properties (e.g., `foundation = Vector2i(1,1)`, `power = 0`, `radar = false`, `buildable = false`, `deploys_into = ""`, `undeploys_into = ""`)

#### Scenario: Create building entity data
- **WHEN** an EntityData resource is created with `entity_type = BUILDING`, `foundation = Vector2i(2,2)`, `power = 100`, `capturable = true`, `buildable = true`
- **THEN** the resource contains all fields with defaults for unused properties (e.g., `speed = 0.0`, `weapons = []`, `deploys_into = ""`, `undeploys_into = ""`)

#### Scenario: Create terrain entity data
- **WHEN** an EntityData resource is created with `entity_type = TERRAIN`, `strength = 200`, `foundation = Vector2i(1,1)`
- **THEN** the resource contains all fields with defaults for unused properties (e.g., `speed = 0.0`, `weapons = []`, `capturable = false`, `buildable = false`, `deploys_into = ""`, `undeploys_into = ""`)

#### Scenario: Buildable field defaults to false
- **WHEN** an EntityData resource is created without explicitly setting `buildable`
- **THEN** `buildable` is `false`

#### Scenario: DeploysInto field defaults to empty
- **WHEN** an EntityData resource is created without explicitly setting `deploys_into`
- **THEN** `deploys_into` is `""`

#### Scenario: UndeploysInto field defaults to empty
- **WHEN** an EntityData resource is created without explicitly setting `undeploys_into`
- **THEN** `undeploys_into` is `""`

### Requirement: EntityData dock configuration
EntityData SHALL include `dock_position: Vector3` and `dock_rotation: float` for buildings with docking capability. EntityData SHALL include `dock_unload: bool` to indicate whether the building has a DockUnloadComponent.

#### Scenario: Refinery with dock
- **WHEN** an EntityData is created with `dock_position = Vector3(6, 0, 2)`, `dock_rotation = -90.0`, `dock_unload = true`
- **THEN** the building has a dock 6 units right and 2 units forward, facing west, with unload capability

#### Scenario: Building without dock
- **WHEN** an EntityData is created without setting `dock_position`
- **THEN** `dock_position` is `Vector3.ZERO` and no DockHostComponent is attached

### Requirement: Infantry entity data includes weapons
Infantry entity .tres files SHALL populate the `weapons` array with references to WeaponData .tres files. EntityFactory SHALL create a CombatComponent when `data.weapons` is non-empty.

#### Scenario: GDI Light Infantry has weapon
- **WHEN** `gdi_light_infantry.tres` is loaded
- **THEN** `weapons` SHALL contain a reference to `m1carbine.tres`

#### Scenario: Nod Light Infantry has weapon
- **WHEN** `nod_light_infantry.tres` is loaded
- **THEN** `weapons` SHALL contain a reference to `m1carbine.tres`

#### Scenario: EntityFactory creates CombatComponent
- **WHEN** an entity is created with non-empty `weapons` array
- **THEN** EntityFactory SHALL instantiate CombatComponent and call `configure(data)`

### Requirement: EntityData accepted resource categories
EntityData SHALL include `accepted_resource_categories: PackedStringArray` for buildings that accept resource cargo (refineries). This field SHALL be passed to DockUnloadComponent at creation time. Empty array = accept all cargo types, non-empty array = exclusive whitelist of accepted resource categories.

#### Scenario: Refinery accepts all tiberium
- **WHEN** an EntityData has `accepted_resource_categories = ["tiberium"]`
- **THEN** DockUnloadComponent accepts cargo whose category matches "tiberium"

#### Scenario: Refinery accepts specific types
- **WHEN** an EntityData has `accepted_resource_categories = ["tiberium_green", "tiberium_blue"]`
- **THEN** DockUnloadComponent only accepts cargo with those specific type IDs

#### Scenario: Empty accepts all
- **WHEN** an EntityData has `accepted_resource_categories = []`
- **THEN** DockUnloadComponent accepts any cargo type

### Requirement: EntityData locomotor references the registry
`EntityData.locomotor: String` SHALL name a Locomotor registered in `GlobalRules.locomotors`. The MovementController SHALL resolve the unit's locomotor resource from this id at runtime. An id not in the registry SHALL fall back to no-locomotor behavior (current movement) and SHALL be reported loudly at runtime and by validation.

#### Scenario: Known locomotor resolved
- **WHEN** an EntityData has `locomotor = "Wheel"` and "Wheel" is registered
- **THEN** MovementController resolves the Wheel Locomotor and applies its terrain speeds, climb tolerance, and flags

#### Scenario: Unknown locomotor falls back loudly
- **WHEN** an EntityData has `locomotor = "NotAThing"` not in the registry
- **THEN** the unit moves with current default behavior (no terrain filtering), `push_error` is emitted, and validation reports an error

### Requirement: EntityData movement_zone is a pathfinding domain class
`EntityData.movement_zone: String` SHALL be interpreted as the TS-style pathfinding domain class (e.g. Normal, Infantry, Crusher, Destroyer, AmphibiousCrusher, InfantryDestroyer, Fly, Subterannean) and SHALL be metadata only. It SHALL NOT gate terrain passability — passability SHALL be driven by `locomotor`. Validation SHALL reject a `movement_zone` that contradicts its unit's locomotor (e.g. `Track` with zone `Subterannean`).

#### Scenario: Zone is informational for passability
- **WHEN** two units share `locomotor = "Wheel"` but differ in `movement_zone`
- **THEN** both units have identical terrain passability

#### Scenario: Contradictory zone rejected
- **WHEN** validation runs on an EntityData with `locomotor = "Track"` and `movement_zone = "Subterannean"`
- **THEN** an error is returned naming the entity id

### Requirement: EntityData weight drives ice damage, not speed
`EntityData.weight: float` SHALL represent mass used to damage ice entities when a unit enters their cell. Weight SHALL NOT scale movement speed — speed is set by `EntityData.speed` and terrain/locomotor factors.

#### Scenario: Heavy unit damages ice
- **WHEN** a unit with `weight = 3.0` enters a cell occupied by an ice entity
- **THEN** the ice entity receives weight-proportional damage

#### Scenario: Weight does not affect speed
- **WHEN** two units with the same `speed = 6.0` but different `weight` move over flat clear terrain
- **THEN** both move at 6.0 units per second

### Requirement: Submarine is a Ship with stealth
A naval unit intended as a submarine SHALL use `locomotor = "Ship"` and enable `cloakable` (with TS-style submerge behavior: cloaked in water, decloaks to attack). No dedicated Submarine locomotor SHALL exist.

#### Scenario: Submarine data
- **WHEN** a submarine unit is defined
- **THEN** its EntityData has `locomotor = "Ship"`, a naval `movement_zone` domain, and `cloakable = true`

### Requirement: Default build time derives from GlobalRules build speed
`EntityData.get_build_time()` SHALL return the explicit `build_time` when it is positive. Otherwise it SHALL compute the build time from `cost` and the game-wide build-speed factor, which SHALL be sourced from `GlobalRules.build_speed` rather than a duplicated constant. When GlobalRules is unavailable, it SHALL fall back to the default factor `0.8`.

#### Scenario: Explicit build time takes precedence
- **WHEN** `build_time` is set to a positive value
- **THEN** `get_build_time()` returns that value unchanged

#### Scenario: Computed from GlobalRules build speed
- **WHEN** `build_time` is unset and GlobalRules is available
- **THEN** `get_build_time()` computes `cost * GlobalRules.build_speed * 60 / 1000`

#### Scenario: Fallback when GlobalRules unavailable
- **WHEN** `build_time` is unset and GlobalRules cannot be resolved
- **THEN** `get_build_time()` computes the time using the default factor `0.8`

### Requirement: EntityData voice set reference
EntityData SHALL include an optional `voice_data: VoiceData` export (default null) in the Art group. When set, EntityFactory SHALL attach a VoiceComponent holding the reference; when null, no VoiceComponent is created.

#### Scenario: Voice data set attaches component
- **WHEN** an EntityData has `voice_data` referencing a VoiceData resource
- **THEN** EntityFactory SHALL attach a VoiceComponent holding that reference

#### Scenario: Voice data unset omits component
- **WHEN** an EntityData has `voice_data = null`
- **THEN** no VoiceComponent SHALL be attached
