## ADDED Requirements

### Requirement: EntityFactory creates entities from data
The system SHALL provide an `EntityFactory.gd` autoload singleton that creates entities from EntityData resources. The factory SHALL instantiate a base scene and add components dynamically based on data properties.

#### Scenario: Create infantry entity
- **WHEN** `EntityFactory.create_entity("E1")` is called
- **THEN** the factory looks up EntityData with id "E1", instantiates a base scene, adds StatsComponent, HealthComponent, HitboxComponent, SelectComponent, MovementController, CombatComponent, ArtComponent, and returns the configured entity

#### Scenario: Create terrain entity
- **WHEN** `EntityFactory.create_entity("TREE01")` is called
- **THEN** the factory instantiates a base scene, adds StatsComponent, HealthComponent (if strength > 0), HitboxComponent, FoundationComponent, ArtComponent — but NOT SelectComponent (entity_type = TERRAIN)

#### Scenario: Create building entity
- **WHEN** `EntityFactory.create_entity("GAPOWR")` is called
- **THEN** the factory instantiates a base scene, adds StatsComponent, HealthComponent, HitboxComponent, SelectComponent, FoundationComponent, PowerComponent, ArtComponent, and returns the configured entity

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
- FactoryComponent: if `buildable_queue != ""`
- TransportComponent: if `passengers > 0` or `harvester == true`
- SpecialAbilityComponent: if any ability flag is true
- ArtComponent: if `resource_category != "tiberium"` (skipped for tiberium resource entities)
- ResourceTreeComponent: if `spawned_entity_id != ""`
- ResourceComponent: if `resource_category != ""`
- HarvestComponent: if `harvester == true`
- DockHostComponent: if `dock_position != Vector3.ZERO`
- DockClientComponent: if `dock != ""`
- DockUnloadComponent: if `dock_unload == true`
- FreeUnitComponent: if `free_unit != ""`

#### Scenario: Minimal entity (terrain rock)
- **WHEN** EntityData has `entity_type = TERRAIN`, `strength = 0`, `foundation = Vector2i(1,1)`, `speed = 0`, `weapons = []`
- **THEN** entity gets only StatsComponent, HitboxComponent, ArtComponent

#### Scenario: Full entity (Nod Buggy)
- **WHEN** EntityData has `entity_type = VEHICLE`, `strength = 220`, `speed = 10`, `weapons = [raider_cannon]`, `foundation = Vector2i(1,1)`
- **THEN** entity gets StatsComponent, HealthComponent, HitboxComponent, SelectComponent, CombatComponent, MovementController, ArtComponent

#### Scenario: Harvester entity
- **WHEN** EntityData has `harvester = true`, `dock = "PROC"`, `storage = 1`, `speed = 5.0`
- **THEN** entity gets StatsComponent, HealthComponent, HitboxComponent, SelectComponent, MovementController, TransportComponent, HarvestComponent, DockClientComponent, ArtComponent

#### Scenario: Refinery entity
- **WHEN** EntityData has `dock_position = Vector3(6, 0, 2)`, `dock_unload = true`, `accepted_resource_categories = ["tiberium"]`, `free_unit = "HARV"`
- **THEN** entity gets StatsComponent, HealthComponent, HitboxComponent, SelectComponent, FoundationComponent, DockHostComponent, DockUnloadComponent, FreeUnitComponent, ArtComponent

#### Scenario: Resource crystal entity
- **WHEN** EntityData has `resource_category = "tiberium"`, `resource_type_id = "tiberium_green"`, `strength = 300`
- **THEN** entity gets StatsComponent, HealthComponent, ResourceComponent, ArtComponent (no SelectComponent — entity_type = TERRAIN)

#### Scenario: Resource tree entity
- **WHEN** EntityData has `spawned_entity_id = "TIB"`, `radius_cells = 8`, `node_count = 12`
- **THEN** entity gets StatsComponent, FoundationComponent, ResourceTreeComponent, ArtComponent (no HealthComponent if strength = 0, no SelectComponent)

### Requirement: Component wiring
The factory SHALL wire component references programmatically after instantiation. HitboxComponent and SelectComponent SHALL receive a reference to HealthComponent.

#### Scenario: Health component reference wiring
- **WHEN** an entity has both HealthComponent and HitboxComponent
- **THEN** HitboxComponent.health_component is set to the HealthComponent node

### Requirement: EntityFactory caching
The factory SHALL cache loaded EntityData resources by id for fast lookup. The factory SHALL provide `get_all_by_type(entity_type: EntityType) -> Array[EntityData]` to query cached entities by category.

#### Scenario: Repeated entity creation
- **WHEN** `create_entity("E1")` is called 10 times
- **THEN** EntityData is loaded once and cached, not re-loaded from disk each time

#### Scenario: Query entities by type
- **WHEN** `get_all_by_type(EntityData.EntityType.BUILDING)` is called
- **THEN** the factory returns an Array[EntityData] containing all cached entities where `entity_type == BUILDING`

#### Scenario: Query returns empty for no matches
- **WHEN** `get_all_by_type(EntityData.EntityType.AIRCRAFT)` is called and no aircraft entities are cached
- **THEN** the factory returns an empty array

#### Scenario: Query includes all subdirectories
- **WHEN** EntityData files exist in `resources/entities/structures/gdi/` and `resources/entities/structures/nod/`
- **THEN** `get_all_by_type(BUILDING)` returns entities from both directories

#### Scenario: Invalid entity id
- **WHEN** `create_entity("INVALID_ID")` is called and no matching EntityData exists
- **THEN** the factory returns null and logs an error

#### Scenario: Base scene missing
- **WHEN** `Entity.tscn` is not found at the expected path
- **THEN** the factory logs an error and returns null
