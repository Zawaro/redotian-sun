## MODIFIED Requirements

### Requirement: TiberiumComponent
The system SHALL provide a `TiberiumComponent.gd` (script-attached Node) for Tiberium crystal entities on the map. Crystals SHALL be `TERRAIN`-type entity instances with 1x1 pseudo-foundation (blocks building placement, allows unit movement). TiberiumComponent SHALL use `resource_type_id: String` to identify the resource sub-type.

#### Scenario: Configure Tiberium node
- **WHEN** a TiberiumComponent is configured with `amount = 500`, `max_amount = 500`, `resource_type_id = "tiberium_green"`, `regrowth_rate = -1.0`
- **THEN** the node has 500 current tiberium, 500 max, green type, and uses the GlobalRules default regrowth rate

#### Scenario: Deplete node
- **WHEN** `HarvestComponent` collects 50 tiberium from a node with `amount = 100`
- **THEN** the node's `amount` decreases to 50

#### Scenario: Depleted node returns zero
- **WHEN** a harvester attempts to collect from a node with `amount = 0`
- **THEN** the node returns 0 tiberium and the harvester seeks a new node

#### Scenario: Blue tiberium type
- **WHEN** a TiberiumComponent is configured with `resource_type_id = "tiberium_blue"`
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
The system SHALL provide a `HarvestComponent.gd` (script-attached Node) for harvester behavior. It SHALL implement a state machine: IDLE → SEEK_RESOURCE → HARVESTING → FULL → SEEK_REFINERY → DOCKING → UNLOADING → IDLE. HarvestComponent SHALL delegate dock-finding to DockClientComponent and support multiple resource categories.

#### Scenario: Auto-seek nearest resource when idle
- **WHEN** a HarvestComponent is in IDLE state with empty cargo and a resource node exists within scan range matching `harvestable_types`
- **THEN** the harvester transitions to SEEK_RESOURCE and navigates to the nearest matching node

#### Scenario: Collect resource from node
- **WHEN** a HarvestComponent is in HARVESTING state at a node with available resource
- **THEN** it fills cargo at `harvester_fill_rate` per second and the node depletes at the same rate

#### Scenario: Return when full
- **WHEN** cargo reaches `TransportComponent.resource_capacity`
- **THEN** the HarvestComponent transitions to FULL state and delegates to DockClientComponent

#### Scenario: Return when node depleted
- **WHEN** the current resource node reaches `amount = 0`
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
- **THEN** only "tiberium_green" nodes are considered (category "tiberium" matches)

### Requirement: DockComponent
**REMOVED**: Renamed to DockHostComponent. See dock-host-client capability for replacement.

**Reason**: Renamed to better reflect host-side responsibility in the DockHost/DockClient split.
**Migration**: Replace all `DockComponent` references with `DockHostComponent`.

### Requirement: FoundationComponent bib cells
The system SHALL extend `FoundationComponent` with `bib_cells: PackedVector2i` defining cells within the foundation footprint that are traversable for dock interaction.

#### Scenario: Bib cells within foundation
- **WHEN** a FoundationComponent has `foundation = Vector2i(4,3)` and `bib_cells = [Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1), Vector2i(3, -1)]`
- **THEN** the bottom row of cells are registered as bib — passable for dock-queued entities

#### Scenario: Bib cells outside foundation are ignored
- **WHEN** a bib cell offset exceeds the foundation rectangle bounds
- **THEN** the cell is silently ignored during registration

### Requirement: EntityFactory wires economy components
The system SHALL extend `EntityFactory._add_components()` to attach TiberiumTreeComponent (if `data.tiberium_tree`), TiberiumComponent (if `data.tiberium_resource`), HarvestComponent (if `data.harvester`), DockHostComponent (if dock position is set), DockClientComponent (if `data.dock != ""`), and RefineryComponent (if `data.accepted_resource_categories.size() > 0`).

#### Scenario: Tiberium tree gets TiberiumTreeComponent
- **WHEN** an entity is created with `tiberium_tree = true`
- **THEN** the entity has a TiberiumTreeComponent child with values from EntityData

#### Scenario: Tiberium crystal gets TiberiumComponent
- **WHEN** an entity is created with `tiberium_resource = true`
- **THEN** the entity has a TiberiumComponent child with values from EntityData

#### Scenario: Harvester gets HarvestComponent and DockClientComponent
- **WHEN** an entity is created with `harvester = true` and `dock = "PROC"`
- **THEN** the entity has a HarvestComponent child and a DockClientComponent child with `can_dock_with = ["PROC"]`

#### Scenario: Refinery gets DockHostComponent and RefineryComponent
- **WHEN** an entity is created with a non-zero `dock_position` and `accepted_resource_categories = ["tiberium"]`
- **THEN** the entity has a DockHostComponent child and a RefineryComponent child

### Requirement: BuildingManager stub deduction + pseudo-foundation check
The system SHALL call `EconomyManager.deduct()` in `BuildingManager.place_building()` as a temporary measure. The system SHALL also check for TiberiumComponent entities in `BuildingManager.can_place()` footprint cells (pseudo-foundation).

#### Scenario: Building placement deducts credits
- **WHEN** `BuildingManager.place_building()` is called with a building costing 2000
- **THEN** `EconomyManager.deduct()` is called for 2000

#### Scenario: Pseudo-foundation blocks building placement
- **WHEN** `BuildingManager.can_place()` checks a footprint cell containing an entity with TiberiumComponent
- **THEN** the cell is considered blocked and placement is rejected
