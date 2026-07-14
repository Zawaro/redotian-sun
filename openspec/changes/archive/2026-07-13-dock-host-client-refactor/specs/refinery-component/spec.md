## ADDED Requirements

### Requirement: RefineryComponent
The system SHALL provide a `RefineryComponent.gd` (script-attached Node) for buildings that accept resource cargo from dock clients. It SHALL declare which resource categories the building accepts.

#### Scenario: Configure refinery
- **WHEN** a RefineryComponent is configured with `accepted_resource_categories = ["tiberium"]`, `unload_rate = 2.33`
- **THEN** the building accepts tiberium category resources and unloads at 2.33 units per tick

#### Scenario: Accept matching resource
- **WHEN** a dock client has cargo with resource_type_id "tiberium_green" and the refinery has `accepted_resource_categories = ["tiberium"]`
- **THEN** the resource is accepted (its category "tiberium" matches)

#### Scenario: Reject non-matching resource
- **WHEN** a dock client has cargo with resource_type_id "vein" and the refinery has `accepted_resource_categories = ["tiberium"]`
- **THEN** the resource is rejected

### Requirement: DockUnloadComponent uses RefineryComponent for validation
DockUnloadComponent SHALL check RefineryComponent's `accepted_resource_categories` before processing cargo from a docked client.

#### Scenario: Unload valid cargo
- **WHEN** a dock client is docked and has cargo with matching category
- **THEN** DockUnloadComponent processes the unload tick normally

#### Scenario: Skip invalid cargo
- **WHEN** a dock client is docked but cargo category does not match RefineryComponent
- **THEN** DockUnloadComponent skips the unload tick (or calls leave_dock)

### Requirement: DockUnloadComponent uses ResourceType for credit calculation
DockUnloadComponent SHALL look up `GlobalRules.get_resource_type(type_id).value_per_unit` for each cargo type when calculating credits.

#### Scenario: Single type cargo unload
- **WHEN** cargo is `{"tiberium_green": 100}` and `value_per_unit = 1.0`
- **THEN** 100 credits are added

#### Scenario: Multi-type cargo unload
- **WHEN** cargo is `{"tiberium_green": 300, "tiberium_blue": 100}` with values 1.0 and 2.0
- **THEN** `300 * 1.0 + 100 * 2.0 = 500` credits are added

### Requirement: EntityData accepted_resource_categories
EntityData SHALL include `accepted_resource_categories: PackedStringArray` for buildings that accept resource cargo.

#### Scenario: Refinery with accepted categories
- **WHEN** an EntityData has `accepted_resource_categories = ["tiberium"]`
- **THEN** EntityFactory attaches a RefineryComponent with those categories

#### Scenario: Empty accepted categories
- **WHEN** an EntityData has `accepted_resource_categories = []`
- **THEN** no RefineryComponent is attached

### Requirement: EntityFactory creates RefineryComponent
EntityFactory SHALL attach RefineryComponent when `data.accepted_resource_categories.size() > 0`.

#### Scenario: Refinery entity gets RefineryComponent
- **WHEN** an entity is created with `accepted_resource_categories = ["tiberium"]`
- **THEN** it has a RefineryComponent child with those categories

#### Scenario: Non-refinery entity skips RefineryComponent
- **WHEN** an entity is created with `accepted_resource_categories = []`
- **THEN** no RefineryComponent is added
