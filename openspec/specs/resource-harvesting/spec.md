## ADDED Requirements

### Requirement: ResourceComponent
The system SHALL provide a `ResourceComponent.gd` (script-attached Node) for harvestable resource entities on the map. Resources SHALL be `TERRAIN`-type entity instances with 1x1 pseudo-foundation (blocks building placement, allows unit movement). ResourceComponent SHALL use `resource_type_id: String` to identify the resource sub-type. Resource amount is backed by HealthComponent — `get_amount()` returns `health_ratio`, `collect()` calls `take_damage()` proportional to bales.

#### Scenario: Configure resource node
- **WHEN** a ResourceComponent is configured with `resource_type_id = "tiberium_green"`, `regrowth_rate = -1.0`
- **THEN** the node represents green tiberium and uses the GlobalRules default regrowth rate

#### Scenario: Deplete node
- **WHEN** `HarvestComponent` collects 0.5 bales from a node with HealthComponent at full health
- **THEN** the node's health decreases proportionally

#### Scenario: Depleted node returns zero
- **WHEN** a harvester attempts to collect from a node with `current_health = 0`
- **THEN** the node returns 0 bales and the harvester seeks a new node

#### Scenario: Blue resource type
- **WHEN** a ResourceComponent is configured with `resource_type_id = "tiberium_blue"`
- **THEN** the node represents blue (Vinifera) tiberium

#### Scenario: Pseudo-foundation blocks building placement
- **WHEN** `BuildingManager.can_place()` checks a cell occupied by a ResourceComponent entity
- **THEN** the cell is blocked for building placement

#### Scenario: Pseudo-foundation allows unit movement
- **WHEN** a unit paths through a cell occupied by a ResourceComponent entity
- **THEN** the cell is NOT blocked for movement

#### Scenario: Visual stage 1 — low amount
- **WHEN** a ResourceComponent has health ratio <= 0.33
- **THEN** the entity shows 3 small cube mesh instances

#### Scenario: Visual stage 2 — medium amount
- **WHEN** a ResourceComponent has health ratio > 0.33 and <= 0.66
- **THEN** the entity shows 2 big cubes + 3 small cubes

#### Scenario: Visual stage 3 — full amount
- **WHEN** a ResourceComponent has health ratio > 0.66
- **THEN** the entity shows 5 big cubes

### Requirement: HarvestComponent
The system SHALL provide a `HarvestComponent.gd` (script-attached Node) for harvester behavior. It SHALL implement a state machine: IDLE → SEEK_NODE → HARVESTING → FULL → DOCKING → UNLOADING → QUEUED → IDLE. HarvestComponent SHALL delegate dock-finding to DockClientComponent and support multiple resource categories via `harvestable_types`.

#### Scenario: Auto-seek nearest resource when idle
- **WHEN** a HarvestComponent is in IDLE state with empty cargo and a resource node exists within scan range matching `harvestable_types`
- **THEN** the harvester transitions to SEEK_NODE and navigates to the nearest matching node

#### Scenario: Collect resource from node
- **WHEN** a HarvestComponent is in HARVESTING state at a node with available resource
- **THEN** it fills cargo at `GlobalRules.harvester_fill_rate` per second and the node depletes at the same rate

#### Scenario: Return when full
- **WHEN** cargo reaches `TransportComponent.storage` capacity
- **THEN** the HarvestComponent transitions to FULL state and delegates to DockClientComponent

#### Scenario: Return when node depleted
- **WHEN** the current resource node is depleted (HealthComponent at 0)
- **THEN** the HarvestComponent returns to IDLE and seeks a new node

#### Scenario: Dock at refinery via DockClientComponent
- **WHEN** a HarvestComponent is in FULL state and DockClientComponent emits `dock_slot_reserved`
- **THEN** the harvester transitions to DOCKING and navigates to the dock position

#### Scenario: Queue when all hosts full
- **WHEN** DockClientComponent emits `dock_slot_failed`
- **THEN** the HarvestComponent transitions to QUEUED state

#### Scenario: Manual order to specific node
- **WHEN** a player left-clicks a resource node with a harvester selected
- **THEN** the HarvestComponent targets that specific node, overriding auto-seek

#### Scenario: Manual order to dock at refinery
- **WHEN** a player left-clicks a building with DockHostComponent while a harvester is selected
- **THEN** the HarvestComponent targets that refinery for unloading

#### Scenario: Category-based resource filtering
- **WHEN** HarvestComponent has `harvestable_types = ["tiberium"]` and nodes of type "tiberium_green" and "vein" exist
- **THEN** only "tiberium_green" nodes are considered (category "tiberium" matches via GlobalRules.get_resource_category())

#### Scenario: Player move command stops harvesting
- **WHEN** a player issues a move command to a harvester in any state
- **THEN** `cancel_harvest(true)` is called, resetting to IDLE with `_player_commanded = true`, preventing auto-seek until a new harvest order is issued

#### Scenario: Cell reservation during harvest
- **WHEN** a harvester begins seeking a resource node
- **THEN** the cell is reserved in SpatialHash to prevent other harvesters from targeting the same cell

### Requirement: DockHostComponent
The system SHALL provide a `DockHostComponent.gd` (script-attached Node) for buildings that accept docking entities (refineries, airpads, repair pads). It SHALL manage a FIFO queue of dock clients, reserve/release the dock cell in SpatialHash, and emit signals when clients dock or undock.

#### Scenario: Configure dock host
- **WHEN** a DockHostComponent is configured with `dock_position = Vector3(6, 0, 2)`, `dock_rotation = -90.0`, `dock_types = ["harvest"]`, `max_queue_length = 3`
- **THEN** the component accepts up to 3 queued clients of type "harvest"

#### Scenario: Immediate dock on empty slot
- **WHEN** a client calls `request_dock()` and `current_docker == null`
- **THEN** the client becomes the current docker, `docker_docked` emits immediately, and the dock cell is reserved in SpatialHash

#### Scenario: Queue when occupied
- **WHEN** a client calls `request_dock()` and `current_docker != null` and `queue.size() < max_queue_length`
- **THEN** the client is appended to the queue and `request_dock()` returns false

#### Scenario: Reject when queue full
- **WHEN** a client calls `request_dock()` and `queue.size() >= max_queue_length`
- **THEN** `request_dock()` returns false and the client is not added to the queue

#### Scenario: Wait timer for queued clients
- **WHEN** a client enters the queue and `dock_wait_ticks = 10`
- **THEN** the component waits 10 ticks before emitting `docker_docked` and calling `on_slot_available()` on the next client

#### Scenario: Leave dock releases cell
- **WHEN** the current docker calls `leave_dock()` or is removed
- **THEN** the dock cell is released in SpatialHash, `docker_undocked` emits, and the next queued client becomes current

#### Scenario: Foundation read from sibling
- **WHEN** DockHostComponent needs the building's foundation size
- **THEN** it reads from FoundationComponent sibling via `_get_foundation()`

### Requirement: DockClientComponent
The system SHALL provide a `DockClientComponent.gd` (script-attached Node) for entities that dock at DockHostComponent buildings. It SHALL handle host discovery, reservation-before-movement, and occupancy-aware selection.

#### Scenario: Configure dock client
- **WHEN** a DockClientComponent is configured with `can_dock_with = ["PROC"]`
- **THEN** the component searches for buildings with entity ID "PROC"

#### Scenario: Find nearest host
- **WHEN** `find_nearest_host(parent)` is called
- **THEN** it searches the "Buildings" group for entities with DockHostComponent where entity ID is in `can_dock_with`, applying `occupancy_penalty` to distance

#### Scenario: Reserve before movement
- **WHEN** `seek_dock(parent)` is called
- **THEN** it finds the nearest host, calls `request_dock()`, and if successful emits `dock_slot_reserved` with the host node

#### Scenario: Try next host on failure
- **WHEN** `seek_dock()` fails at the nearest host (queue full)
- **THEN** it tries the next nearest host via `_find_shorter_queue()`, repeating until one succeeds or all are tried

#### Scenario: Emit dock_slot_failed
- **WHEN** `seek_dock()` fails at all reachable hosts
- **THEN** it emits `dock_slot_failed`

#### Scenario: Release reservation
- **WHEN** `release_reservation()` is called and a host is reserved
- **THEN** it calls `leave_dock()` on the host's DockHostComponent

#### Scenario: On slot available callback
- **WHEN** the reserved host emits `slot_available` and the client is queued
- **THEN** DockClientComponent calls `on_slot_available()` which re-triggers dock acquisition

### Requirement: DockUnloadComponent
The system SHALL provide a `DockUnloadComponent.gd` (script-attached Node) for buildings that unload cargo from docked entities. It SHALL drain cargo from TransportComponent at `unload_rate` per second, look up `ResourceType.value` for each cargo type, and add credits to EconomyManager.

#### Scenario: Unload single-type cargo
- **WHEN** a dock client has cargo `{"tiberium_green": 100}` and `value_per_unit = 1.0`
- **THEN** 100 credits are added to the player's treasury

#### Scenario: Unload multi-type cargo
- **WHEN** a dock client has cargo `{"tiberium_green": 300, "tiberium_blue": 100}` with values 1.0 and 2.0
- **THEN** `300 * 1.0 + 100 * 2.0 = 500` credits are added

#### Scenario: Leave dock when empty
- **WHEN** cargo reaches 0.0 after unloading
- **THEN** DockUnloadComponent calls `dock.leave_dock(docker_node)`

### Requirement: RefineryComponent
The system SHALL provide a `RefineryComponent.gd` (script-attached Node) for buildings that accept resource cargo from dock clients. It SHALL declare which resource categories the building accepts.

#### Scenario: Configure refinery
- **WHEN** a RefineryComponent is configured with `accepted_resource_categories = ["tiberium"]`, `unload_rate = 2.33`
- **THEN** the building accepts tiberium category resources

#### Scenario: Accept matching resource
- **WHEN** a dock client has cargo with resource_type_id "tiberium_green" and the refinery has `accepted_resource_categories = ["tiberium"]`
- **THEN** the resource is accepted (its category "tiberium" matches)

### Requirement: FoundationComponent bib cells
The system SHALL extend `FoundationComponent` with `bib_cells: PackedVector2i` defining cells within the foundation footprint that are traversable for dock interaction.

#### Scenario: Bib cells within foundation
- **WHEN** a FoundationComponent has `foundation = Vector2i(4,3)` and `bib_cells = [Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2)]`
- **THEN** the specified cells are registered as bib — passable for dock-queued entities

#### Scenario: Bib cells outside foundation are ignored
- **WHEN** a bib cell offset exceeds the foundation rectangle bounds
- **THEN** the cell is silently ignored during registration

### Requirement: EntityFactory wires economy components
The system SHALL extend `EntityFactory._add_components()` to attach ResourceTreeComponent (if `data.spawned_entity_id != ""`), ResourceComponent (if `data.resource_category != ""`), HarvestComponent (if `data.harvester`), DockHostComponent (if `data.dock_position != Vector3.ZERO`), DockClientComponent (if `data.dock != ""`), DockUnloadComponent (if `data.dock_unload`), RefineryComponent (if `data.accepted_resource_categories.size() > 0`), and FreeUnitComponent (if `data.free_unit != ""`).

#### Scenario: Resource tree gets ResourceTreeComponent
- **WHEN** an entity is created with `spawned_entity_id = "TIB"`
- **THEN** the entity has a ResourceTreeComponent child with values from EntityData

#### Scenario: Resource crystal gets ResourceComponent
- **WHEN** an entity is created with `resource_category = "tiberium"`
- **THEN** the entity has a ResourceComponent child with `resource_type_id` from EntityData

#### Scenario: Harvester gets HarvestComponent and DockClientComponent
- **WHEN** an entity is created with `harvester = true` and `dock = "PROC"`
- **THEN** the entity has a HarvestComponent child and a DockClientComponent child with `can_dock_with = ["PROC"]`

#### Scenario: Refinery gets DockHostComponent, DockUnloadComponent, and RefineryComponent
- **WHEN** an entity is created with `dock_position != Vector3.ZERO`, `dock_unload = true`, and `accepted_resource_categories = ["tiberium"]`
- **THEN** the entity has DockHostComponent, DockUnloadComponent, and RefineryComponent children

### Requirement: BuildingManager pseudo-foundation check
The system SHALL check for ResourceComponent entities in `BuildingManager.can_place()` footprint cells (pseudo-foundation).

#### Scenario: Pseudo-foundation blocks building placement
- **WHEN** `BuildingManager.can_place()` checks a footprint cell containing an entity with ResourceComponent
- **THEN** the cell is considered blocked and placement is rejected
