## ADDED Requirements

### Requirement: ResourceType resource class
The system SHALL provide a `ResourceType.gd` resource class defining a resource type with id, display_name, category, parent_type, value_per_unit, and color.

#### Scenario: Create resource category
- **WHEN** a ResourceType is created with `id = "tiberium"`, `category = ""`, `parent_type = ""`
- **THEN** it represents a top-level resource category

#### Scenario: Create resource sub-type
- **WHEN** a ResourceType is created with `id = "tiberium_green"`, `category = "tiberium"`, `parent_type = "tiberium"`, `value_per_unit = 1.0`
- **THEN** it represents a sub-type of the tiberium category with 1 credit per unit

### Requirement: GlobalRules resource types registry
GlobalRules SHALL contain `resource_types: Dictionary` mapping resource type IDs to ResourceType resources.

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

### Requirement: Resource type .tres files
ResourceType definitions SHALL be stored as `.tres` files under `resources/resource_types/`.

#### Scenario: Tiberium category .tres
- **WHEN** `resources/resource_types/tiberium.tres` is loaded
- **THEN** it is a ResourceType with `id = "tiberium"`, empty category, empty parent_type

#### Scenario: Tiberium green sub-type .tres
- **WHEN** `resources/resource_types/tiberium_green.tres` is loaded
- **THEN** it is a ResourceType with `id = "tiberium_green"`, `category = "tiberium"`, `value_per_unit = 1.0`

### Requirement: TransportComponent Dictionary cargo
TransportComponent SHALL use `cargo: Dictionary = {}` with format `{resource_type_id: amount}` instead of a single integer.

#### Scenario: Add cargo
- **WHEN** `add_cargo("tiberium_green", 100)` is called on an empty cargo
- **THEN** `cargo["tiberium_green"] = 100`

#### Scenario: Add cargo respects capacity
- **WHEN** `add_cargo("tiberium_green", 100)` is called with `resource_capacity = 50` and `cargo = {}`
- **THEN** `cargo["tiberium_green"] = 50` (capped by capacity)

#### Scenario: Remove cargo
- **WHEN** `remove_cargo("tiberium_green", 30)` is called with `cargo = {"tiberium_green": 100}`
- **THEN** `cargo["tiberium_green"] = 70`

#### Scenario: Remove cargo erases at zero
- **WHEN** `remove_cargo("tiberium_green", 100)` is called with `cargo = {"tiberium_green": 100}`
- **THEN** `cargo` becomes `{}` (empty dictionary)

#### Scenario: Get cargo total
- **WHEN** `get_cargo_total()` is called with `cargo = {"tiberium_green": 300, "tiberium_blue": 100}`
- **THEN** returns 400

#### Scenario: Get cargo value
- **WHEN** `get_cargo_value(global_rules)` is called with `cargo = {"tiberium_green": 300, "tiberium_blue": 100}`
- **THEN** returns `300 * 1.0 + 100 * 2.0 = 500`

### Requirement: TransportComponent resource_capacity
TransportComponent SHALL use `resource_capacity: int = 0` instead of `storage: int = 0`.

#### Scenario: Configure resource capacity
- **WHEN** TransportComponent is configured with `resource_capacity = 700`
- **THEN** the harvester can carry up to 700 units of resources
