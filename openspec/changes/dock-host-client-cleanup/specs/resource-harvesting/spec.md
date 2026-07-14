## MODIFIED Requirements

### Requirement: DockClientComponent
The system SHALL provide a `DockClientComponent.gd` (script-attached Node) for entities that dock at DockHostComponent buildings. It SHALL handle host discovery, reservation-before-movement, and occupancy-aware selection. DockClientComponent SHALL NOT manage timing, retry cooldowns, or queue rechecking — it SHALL be reactive to signals from DockHostComponent.

#### Scenario: Configure dock client
- **WHEN** a DockClientComponent is configured with `can_dock_with = ["PROC"]`
- **THEN** the component searches for buildings with entity ID "PROC"

#### Scenario: Find nearest host
- **WHEN** `find_nearest_host(parent)` is called
- **THEN** it searches the "Buildings" group for entities with DockHostComponent where entity ID is in `can_dock_with`, applying `occupancy_penalty` to distance

#### Scenario: Reserve before movement
- **WHEN** `seek_dock(parent)` is called
- **THEN** it finds the nearest host, calls `request_dock()`, and if successful emits `dock_slot_reserved` with the host node

#### Scenario: Emit dock_slot_failed
- **WHEN** `seek_dock()` fails at all reachable hosts
- **THEN** it emits `dock_slot_failed`

#### Scenario: Release reservation
- **WHEN** `release_reservation()` is called and a host is reserved
- **THEN** it calls `leave_dock()` on the host's DockHostComponent and clears internal state

#### Scenario: On slot available callback
- **WHEN** the reserved host emits `slot_available` and the client is queued
- **THEN** DockClientComponent calls `on_slot_available()` which re-triggers dock acquisition

#### Scenario: Handle dock timeout from host
- **WHEN** DockHostComponent emits `dock_timeout(docker)` for this client
- **THEN** DockClientComponent clears its reservation state and emits `dock_cancelled`

### Requirement: DockUnloadComponent
The system SHALL provide a `DockUnloadComponent.gd` (script-attached Node) for buildings that unload cargo from docked entities. It SHALL drain cargo from TransportComponent at `unload_rate` per second, look up `ResourceType.value` for each cargo type, add credits to EconomyManager, and validate cargo against `accepted_resource_categories` before unloading. Empty `accepted_resource_categories` SHALL accept all cargo types.

#### Scenario: Unload single-type cargo
- **WHEN** a dock client has cargo `{"tiberium_green": 100}` and DockUnloadComponent has `accepted_resource_categories = ["tiberium"]` and `value_per_unit = 1.0`
- **THEN** 100 credits are added to the player's treasury

#### Scenario: Unload multi-type cargo
- **WHEN** a dock client has cargo `{"tiberium_green": 300, "tiberium_blue": 100}` with values 1.0 and 2.0
- **THEN** `300 * 1.0 + 100 * 2.0 = 500` credits are added

#### Scenario: Reject unaccepted cargo category
- **WHEN** a dock client has cargo `{"vehicle_parts": 50}` and DockUnloadComponent has `accepted_resource_categories = ["tiberium"]`
- **THEN** the cargo is NOT unloaded and `leave_dock()` is called immediately

#### Scenario: Empty categories accept all
- **WHEN** DockUnloadComponent has `accepted_resource_categories = []` and a dock client has cargo
- **THEN** all cargo is accepted for unloading

#### Scenario: Leave dock when empty
- **WHEN** cargo reaches 0.0 after unloading
- **THEN** DockUnloadComponent calls `dock.leave_dock(docker_node)`

### Requirement: EntityFactory wires economy components
The system SHALL extend `EntityFactory._add_components()` to attach ResourceTreeComponent (if `data.spawned_entity_id != ""`), ResourceComponent (if `data.resource_category != ""`), HarvestComponent (if `data.harvester`), DockHostComponent (if `data.dock_position != Vector3.ZERO`), DockClientComponent (if `data.dock != ""`), DockUnloadComponent (if `data.dock_unload`), and FreeUnitComponent (if `data.free_unit != ""`).

#### Scenario: Resource tree gets ResourceTreeComponent
- **WHEN** an entity is created with `spawned_entity_id = "TIB"`
- **THEN** the entity has a ResourceTreeComponent child with values from EntityData

#### Scenario: Resource crystal gets ResourceComponent
- **WHEN** an entity is created with `resource_category = "tiberium"`
- **THEN** the entity has a ResourceComponent child with `resource_type_id` from EntityData

#### Scenario: Harvester gets HarvestComponent and DockClientComponent
- **WHEN** an entity is created with `harvester = true` and `dock = "PROC"`
- **THEN** the entity has a HarvestComponent child and a DockClientComponent child with `can_dock_with = ["PROC"]`

#### Scenario: Refinery gets DockHostComponent and DockUnloadComponent
- **WHEN** an entity is created with `dock_position != Vector3.ZERO` and `dock_unload = true`
- **THEN** the entity has DockHostComponent and DockUnloadComponent children
