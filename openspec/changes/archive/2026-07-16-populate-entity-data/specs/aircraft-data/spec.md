## ADDED Requirements

### Requirement: ORCA Orca Fighter entity data
The system SHALL provide an EntityData resource at `resources/entities/aircraft/gdi_orca.tres`
with the following TS-accurate stats: id="ORCA", display_name="Orca Fighter", entity_type=AIRCRAFT,
strength=200, armor="light", cost=1000, tech_level=5, sight=2, speed=20.0,
movement_zone="Fly", locomotor="Fly", owner=["GDI"], buildable=true.

#### Scenario: ORCA loads correctly
- **WHEN** EntityFactory scans `resources/entities/aircraft/`
- **THEN** entity with id="ORCA" is cached and returned by `get_entity_data("ORCA")`

#### Scenario: ORCA has correct type
- **WHEN** `get_all_by_type(EntityType.AIRCRAFT)` is called
- **THEN** result includes ORCA

### Requirement: APACHE Harpy entity data
The system SHALL provide an EntityData resource at `resources/entities/aircraft/nod_harpy.tres`
with the following TS-accurate stats: id="APACHE", display_name="Harpy", entity_type=AIRCRAFT,
strength=225, armor="light", cost=1000, tech_level=5, sight=2, speed=14.0,
movement_zone="Fly", locomotor="Fly", owner=["Nod"], buildable=true.

#### Scenario: APACHE loads correctly
- **WHEN** EntityFactory scans `resources/entities/aircraft/`
- **THEN** entity with id="APACHE" is cached and returned by `get_entity_data("APACHE")`

#### Scenario: APACHE has correct type
- **WHEN** `get_all_by_type(EntityType.AIRCRAFT)` is called
- **THEN** result includes APACHE
