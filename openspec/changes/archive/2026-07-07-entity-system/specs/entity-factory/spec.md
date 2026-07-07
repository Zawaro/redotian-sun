## ADDED Requirements

### Requirement: EntityFactory creates entities from data
The system SHALL provide an `EntityFactory.gd` autoload singleton that creates entities from EntityData resources. The factory SHALL instantiate a base `Entity.tscn` scene and add components dynamically based on data properties.

#### Scenario: Create infantry entity
- **WHEN** `EntityFactory.create_entity("E1")` is called
- **THEN** the factory looks up EntityData with id "E1", instantiates Entity.tscn, adds StatsComponent, HealthComponent, HitboxComponent, SelectComponent, MovementController, CombatComponent, ArtComponent, and returns the configured entity

#### Scenario: Create terrain entity
- **WHEN** `EntityFactory.create_entity("TREE01")` is called
- **THEN** the factory instantiates Entity.tscn, adds StatsComponent, HealthComponent (if strength > 0), HitboxComponent, FoundationComponent, ArtComponent — but NOT SelectComponent (entity_type = TERRAIN)

#### Scenario: Create building entity
- **WHEN** `EntityFactory.create_entity("GAPOWR")` is called
- **THEN** the factory instantiates Entity.tscn, adds StatsComponent, HealthComponent, HitboxComponent, SelectComponent, FoundationComponent, PowerComponent, ArtComponent, and returns the configured entity

### Requirement: Component addition rules
The factory SHALL add components based on these rules:
- StatsComponent: ALWAYS
- HealthComponent: if `strength > 0`
- HitboxComponent: ALWAYS
- SelectComponent: if `entity_type != TERRAIN`
- CombatComponent: if `weapons.size() > 0`
- MovementController: if `speed > 0`
- FoundationComponent: if `foundation != Vector2i(1,1)`
- PowerComponent: if `power != 0` or `powered == true`
- RadarComponent: if `radar == true`
- FactoryComponent: if `factory != ""`
- TransportComponent: if `passengers > 0` or `harvester == true`
- SpecialAbilityComponent: if any ability flag is true
- ArtComponent: ALWAYS

#### Scenario: Minimal entity (terrain rock)
- **WHEN** EntityData has `entity_type = TERRAIN`, `strength = 0`, `foundation = Vector2i(1,1)`, `speed = 0`, `weapons = []`
- **THEN** entity gets only StatsComponent, HitboxComponent, ArtComponent

#### Scenario: Full entity (Nod Buggy)
- **WHEN** EntityData has `entity_type = VEHICLE`, `strength = 220`, `speed = 10`, `weapons = [raider_cannon]`, `foundation = Vector2i(1,1)`
- **THEN** entity gets StatsComponent, HealthComponent, HitboxComponent, SelectComponent, CombatComponent, MovementController, ArtComponent

### Requirement: Component wiring
The factory SHALL wire component references programmatically after instantiation. HitboxComponent and SelectComponent SHALL receive a NodePath reference to HealthComponent.

#### Scenario: Health component reference wiring
- **WHEN** an entity has both HealthComponent and HitboxComponent
- **THEN** HitboxComponent.health_component is set to the HealthComponent node

### Requirement: Map override support (deferred)
The factory SHALL accept an optional `overrides: Dictionary` parameter. When provided, the factory SHALL duplicate the EntityData and override specified fields before creating the entity.

#### Scenario: Override entity strength
- **WHEN** `EntityFactory.create_entity("BGGY", {"strength": 300})` is called
- **THEN** the entity is created with strength 300 instead of the base 220

### Requirement: Mod/DLC data set registration
The factory SHALL provide `register_data_set(path: String)` to load additional EntityData resources from a directory. Later-loaded sets SHALL override earlier ones for the same entity id.

#### Scenario: Mod overrides base entity
- **WHEN** `register_data_set("res://mods/mymod/entities/")` is called after base data is loaded
- **THEN** any EntityData in the mod directory with matching id overrides the base version

### Requirement: EntityFactory caching
The factory SHALL cache loaded EntityData resources by id for fast lookup.

#### Scenario: Repeated entity creation
- **WHEN** `create_entity("E1")` is called 10 times
- **THEN** EntityData is loaded once and cached, not re-loaded from disk each time
