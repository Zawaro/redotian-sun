## MODIFIED Requirements

### Requirement: EntityData resource class
The system SHALL provide a single `EntityData.gd` resource class containing ALL properties for ALL entity types (infantry, vehicle, building, aircraft, terrain). Properties SHALL have sensible defaults (0, false, "") so unused fields can be ignored. The class SHALL include a `buildable: bool` field (default `false`) to indicate whether an entity can be placed by the player via the build menu. EntityData SHALL use `resource_type_id: String` for tiberium type identification, `resource_capacity: int` for harvester cargo capacity, and `accepted_resource_categories: PackedStringArray` for refinery buildings.

#### Scenario: Create infantry entity data
- **WHEN** an EntityData resource is created with `entity_type = INFANTRY`, `strength = 125`, `speed = 5.0`, `weapons = [WeaponData("minigun")]`
- **THEN** the resource contains all fields with defaults for unused properties (e.g., `foundation = Vector2i(1,1)`, `power = 0`, `radar = false`, `buildable = false`)

#### Scenario: Create building entity data
- **WHEN** an EntityData resource is created with `entity_type = BUILDING`, `foundation = Vector2i(2,2)`, `power = 100`, `capturable = true`, `buildable = true`
- **THEN** the resource contains all fields with defaults for unused properties (e.g., `speed = 0.0`, `weapons = []`)

#### Scenario: Create terrain entity data
- **WHEN** an EntityData resource is created with `entity_type = TERRAIN`, `strength = 200`, `foundation = Vector2i(1,1)`
- **THEN** the resource contains all fields with defaults for unused properties (e.g., `speed = 0.0`, `weapons = []`, `capturable = false`, `buildable = false`)

#### Scenario: Buildable field defaults to false
- **WHEN** an EntityData resource is created without explicitly setting `buildable`
- **THEN** `buildable` is `false`

### Requirement: EntityData Tiberium crystal fields
EntityData SHALL include `resource_type_id: String` for identifying the resource sub-type of tiberium crystals.

#### Scenario: Create tiberium crystal data
- **WHEN** an EntityData is created with `tiberium_resource = true`, `tiberium_amount = 300`, `tiberium_max_amount = 300`, `resource_type_id = "tiberium_green"`, `tiberium_regrowth_rate = -1.0`
- **THEN** the entity is a green tiberium crystal with 300 tiberium

### Requirement: EntityData dock configuration
EntityData SHALL include `dock_position: Vector3` and `dock_rotation: float` for buildings with docking capability. EntityData SHALL include `dock: String` for units that dock at buildings (the target entity ID).

#### Scenario: Refinery with dock
- **WHEN** an EntityData is created with `dock_position = Vector3(0, 0, -2)`, `dock_rotation = 180.0`
- **THEN** the building has a dock 2 units behind the building center, facing south

#### Scenario: Harvester with dock target
- **WHEN** an EntityData is created with `dock = "PROC"`, `harvester = true`, `resource_capacity = 700`
- **THEN** the harvester targets refinery entity "PROC" and can carry 700 units of resources

### Requirement: EntityData transport fields
EntityData SHALL include `resource_capacity: int` for harvester cargo capacity and `passengers: int` for infantry transport capacity.

#### Scenario: Harvester transport
- **WHEN** an EntityData is created with `harvester = true`, `resource_capacity = 700`
- **THEN** the harvester can carry 700 units of resources

#### Scenario: APC transport
- **WHEN** an EntityData is created with `passengers = 5`
- **THEN** the APC can carry 5 passengers

### Requirement: EntityData refinery fields
EntityData SHALL include `accepted_resource_categories: PackedStringArray` for buildings that accept resource cargo.

#### Scenario: Refinery with accepted categories
- **WHEN** an EntityData is created with `accepted_resource_categories = ["tiberium"]`
- **THEN** the building accepts tiberium category resources

#### Scenario: Empty accepted categories
- **WHEN** an EntityData is created without setting `accepted_resource_categories`
- **THEN** `accepted_resource_categories` is an empty PackedStringArray

## REMOVED Requirements

### Requirement: EntityData Tiberium type int field
**Reason**: Replaced by `resource_type_id: String` for the resource type hierarchy system.
**Migration**: Replace `tiberium_type = 0` with `resource_type_id = "tiberium_green"` in all .tres files.

### Requirement: EntityData storage field
**Reason**: Replaced by `resource_capacity: int` for consistency with resource type system.
**Migration**: Replace `storage = 700` with `resource_capacity = 700` in all .tres files.
