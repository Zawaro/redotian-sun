## ADDED Requirements

### Requirement: E2 Disc Thrower entity data
The system SHALL provide an EntityData resource at `resources/entities/infantry/e2_disc_thrower.tres`
with the following TS-accurate stats: id="E2", display_name="Disc Thrower", entity_type=INFANTRY,
strength=150, armor="none", cost=200, tech_level=2, sight=7, speed=4.0,
movement_zone="InfantryDestroyer", locomotor="Foot", owner=["GDI"], buildable=true.

#### Scenario: E2 loads correctly
- **WHEN** EntityFactory scans `resources/entities/infantry/`
- **THEN** entity with id="E2" is cached and returned by `get_entity_data("E2")`

#### Scenario: E2 has correct type
- **WHEN** `get_all_by_type(EntityType.INFANTRY)` is called
- **THEN** result includes E2

### Requirement: E3 Rocket Infantry entity data
The system SHALL provide an EntityData resource at `resources/entities/infantry/e3_rocket_infantry.tres`
with the following TS-accurate stats: id="E3", display_name="Rocket Infantry", entity_type=INFANTRY,
strength=100, armor="none", cost=250, tech_level=2, sight=7, speed=4.0,
movement_zone="InfantryDestroyer", locomotor="Foot", owner=["Nod"], buildable=true.

#### Scenario: E3 loads correctly
- **WHEN** EntityFactory scans `resources/entities/infantry/`
- **THEN** entity with id="E3" is cached and returned by `get_entity_data("E3")`

#### Scenario: E3 has correct type
- **WHEN** `get_all_by_type(EntityType.INFANTRY)` is called
- **THEN** result includes E3
