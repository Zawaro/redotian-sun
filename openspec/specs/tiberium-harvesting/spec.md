## ADDED Requirements

### Requirement: TiberiumComponent
The system SHALL provide a `TiberiumComponent.gd` (script-attached Node) for Tiberium crystal entities on the map. Crystals SHALL be `TERRAIN`-type entity instances with 1x1 pseudo-foundation (blocks building placement, allows unit movement).

#### Scenario: Configure Tiberium node
- **WHEN** a TiberiumComponent is configured with `amount = 500`, `max_amount = 500`, `tiberium_type = 0`, `regrowth_rate = -1.0`
- **THEN** the node has 500 current tiberium, 500 max, green type, and uses the GlobalRules default regrowth rate

#### Scenario: Deplete node
- **WHEN** `HarvestComponent` collects 50 tiberium from a node with `amount = 100`
- **THEN** the node's `amount` decreases to 50

#### Scenario: Depleted node returns zero
- **WHEN** a harvester attempts to collect from a node with `amount = 0`
- **THEN** the node returns 0 tiberium and the harvester seeks a new node

#### Scenario: Blue tiberium type
- **WHEN** a TiberiumComponent is configured with `tiberium_type = 1`
- **THEN** the node represents blue (Vinifera) tiberium

#### Scenario: Pseudo-foundation blocks building placement
- **WHEN** `BuildingManager.can_place()` checks a cell occupied by a TiberiumComponent entity
- **THEN** the cell is blocked for building placement

#### Scenario: Pseudo-foundation allows unit movement
- **WHEN** a unit paths through a cell occupied by a TiberiumComponent entity
- **THEN** the cell is NOT blocked for movement

#### Scenario: Visual stage 1 — low amount
- **WHEN** a TiberiumComponent has `amount <= max_amount * 0.33`
- **THEN** the entity shows 3 small cube mesh instances

#### Scenario: Visual stage 2 — medium amount
- **WHEN** a TiberiumComponent has `amount > max_amount * 0.33` and `amount <= max_amount * 0.66`
- **THEN** the entity shows 2 big cubes + 3 small cubes

#### Scenario: Visual stage 3 — full amount
- **WHEN** a TiberiumComponent has `amount > max_amount * 0.66`
- **THEN** the entity shows 5 big cubes

### Requirement: HarvestComponent
The system SHALL provide a `HarvestComponent.gd` (script-attached Node) for harvester behavior. It SHALL implement a state machine: IDLE → SEEK_NODE → APPROACH_NODE → HARVESTING → FULL → SEEK_REFINERY → APPROACH_REFINERY → DOCKING → UNLOADING → IDLE.

#### Scenario: Auto-seek nearest node when idle
- **WHEN** a HarvestComponent is in IDLE state with empty cargo and a Tiberium node exists within scan range
- **THEN** the harvester transitions to SEEK_NODE and navigates to the nearest node

#### Scenario: Collect tiberium from node
- **WHEN** a HarvestComponent is in HARVESTING state at a node with available tiberium
- **THEN** it fills cargo at `harvester_fill_rate` per second and the node depletes at the same rate

#### Scenario: Return when full
- **WHEN** cargo reaches `TransportComponent.storage` capacity
- **THEN** the HarvestComponent transitions to FULL state and seeks the nearest refinery with a DockComponent

#### Scenario: Return when node depleted
- **WHEN** the current Tiberium node reaches `amount = 0`
- **THEN** the HarvestComponent returns to IDLE and seeks a new node

#### Scenario: Dock at refinery
- **WHEN** a HarvestComponent reaches a refinery's `dock_position` with the correct `dock_rotation`
- **THEN** it transitions to DOCKING, then UNLOADING

#### Scenario: Unload cargo to credits
- **WHEN** a HarvestComponent is in UNLOADING state at a dock
- **THEN** cargo decreases at `DockComponent.unload_rate` per second and credits are added to the player's treasury

#### Scenario: Manual order to specific node
- **WHEN** a player left-clicks a Tiberium node with a harvester selected
- **THEN** the HarvestComponent targets that specific node, overriding auto-seek

#### Scenario: Manual order to dock at refinery
- **WHEN** a player left-clicks a building with DockComponent while a harvester is selected
- **THEN** the HarvestComponent targets that refinery for unloading

#### Scenario: Crystal search via scene tree
- **WHEN** a HarvestComponent searches for the nearest Tiberium crystal
- **THEN** it iterates entities in the "entities" group and filters by TiberiumComponent presence (NOT SpatialHash, which only tracks entities with MovementController)

### Requirement: DockComponent
The system SHALL provide a `DockComponent.gd` (script-attached Node) for buildings that accept docking entities (refineries, airpads, repair pads).

#### Scenario: Configure refinery dock
- **WHEN** a DockComponent is configured with `dock_position = Vector3(0, 0, -2)`, `dock_rotation = 180.0`, `allowed_entities = ["HARV"]`, `unload_rate = 28.0`
- **THEN** harvesters with `dock = "PROC"` can dock at this position, facing south, unloading at 28 tiberium/sec

#### Scenario: One harvester at a time
- **WHEN** a harvester is currently docking/unloading at a DockComponent
- **THEN** additional harvesters entering the dock range are added to the queue

#### Scenario: Queue processing
- **WHEN** the current harvester finishes unloading and departs
- **THEN** the next harvester in the queue is signalled to approach the dock position

#### Scenario: Allowed entities filter
- **WHEN** an entity with `dock = "REFN"` attempts to dock at a DockComponent with `allowed_entities = ["HARV"]`
- **THEN** the entity is rejected and not added to the queue

#### Scenario: Nearest occupied refinery queues rather than distant
- **WHEN** a harvester has two refineries in range: one nearby but occupied, one farther and free
- **THEN** the harvester queues at the nearby occupied refinery rather than traveling to the distant one

### Requirement: FoundationComponent bib cells
The system SHALL extend `FoundationComponent` with `bib_cells: PackedVector2i` defining cells within the foundation footprint that are traversable for dock interaction.

#### Scenario: Bib cells within foundation
- **WHEN** a FoundationComponent has `foundation = Vector2i(4,3)` and `bib_cells = [Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1), Vector2i(3, -1)]`
- **THEN** the bottom row of cells are registered as bib — passable for dock-queued entities

#### Scenario: Bib cells outside foundation are ignored
- **WHEN** a bib cell offset exceeds the foundation rectangle bounds
- **THEN** the cell is silently ignored during registration

### Requirement: EntityFactory wires economy components
The system SHALL extend `EntityFactory._add_components()` to attach TiberiumTreeComponent (if `data.tiberium_tree`), TiberiumComponent (if `data.tiberium_resource`), HarvestComponent (if `data.harvester`), and DockComponent (if dock position is set).

#### Scenario: Tiberium tree gets TiberiumTreeComponent
- **WHEN** an entity is created with `tiberium_tree = true`
- **THEN** the entity has a TiberiumTreeComponent child with values from EntityData

#### Scenario: Tiberium crystal gets TiberiumComponent
- **WHEN** an entity is created with `tiberium_resource = true`
- **THEN** the entity has a TiberiumComponent child with values from EntityData

#### Scenario: Harvester gets HarvestComponent
- **WHEN** an entity is created with `harvester = true`
- **THEN** the entity has a HarvestComponent child referencing its TransportComponent

#### Scenario: Refinery gets DockComponent
- **WHEN** an entity is created with a non-zero `dock_position`
- **THEN** the entity has a DockComponent child configured from EntityData

### Requirement: BuildingManager stub deduction + pseudo-foundation check
The system SHALL call `EconomyManager.deduct()` in `BuildingManager.place_building()` as a temporary measure. The system SHALL also check for TiberiumComponent entities in `BuildingManager.can_place()` footprint cells (pseudo-foundation).

#### Scenario: Building placement deducts credits
- **WHEN** `BuildingManager.place_building()` is called with a building costing 2000
- **THEN** `EconomyManager.deduct()` is called for 2000

#### Scenario: Pseudo-foundation blocks building placement
- **WHEN** `BuildingManager.can_place()` checks a footprint cell containing an entity with TiberiumComponent
- **THEN** the cell is considered blocked and placement is rejected
