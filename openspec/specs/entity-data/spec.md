## MODIFIED Requirements

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

## ADDED Requirements

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
