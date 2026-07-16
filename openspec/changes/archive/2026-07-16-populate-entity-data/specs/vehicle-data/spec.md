## ADDED Requirements

### Requirement: BIKE Attack Cycle entity data
The system SHALL provide an EntityData resource at `resources/entities/vehicles/nod_attack_cycle.tres`
with the following TS-accurate stats: id="BIKE", display_name="Attack Cycle", entity_type=VEHICLE,
strength=150, armor="wood", cost=600, tech_level=5, sight=5, speed=12.0,
movement_zone="Destroyer", locomotor="Wheel", owner=["Nod"], buildable=true.

#### Scenario: BIKE loads correctly
- **WHEN** EntityFactory scans `resources/entities/vehicles/`
- **THEN** entity with id="BIKE" is cached and returned by `get_entity_data("BIKE")`

#### Scenario: BIKE has correct type
- **WHEN** `get_all_by_type(EntityType.VEHICLE)` is called
- **THEN** result includes BIKE

### Requirement: APC Amphibious APC entity data
The system SHALL provide an EntityData resource at `resources/entities/vehicles/gdi_apc.tres`
with the following TS-accurate stats: id="APC", display_name="Amphibious APC", entity_type=VEHICLE,
strength=200, armor="heavy", cost=800, tech_level=6, sight=5, speed=8.0,
movement_zone="AmphibiousCrusher", locomotor="Track", owner=["GDI"], buildable=true,
passengers=5.

#### Scenario: APC loads correctly
- **WHEN** EntityFactory scans `resources/entities/vehicles/`
- **THEN** entity with id="APC" is cached and returned by `get_entity_data("APC")`

#### Scenario: APC has correct type
- **WHEN** `get_all_by_type(EntityType.VEHICLE)` is called
- **THEN** result includes APC
