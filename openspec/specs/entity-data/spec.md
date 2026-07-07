## ADDED Requirements

### Requirement: EntityData resource class
The system SHALL provide a single `EntityData.gd` resource class containing ALL properties for ALL entity types (infantry, vehicle, building, aircraft, terrain). Properties SHALL have sensible defaults (0, false, "") so unused fields can be ignored.

#### Scenario: Create infantry entity data
- **WHEN** an EntityData resource is created with `entity_type = INFANTRY`, `strength = 125`, `speed = 5.0`, `weapons = [WeaponData("minigun")]`
- **THEN** the resource contains all fields with defaults for unused properties (e.g., `foundation = Vector2i(1,1)`, `power = 0`, `radar = false`)

#### Scenario: Create building entity data
- **WHEN** an EntityData resource is created with `entity_type = BUILDING`, `foundation = Vector2i(2,2)`, `power = 100`, `capturable = true`
- **THEN** the resource contains all fields with defaults for unused properties (e.g., `speed = 0.0`, `weapons = []`)

#### Scenario: Create terrain entity data
- **WHEN** an EntityData resource is created with `entity_type = TERRAIN`, `strength = 200`, `foundation = Vector2i(1,1)`
- **THEN** the resource contains all fields with defaults for unused properties (e.g., `speed = 0.0`, `weapons = []`, `capturable = false`)

### Requirement: WeaponData resource class
The system SHALL provide a `WeaponData.gd` resource class for defining weapon stats. Each EntityData SHALL reference weapons via `weapons: Array[WeaponData]` — unlimited count.

#### Scenario: Entity with multiple weapons
- **WHEN** an EntityData has `weapons = [minigun, cannon, missile]`
- **THEN** all three WeaponData resources are accessible via the weapons array

#### Scenario: Entity with no weapons
- **WHEN** an EntityData has `weapons = []`
- **THEN** no CombatComponent is added to the entity

### Requirement: ArtData resource class
The system SHALL provide an `ArtData.gd` resource class for visual properties. Each EntityData SHALL reference art via `art_data: ArtData`. ArtData SHALL include model path, animation data, foundation, height, and turret/barrel offsets.

#### Scenario: ArtData with unlimited active animations
- **WHEN** an ArtData has `active_anims = [ActiveAnimData("GACNST_A"), ActiveAnimData("GACNST_B"), ActiveAnimData("GACNST_C")]`
- **THEN** all three animations are accessible via the active_anims array

#### Scenario: ArtData foundation for terrain
- **WHEN** an ArtData has `foundation = Vector2i(1,1)` and `height = 1.0`
- **THEN** terrain entities can use these values for footprint and visual height

### Requirement: ActiveAnimData resource class
The system SHALL provide an `ActiveAnimData.gd` resource class for individual animation definitions. Each animation SHALL include name, damaged variant, offsets, and power requirements.

#### Scenario: Animation with power requirement
- **WHEN** an ActiveAnimData has `requires_power = true`
- **THEN** the animation only plays when the parent entity has power

### Requirement: EntityData.id uniqueness
Each EntityData resource SHALL have a unique `id: String` that matches the rules.ini section name (e.g., "BGGY", "E1", "GAPOWR").

#### Scenario: Duplicate id detection
- **WHEN** two EntityData resources have the same `id`
- **THEN** EntityFactory logs a warning and the later-loaded resource overrides the earlier one
