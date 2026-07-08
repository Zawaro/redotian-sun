## MODIFIED Requirements

### Requirement: EntityData resource class
The system SHALL provide a single `EntityData.gd` resource class containing ALL properties for ALL entity types (infantry, vehicle, building, aircraft, terrain). Properties SHALL have sensible defaults (0, false, "") so unused fields can be ignored. The class SHALL include a `buildable: bool` field (default `false`) to indicate whether an entity can be placed by the player via the build menu.

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
