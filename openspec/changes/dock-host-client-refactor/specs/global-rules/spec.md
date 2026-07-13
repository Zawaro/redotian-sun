## MODIFIED Requirements

### Requirement: GlobalRules resource
The system SHALL provide a `GlobalRules.gd` resource class containing all default game values from rules.ini [General] section. GlobalRules SHALL be stored as `resources/global_rules.tres`. GlobalRules SHALL contain `resource_types: Dictionary` mapping resource type IDs to ResourceType resources.

#### Scenario: Load global rules
- **WHEN** the game starts
- **THEN** GlobalRules is loaded with default values (veteran_ratio=10.0, build_speed=0.8, refund_percent=0.5, etc.)

#### Scenario: Resource types loaded
- **WHEN** GlobalRules is loaded
- **THEN** `resource_types` contains entries for "tiberium", "tiberium_green", "tiberium_blue", "tiberium_red", and "vein"

### Requirement: Tiberium value constant
GlobalRules SHALL contain `resource_types: Dictionary` with per-type `value_per_unit` values instead of a single `tiberium_value` float.

#### Scenario: Default tiberium value
- **WHEN** `GlobalRules.get_resource_type("tiberium_green").value_per_unit` is accessed
- **THEN** returns 1.0 (each tiberium unit refined adds 1 credit)

#### Scenario: Blue tiberium value
- **WHEN** `GlobalRules.get_resource_type("tiberium_blue").value_per_unit` is accessed
- **THEN** returns 2.0 (blue tiberium is worth double)

### Requirement: Resource type helpers
GlobalRules SHALL provide `get_resource_type(id)`, `get_resource_category(resource_id)`, and `get_subtypes(category_id)` helper methods.

#### Scenario: Get resource type
- **WHEN** `get_resource_type("tiberium_green")` is called
- **THEN** returns the ResourceType with id "tiberium_green"

#### Scenario: Get category for sub-type
- **WHEN** `get_resource_category("tiberium_green")` is called
- **THEN** returns "tiberium"

#### Scenario: Get sub-types for category
- **WHEN** `get_subtypes("tiberium")` is called
- **THEN** returns an array of all resource type IDs where `category == "tiberium"`

## REMOVED Requirements

### Requirement: Tiberium value constant (single float)
**Reason**: Replaced by per-type `value_per_unit` in `resource_types` dictionary.
**Migration**: Remove `tiberium_value: float` from GlobalRules. Use `resource_types["tiberium_green"].value_per_unit` instead.
