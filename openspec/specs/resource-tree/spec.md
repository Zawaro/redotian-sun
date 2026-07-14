## ADDED Requirements

### Requirement: ResourceTreeComponent
The system SHALL provide a `ResourceTreeComponent.gd` (script-attached Node) for persistent resource spawners on the map. The tree SHALL be a TERRAIN-type EntityFactory entity with 1x1 true foundation, indestructible, and unselectable.

#### Scenario: Tree is configured from EntityData
- **WHEN** a ResourceTreeComponent receives `configure(data)` with `spawned_entity_id = "TIB"`, `radius_cells = 8`, `node_count = 12`, `spawn_strength = 0.5`
- **THEN** the component stores these values for use by ResourceGrowthSystem

#### Scenario: Tree persists after depletion
- **WHEN** all resource crystals around the tree are depleted (harvested to 0 health)
- **THEN** the tree entity remains on the map (foundation still occupied, visual still present)

#### Scenario: Tree foundation blocks everything
- **WHEN** a building is placed or a unit moves onto the tree's 1x1 foundation cell
- **THEN** both are blocked (true foundation)

#### Scenario: Multiple trees per map
- **WHEN** a map scene contains two ResourceTree entities with different positions and types
- **THEN** both trees are managed independently by ResourceGrowthSystem

#### Scenario: Zero node count disables spawning
- **WHEN** a ResourceTree has `node_count = 0`
- **THEN** ResourceGrowthSystem does not spawn crystals for this tree

### Requirement: ResourceTree entity data
EntityData SHALL include fields for ResourceTree configuration.

#### Scenario: Tree configuration
- **WHEN** an EntityData is created with `spawned_entity_id = "TIB"`, `radius_cells = 8`, `node_count = 12`, `spawn_strength = 0.5`, `max_spawn_strength = 1.0`, `regrowth_rate = -1.0`
- **THEN** the tree has full spawner configuration with default GlobalRules regrowth

#### Scenario: Tree is indestructible and unselectable
- **WHEN** a ResourceTree entity is created
- **THEN** it has no HealthComponent, no SelectComponent, no HitboxComponent

### Requirement: ResourceGrowthSystem
The system SHALL provide a `ResourceGrowthSystem.gd` autoload that manages resource growth and spawning via two independent timers (tree timer and crystal timer) with batched entity processing. The autoload is registered as `TiberiumGrowthSystem` in `project.godot` for backward compatibility.

#### Scenario: MapEditor guard
- **WHEN** `ResourceGrowthSystem._physics_process()` runs in the Redot editor
- **THEN** it returns immediately without processing any growth (MapEditor is completely static)

#### Scenario: Tree timer spawns crystals
- **WHEN** the tree timer fires and a ResourceTree has `node_count > 0`
- **THEN** the system picks a random cell within `radius_cells` and either grows existing resource or spawns a new crystal with `spawn_strength` health

#### Scenario: Tree timer batched processing
- **WHEN** the tree timer fires with 30 trees on the map and `growth_batch_trees = 10`
- **THEN** only 10 trees are processed per tick, cycling through all trees over multiple ticks

#### Scenario: Crystal timer self-growth
- **WHEN** the crystal timer fires and a crystal has health < max_health
- **THEN** the crystal's health increases toward max_health

#### Scenario: Crystal timer spread to adjacent cell
- **WHEN** the crystal timer fires and a crystal has `spread_count < spread_max`
- **THEN** the system picks a random adjacent cell and either grows existing resource or spawns a new crystal with `spread_amount` resource, incrementing `spread_count`

#### Scenario: Crystal spread count limit
- **WHEN** a crystal has `spread_count >= spread_max`
- **THEN** the crystal only self-grows, never spreads

#### Scenario: Crystal timer batched processing
- **WHEN** the crystal timer fires with 500 crystals on the map and `growth_batch_crystals = 50`
- **THEN** only 50 crystals are processed per tick, cycling through all crystals over multiple ticks
