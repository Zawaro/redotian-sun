## MODIFIED Requirements

### Requirement: Component-level validation
Each component SHALL validate its own requirements against the source
`EntityData` and expose a `validate(data: EntityData) -> PackedStringArray`
method that returns human-readable warning messages (empty when valid).
`EntityFactory` SHALL call `validate()` on every component that defines it at
entity-creation time and SHALL log each returned message via `push_warning()`.
Validation SHALL NOT crash the game, and a warning from one component SHALL NOT
prevent other components from being configured.

The following components SHALL validate:
- **CombatComponent**: warns when `weapons` is empty, and forwards each
  `WeaponData.validate()` error.
- **MovementController**: warns when `speed <= 0`.
- **FoundationComponent**: warns when `foundation == Vector2i(0, 0)`.
- **FactoryComponent**: warns when `factory` is non-empty and not one of the
  known queue types (`BuildingType`, `InfantryType`, `VehicleType`,
  `AircraftType`).
- **TransportComponent**: warns when `harvester == true` but `dock` is empty.
- **StatsComponent**: warns when `id` is empty.

`PowerComponent` and `ArtComponent` are data-only / already graceful and SHALL
NOT define `validate()`.

#### Scenario: CombatComponent without weapons
- **WHEN** `CombatComponent.validate()` runs against EntityData `id = "E1"` with `weapons = []`
- **THEN** it returns a message containing `"CombatComponent: 'E1' has no weapons"` and does not crash

#### Scenario: MovementController with zero speed
- **WHEN** `MovementController.validate()` runs against EntityData `id = "E1"` with `speed = 0`
- **THEN** it returns a message containing `"speed"` for `'E1'`

#### Scenario: FoundationComponent with zero foundation
- **WHEN** `FoundationComponent.validate()` runs against EntityData `id = "E1"` with `foundation = Vector2i(0, 0)`
- **THEN** it returns a message containing `"foundation"` for `'E1'`

#### Scenario: FactoryComponent with unknown queue type
- **WHEN** `FactoryComponent.validate()` runs against EntityData `id = "E1"` with `factory = "BogusType"`
- **THEN** it returns a message containing `"BogusType"` for `'E1'`

#### Scenario: FactoryComponent with known queue type
- **WHEN** `FactoryComponent.validate()` runs against EntityData with `factory = "InfantryType"`
- **THEN** it returns an empty array

#### Scenario: TransportComponent without dock for harvester
- **WHEN** `TransportComponent.validate()` runs against EntityData `id = "E1"` with `harvester = true`, `dock = ""`
- **THEN** it returns a message about the missing dock for `'E1'`

#### Scenario: StatsComponent with empty id
- **WHEN** `StatsComponent.validate()` runs against EntityData with `id = ""`
- **THEN** it returns a message containing `"id is empty"`

### Requirement: Graceful degradation
When validation fails, the entity SHALL still be created with whatever valid data
is available. Missing components SHALL be skipped rather than aborting entity
creation. `EntityFactory` SHALL iterate components independently so that a
warning or invalid data on one component does not prevent the remaining
components from being validated and configured.

#### Scenario: Entity with invalid weapons
- **WHEN** EntityData has `weapons = [WeaponData with damage=0]`
- **THEN** CombatComponent is added but the invalid weapon is logged as a warning and the entity is still created

#### Scenario: Entity with missing art data
- **WHEN** EntityData has `art_data = null`
- **THEN** ArtComponent is added with the default gray-box placeholder mesh

#### Scenario: One component warns, others still configure
- **WHEN** an entity's EntityData produces a warning from one component's `validate()`
- **THEN** the factory logs that warning and still configures every other component on the entity

## ADDED Requirements

### Requirement: TODO logging for unimplemented abilities
`SpecialAbilityComponent.validate(data)` SHALL emit a `TODO:` warning for each
enabled ability flag that is not yet implemented, so that `grep "TODO:"` reveals
the full list of pending abilities. The message format SHALL be
`"TODO: <ability> not implemented for '<id>'"`.

#### Scenario: Enabled unimplemented ability
- **WHEN** `SpecialAbilityComponent.validate()` runs against EntityData `id = "E1"` with `cloakable = true`
- **THEN** it returns a message `"TODO: cloakable not implemented for 'E1'"`

#### Scenario: No abilities enabled
- **WHEN** `SpecialAbilityComponent.validate()` runs against EntityData with all ability flags false
- **THEN** it returns an empty array
