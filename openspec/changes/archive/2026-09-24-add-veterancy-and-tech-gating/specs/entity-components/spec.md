## ADDED Requirements

### Requirement: StatsComponent trainable and rank state
`StatsComponent` SHALL expose `trainable: bool` and the rank fields described by the `veterancy` capability (`experience`, derived `veteran_level`, `veterancy_changed`). `trainable` SHALL default from entity type when `EntityData.configure` runs: infantry, vehicles and aircraft are trainable; buildings are not. A building MAY opt in by setting `EntityData.trainable = true`. This default follows OpenTS (`Trainable=yes` for unit types, `no` for buildings).

#### Scenario: Unit types are trainable by default
- **WHEN** an infantry, vehicle or aircraft entity is created without an explicit `trainable` flag
- **THEN** its `StatsComponent.trainable` is true

#### Scenario: Buildings are not trainable by default
- **WHEN** a building entity is created without an explicit `trainable` flag
- **THEN** its `StatsComponent.trainable` is false

#### Scenario: Non-unit, non-building types are not trainable
- **WHEN** a terrain, overlay or smudge entity is created
- **THEN** its `StatsComponent.trainable` is false

#### Scenario: Defensive building opts in
- **WHEN** a building's `EntityData.trainable` is true
- **THEN** its `StatsComponent.trainable` is true

### Requirement: StatsComponent entity-type helpers
`StatsComponent` SHALL expose `is_unit()`, `is_infantry()`, `is_vehicle()`, `is_structure()` and `is_aircraft()` predicates resolving against `entity_type`. `is_unit()` SHALL be true for infantry, vehicles and aircraft. A static `is_unit_type(entity_type: int)` SHALL provide the same mobile-unit test for data-only call sites that have no `StatsComponent` instance. Existing call sites that inline the mobile-unit comparison SHALL use the shared unit predicate instead.

#### Scenario: Unit predicate covers mobile types
- **WHEN** `is_unit()` is called on an infantry, vehicle or aircraft entity
- **THEN** it returns true

#### Scenario: Unit predicate excludes buildings and terrain
- **WHEN** `is_unit()` is called on a building or terrain entity
- **THEN** it returns false

#### Scenario: Airframe predicate is specific
- **WHEN** `is_aircraft()` is called on an infantry entity
- **THEN** it returns false
