## ADDED Requirements

### Requirement: TiberiumTreeComponent
The system SHALL provide a `TiberiumTreeComponent.gd` (script-attached Node) for persistent tiberium spawners on the map. The tree SHALL be a TERRAIN-type EntityFactory entity with 1x1 true foundation, indestructible, and unselectable.

#### Scenario: Tree spawns crystals on ready
- **WHEN** a TiberiumTree with `spawned_entity_id = "TIB"`, `radius_cells = 8`, `node_count = 12`, `amount_per_node = 300` enters the scene tree
- **THEN** it spawns 12 Tiberium crystal entity instances within an 8-cell radius with 2-cell minimum spacing, each with `amount = 300`

#### Scenario: Tree persists after depletion
- **WHEN** all spawned crystals are depleted (harvested to amount = 0)
- **THEN** the tree entity remains on the map (foundation still occupied, visual still present)

#### Scenario: Tree foundation blocks everything
- **WHEN** a building is placed or a unit moves onto the tree's 1x1 foundation cell
- **THEN** both are blocked (true foundation)

#### Scenario: Crystal amount configured from tree
- **WHEN** a TiberiumTree spawns a crystal entity
- **THEN** the crystal's TiberiumComponent is configured with `amount = amount_per_node`, `max_amount = max_amount_per_node`, `tiberium_type` from the tree's parameters

#### Scenario: Green vs blue tiberium
- **WHEN** a TiberiumTree has `tiberium_type = 0`
- **THEN** spawned crystals have `tiberium_type = 0` (green)
- **WHEN** `tiberium_type = 1`
- **THEN** spawned crystals have `tiberium_type = 1` (blue)

#### Scenario: Multiple trees per map
- **WHEN** a map scene contains two TiberiumTree entities with different positions and types
- **THEN** both trees spawn their own crystals independently

#### Scenario: Zero node count spawns nothing
- **WHEN** a TiberiumTree has `node_count = 0`
- **THEN** no crystals are spawned (tree is empty/disabled)

### Requirement: TiberiumTree entity data
EntityData SHALL include fields for TiberiumTree configuration.

#### Scenario: Tree configuration
- **WHEN** an EntityData is created with `tiberium_tree = true`, `spawned_entity_id = "TIB"`, `radius_cells = 8`, `node_count = 12`, `amount_per_node = 300`, `max_amount_per_node = 300`, `regrowth_rate = -1.0`
- **THEN** the tree has full spawner configuration with default GlobalRules regrowth

#### Scenario: Tree is indestructible and unselectable
- **WHEN** a TiberiumTree entity is created
- **THEN** it has no HealthComponent, no SelectComponent, no HitboxComponent
