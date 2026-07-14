## MODIFIED Requirements

### Requirement: DockClientComponent
The system SHALL provide a `DockClientComponent.gd` (script-attached Node) for entities that dock at DockHostComponent buildings. It SHALL handle host discovery, reservation-before-movement, and occupancy-aware selection via a state machine (`IDLE`, `MOVING`, `ROTATING`, `UNLOADING`, `QUEUED`). DockClientComponent SHALL NOT manage per-state timeouts or queue rechecking — it SHALL be reactive to signals from DockHostComponent.

#### Scenario: Configure dock client
- **WHEN** a DockClientComponent is configured with `can_dock_with = ["PROC"]`
- **THEN** the component searches for buildings with entity ID "PROC"

#### Scenario: Find nearest host
- **WHEN** `find_nearest_host(parent)` is called
- **THEN** it searches the "Buildings" group for entities with DockHostComponent where entity ID is in `can_dock_with`, ranking by `distance² + effective_queue_size * occupancy_penalty²`

#### Scenario: Reserve before movement
- **WHEN** `seek_dock(parent)` reserves a free host slot
- **THEN** the client enters `MOVING` and paths to the dock cell

#### Scenario: Queue when occupied
- **WHEN** `seek_dock(parent)` binds no free host
- **THEN** the client enters `QUEUED` and moves to a wait cell; `dock_slot_failed` emits only when no compatible host is reachable

#### Scenario: Release reservation
- **WHEN** `release_reservation()` is called and a host is reserved
- **THEN** it calls `leave_dock()` on the host's DockHostComponent and clears the host references

#### Scenario: Cancel from any sub-state
- **WHEN** `cancel()` is called (player move order mid-dock)
- **THEN** the client leaves the reserved slot or the queue and resets to `IDLE`

#### Scenario: On slot available callback
- **WHEN** the reserved host emits `slot_available` and the client is `QUEUED`
- **THEN** DockClientComponent promotes to `MOVING` via `on_slot_available()`

#### Scenario: Undock resets to idle
- **WHEN** the host emits `docker_undocked` for this client
- **THEN** `on_dock_undocked()` resets state to `IDLE` and re-emits `dock_undocked`

### Requirement: DockUnloadComponent
The system SHALL provide a `DockUnloadComponent.gd` (script-attached Node) for buildings that unload cargo from docked entities. It SHALL drain cargo from the docked entity's TransportComponent at `unload_rate` per second, look up `ResourceType.value` for each cargo type, add credits to EconomyManager, and validate cargo against `accepted_resource_categories` before unloading. Empty `accepted_resource_categories` SHALL accept all cargo types.

#### Scenario: Resolve transport from docked entity
- **WHEN** unloading and `current_docker` is the DockClientComponent
- **THEN** the TransportComponent is read from the docker's parent entity

#### Scenario: Unload single-type cargo
- **WHEN** a dock client has cargo `{"tiberium_green": 100}` and `accepted_resource_categories = ["tiberium"]` with type value `1.0`
- **THEN** 100 credits are added to the player's treasury

#### Scenario: Unload multi-type cargo
- **WHEN** a dock client has cargo `{"tiberium_green": 300, "tiberium_blue": 100}` with values 1.0 and 2.0
- **THEN** `300 * 1.0 + 100 * 2.0 = 500` credits are added

#### Scenario: Reject unaccepted cargo category
- **WHEN** a dock client has cargo `{"vehicle_parts": 50}` and `accepted_resource_categories = ["tiberium"]`
- **THEN** the cargo is NOT unloaded and `leave_dock()` is called immediately

#### Scenario: Empty categories accept all
- **WHEN** `accepted_resource_categories = []` and a dock client has cargo
- **THEN** all cargo is accepted for unloading

#### Scenario: Leave dock when empty
- **WHEN** cargo reaches 0.0 after unloading
- **THEN** DockUnloadComponent calls `dock.leave_dock(docker_node)`

### Requirement: HarvestComponent drives the harvest loop
The system SHALL provide a `HarvestComponent.gd` whose state machine is `IDLE`, `SEEK_NODE`, `HARVESTING`, `DELIVERING`, `HIBERNATE`. `IDLE` is reserved for an explicit player stop (`cancel_harvest`); the component SHALL auto-resume harvesting after a field is exhausted rather than idling.

#### Scenario: Deliver when full
- **WHEN** cargo reaches storage capacity while HARVESTING
- **THEN** the harvester releases the resource cell and enters `DELIVERING`, calling `dock_client.seek_dock()`

#### Scenario: No dock reachable retries without recursion
- **WHEN** `dock_slot_failed` fires while DELIVERING
- **THEN** the harvester schedules a `DELIVER_RETRY` cooldown and re-seeks from `_process` — it does NOT re-seek synchronously (which would recurse via `dock_slot_failed`)

#### Scenario: Player-ordered dock enters DELIVERING
- **WHEN** `set_target_refinery(node)` is called (player left-click on a refinery)
- **THEN** the harvester releases its resource, enters `DELIVERING`, and seeks that specific host — so the undock handler resumes the loop afterward

#### Scenario: Depleted field with partial cargo delivers
- **WHEN** the current node depletes and the harvester holds cargo
- **THEN** `_assess_next_action()` enters `DELIVERING` to unload what it has

#### Scenario: Depleted field while empty hibernates
- **WHEN** the harvester is empty and no reachable resource is found
- **THEN** it enters `HIBERNATE` (NOT `IDLE`), waiting `HIBERNATE_INTERVAL` between re-scans and auto-resuming to `SEEK_NODE` when a field reappears

#### Scenario: Unblock the dock when hibernating on it
- **WHEN** the harvester enters `HIBERNATE` while parked on a refinery's dock cell
- **THEN** it moves to a free wait cell so it does not block the entrance for other harvesters

#### Scenario: Player move command idles the harvester
- **WHEN** `cancel_harvest()` is called (player move order)
- **THEN** the harvester releases its resource, calls `dock_client.cancel()`, and enters `IDLE` (no auto-search)

### Requirement: EntityFactory wires economy components
The system SHALL extend `EntityFactory._add_components()` to attach ResourceTreeComponent (if `data.spawned_entity_id != ""`), ResourceComponent (if `data.resource_category != ""`), HarvestComponent (if `data.harvester`), DockHostComponent (if `data.dock_position != Vector3.ZERO`), DockClientComponent (if `data.dock != ""`), DockUnloadComponent (if `data.dock_unload`), and FreeUnitComponent (if `data.free_unit != ""`). Component fields sourced from EntityData (e.g. `accepted_resource_categories`) are applied via each component's `configure(data)`.

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
- **THEN** the entity has DockHostComponent and DockUnloadComponent children, and `configure(data)` copies `accepted_resource_categories` onto the DockUnloadComponent
