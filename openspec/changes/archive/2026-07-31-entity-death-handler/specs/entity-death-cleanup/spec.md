## ADDED Requirements

### Requirement: All entities freed on health_zero
When any entity's `HealthComponent` emits `health_zero`, the entity SHALL be freed from the scene tree.

#### Scenario: Unit freed on death
- **WHEN** a unit's `HealthComponent.health_zero` signal fires
- **THEN** `queue_free()` is called on the entity node

#### Scenario: Building freed on death
- **WHEN** a building's `HealthComponent.health_zero` signal fires
- **THEN** `queue_free()` is called on the entity node (may be called by both EntityFactory lambda and BuildingManager handler)

#### Scenario: Entity without HealthComponent
- **WHEN** `create_entity()` creates an entity with `strength == 0` (no HealthComponent)
- **THEN** no death connection is made

### Requirement: BuildingManager cleans up registered buildings on death
When a building registered in `BuildingManager._buildings` has `health_zero` fire, BuildingManager SHALL perform full cleanup.

#### Scenario: Building death removes entry from BuildingManager
- **WHEN** a registered building's `health_zero` fires
- **THEN** the building entry is removed from `BuildingManager._buildings`

#### Scenario: Building death unregisters cells from SpatialHash
- **WHEN** a registered building's `health_zero` fires
- **THEN** its cells are unregistered from `SpatialHash` via `unregister_building_cells()`

#### Scenario: Building death unregisters bib cells from SpatialHash
- **WHEN** a registered building with bib cells has its `health_zero` fires
- **THEN** its bib cells are unregistered from `SpatialHash`

#### Scenario: Building death unregisters from PrerequisiteSystem
- **WHEN** a registered building's `health_zero` fires
- **THEN** it is unregistered from `PrerequisiteSystem` for the owning player

#### Scenario: Building death deselects from SelectionManager
- **WHEN** a registered building's `health_zero` fires
- **THEN** the building's `SelectComponent` is deselected from `SelectionManager` (if present)

### Requirement: BuildingManager emits building_destroyed signal
`BuildingManager` SHALL emit `building_destroyed(building: Node3D, entity_data: EntityData)` when a registered building is destroyed.

#### Scenario: Signal emitted on building death
- **WHEN** `_on_building_destroyed` processes a building
- **THEN** `building_destroyed` is emitted with the building node and its `EntityData`

#### Scenario: Signal emitted before queue_free
- **WHEN** `_on_building_destroyed` processes a building
- **THEN** `building_destroyed` is emitted before `queue_free()` is called

### Requirement: Map-loaded entities gracefully handled
Entities not registered in `BuildingManager._buildings` SHALL still be freed on death.

#### Scenario: Map-loaded entity freed via EntityFactory lambda
- **WHEN** an entity created by `MapLoader` (not in `BuildingManager._buildings`) has its `health_zero` fires
- **THEN** building-specific cleanup is skipped, and the entity is freed via EntityFactory's `queue_free()` lambda

### Requirement: Double-free is safe
Multiple paths calling `queue_free()` on the same entity SHALL not cause errors.

#### Scenario: Both EntityFactory and BuildingManager call queue_free
- **WHEN** a registered building's `health_zero` fires
- **THEN** both EntityFactory's lambda and BuildingManager's handler call `queue_free()`, which is safe (deferred, second call is no-op)
