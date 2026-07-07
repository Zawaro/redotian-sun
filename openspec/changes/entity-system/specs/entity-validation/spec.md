## ADDED Requirements

### Requirement: EntityData validation on load
EntityData SHALL have a `validate() -> PackedStringArray` method that checks for required fields and returns error messages. Validation SHALL run when EntityData is loaded from .tres.

#### Scenario: Valid entity data
- **WHEN** an EntityData with `id = "E1"`, `display_name = "Light Infantry"`, `strength = 125`, `cost = 120`, `owner = ["GDI", "Nod"]` is validated
- **THEN** `validate()` returns an empty array (no errors)

#### Scenario: Missing id
- **WHEN** an EntityData with `id = ""` is validated
- **THEN** `validate()` returns `["EntityData: id is empty"]`

#### Scenario: Zero strength for non-terrain
- **WHEN** an EntityData with `entity_type = VEHICLE`, `strength = 0` is validated
- **THEN** `validate()` returns `["BGGY: strength must be > 0"]`

#### Scenario: Negative cost
- **WHEN** an EntityData with `cost = -100` is validated
- **THEN** `validate()` returns `["E1: cost must be >= 0"]`

#### Scenario: Empty owner
- **WHEN** an EntityData with `owner = []` is validated
- **THEN** `validate()` returns `["E1: owner is empty"]`

### Requirement: Component-level validation
Each component SHALL validate its own requirements when configured. Validation errors SHALL be logged via `push_warning()` but SHALL NOT crash the game.

#### Scenario: CombatComponent without weapons
- **WHEN** CombatComponent is configured with EntityData having `weapons = []`
- **THEN** CombatComponent logs a warning "CombatComponent: 'E1' has no weapons" and does not crash

#### Scenario: TransportComponent without dock for harvester
- **WHEN** TransportComponent is configured with `harvester = true`, `dock = ""`
- **THEN** TransportComponent logs a warning about missing dock configuration

### Requirement: Graceful degradation
When validation fails, the entity SHALL still be created with whatever valid data is available. Missing components SHALL be skipped. Invalid properties SHALL be set to defaults.

#### Scenario: Entity with invalid weapons
- **WHEN** EntityData has `weapons = [WeaponData with damage=0]`
- **THEN** CombatComponent is added but the weapon with 0 damage is logged as invalid and skipped

#### Scenario: Entity with missing art data
- **WHEN** EntityData has `art_data = null`
- **THEN** ArtComponent is added with default visual (gray box mesh)

### Requirement: TODO logging for unimplemented properties
When a component encounters a property that is not yet implemented, it SHALL log a TODO message and skip the property gracefully.

#### Scenario: Unimplemented property
- **WHEN** EntityData has `cloakeable = true` but SpecialAbilityComponent does not implement cloaking yet
- **THEN** SpecialAbilityComponent logs "TODO: cloakeable not implemented for E1" and continues
