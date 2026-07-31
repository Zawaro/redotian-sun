## ADDED Requirements

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
