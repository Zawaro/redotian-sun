## ADDED Requirements

### Requirement: ResourceGrowthSystem
The system SHALL provide a `ResourceGrowthSystem.gd` autoload that manages resource growth and spawning via two independent timers (tree timer and resource timer) with batched entity processing and cached entity lists. The system is registered in `project.godot` as `TiberiumGrowthSystem` autoload (name preserved for backward compatibility).

#### Scenario: MapEditor guard
- **WHEN** `ResourceGrowthSystem._physics_process()` runs in the Redot editor
- **THEN** it returns immediately without processing any growth (MapEditor is completely static)

#### Scenario: Entity list caching
- **WHEN** the system needs to iterate trees or resource entities
- **THEN** it uses cached lists rebuilt every `REBUILD_INTERVAL` seconds (5s) or when a timer fires

#### Scenario: Tree timer — spawn zone
- **WHEN** the tree timer fires and a tree has `node_count > 0`
- **THEN** the system iterates all cells within `tree_spawn_radius` of the tree (circular area, e.g. 3 = 7x7)
- **AND** for each cell: if resource exists → grow it; if empty → spawn new resource with `spawn_strength` health

#### Scenario: Tree timer — growth zone (contiguous spread)
- **WHEN** the tree timer fires
- **THEN** the system iterates all resource entities within `radius_cells` of the tree
- **AND** for each resource entity: tries to spread to its 8 adjacent neighbors
- **AND** if neighbor has resource → grow it; if empty → spawn new resource, increment entity's `spread_count`

#### Scenario: Tree timer batched processing
- **WHEN** there are more trees than `growth_batch_trees`
- **THEN** only `growth_batch_trees` trees are processed per tick, cycling through all trees over multiple ticks

#### Scenario: Resource timer fires
- **WHEN** the resource timer counts down to zero
- **THEN** the system processes up to `growth_batch_crystals` resource entities from the cached list

#### Scenario: Resource self-growth
- **WHEN** the resource timer fires and a resource entity has health < max_health
- **THEN** the entity's health increases by 5% of `max_health` per tick

#### Scenario: Resource spread count limit
- **WHEN** a resource entity has `spread_count >= spread_max`
- **THEN** the tree timer does not attempt to spread from this entity

#### Scenario: Randomized timer intervals
- **WHEN** a timer fires
- **THEN** the next interval is `base_interval + randf_range(-60, 60)` seconds (prevents mass growth events in single frame)

#### Scenario: Batched resource processing
- **WHEN** there are 100k resource entities on the map and `growth_batch_crystals = 500`
- **THEN** only 500 resource entities are processed per tick, cycling through all entities over multiple ticks

### Requirement: ResourceComponent spread tracking
ResourceComponent SHALL include a `spread_count: int = 0` field tracking how many times this resource entity has spread to new cells.

#### Scenario: Spread count incremented
- **WHEN** ResourceGrowthSystem spawns new resource from an existing entity's spread attempt
- **THEN** the source entity's `spread_count` increments by 1

#### Scenario: Spread count limit enforced
- **WHEN** a resource entity has `spread_count >= spread_max` (from GlobalRules)
- **THEN** ResourceGrowthSystem does not attempt to spread from this entity

### Requirement: ResourceTreeComponent configure method
ResourceTreeComponent SHALL implement a `configure(data: EntityData)` method that copies tree-spawner fields from EntityData into the component's exports.

#### Scenario: Configure from EntityData
- **WHEN** EntityFactory calls `configure(data)` on a ResourceTreeComponent with `spawned_entity_id = "TIB"`, `radius_cells = 8`, `node_count = 12`, `spawn_strength = 0.5`
- **THEN** the component stores these values for use by ResourceGrowthSystem

#### Scenario: No upfront spawn
- **WHEN** a ResourceTreeComponent enters the scene tree
- **THEN** it does NOT spawn resources automatically (map editor pre-populates; ResourceGrowthSystem handles growth)
