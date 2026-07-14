## ADDED Requirements

### Requirement: TiberiumGrowthSystem
The system SHALL provide a `TiberiumGrowthSystem.gd` autoload that manages tiberium growth and spawning via two independent timers (tree timer and tiberium timer) with batched entity processing and cached entity lists.

#### Scenario: MapEditor guard
- **WHEN** `TiberiumGrowthSystem._physics_process()` runs in the Redot editor
- **THEN** it returns immediately without processing any growth (MapEditor is completely static)

#### Scenario: Entity list caching
- **WHEN** the system needs to iterate trees or tiberium entities
- **THEN** it uses cached lists rebuilt every `REBUILD_INTERVAL` seconds (5s) or when a timer fires

#### Scenario: Tree timer — spawn zone
- **WHEN** the tree timer fires and a tree has `node_count > 0`
- **THEN** the system iterates all cells within `tree_spawn_radius` of the tree (circular area, e.g. 3 = 7x7)
- **AND** for each cell: if tiberium exists → grow it; if empty → spawn new tiberium with `spawn_strength` health

#### Scenario: Tree timer — growth zone (contiguous spread)
- **WHEN** the tree timer fires
- **THEN** the system iterates all tiberium entities within `radius_cells` of the tree
- **AND** for each tiberium entity: tries to spread to its 8 adjacent neighbors
- **AND** if neighbor has tiberium → grow it; if empty → spawn new tiberium, increment entity's `spread_count`

#### Scenario: Tree timer batched processing
- **WHEN** there are more trees than `growth_batch_trees`
- **THEN** only `growth_batch_trees` trees are processed per tick, cycling through all trees over multiple ticks

#### Scenario: Tiberium timer fires
- **WHEN** the tiberium timer counts down to zero
- **THEN** the system processes up to `growth_batch_crystals` tiberium entities from the cached list

#### Scenario: Tiberium self-growth
- **WHEN** the tiberium timer fires and a tiberium entity has `amount < max_amount`
- **THEN** the entity's amount increases by 5% of `max_amount` per tick

#### Scenario: Tiberium spread count limit
- **WHEN** a tiberium entity has `spread_count >= spread_max`
- **THEN** the tree timer does not attempt to spread from this entity

#### Scenario: Full-growth speed bonus
- **WHEN** a tiberium entity has `amount >= max_amount` (fully grown)
- **THEN** the tiberium timer interval is multiplied by `full_growth_speed_bonus` (0.5 = ticks twice as fast)

#### Scenario: Randomized timer intervals
- **WHEN** a timer fires
- **THEN** the next interval is `base_interval + randf_range(-60, 60)` seconds (prevents mass growth events in single frame)

#### Scenario: Batched tiberium processing
- **WHEN** there are 100k tiberium entities on the map and `growth_batch_crystals = 500`
- **THEN** only 500 tiberium entities are processed per tick, cycling through all entities over multiple ticks

### Requirement: TiberiumComponent spread tracking
TiberiumComponent SHALL include a `spread_count: int = 0` field tracking how many times this tiberium entity has spread to new cells.

#### Scenario: Spread count incremented
- **WHEN** TiberiumGrowthSystem spawns new tiberium from an existing entity's spread attempt
- **THEN** the source entity's `spread_count` increments by 1

#### Scenario: Spread count limit enforced
- **WHEN** a tiberium entity has `spread_count >= spread_max` (from GlobalRules)
- **THEN** TiberiumGrowthSystem does not attempt to spread from this entity

### Requirement: TiberiumTreeComponent configure method
TiberiumTreeComponent SHALL implement a `configure(data: EntityData)` method that copies tree-spawner fields from EntityData into the component's exports.

#### Scenario: Configure from EntityData
- **WHEN** EntityFactory calls `configure(data)` on a TiberiumTreeComponent with `spawned_entity_id = "TIB"`, `radius_cells = 8`, `node_count = 12`, `spawn_strength = 300`
- **THEN** the component stores these values for use by TiberiumGrowthSystem

#### Scenario: No upfront spawn
- **WHEN** a TiberiumTreeComponent enters the scene tree
- **THEN** it does NOT spawn tiberium automatically (map editor pre-populates; TiberiumGrowthSystem handles growth)
