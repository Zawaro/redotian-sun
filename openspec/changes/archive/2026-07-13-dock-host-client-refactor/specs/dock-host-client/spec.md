## ADDED Requirements

### Requirement: DockHostComponent
The system SHALL provide a `DockHostComponent.gd` (script-attached Node) for buildings that accept docking entities. It SHALL manage a FIFO queue of dock clients, reserve/release the dock cell in SpatialHash, and emit signals when clients dock or undock.

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

#### Scenario: Immediate dock skips wait timer
- **WHEN** a client docks immediately (slot was free)
- **THEN** `docker_docked` emits without waiting for `dock_wait_ticks`

#### Scenario: Leave dock releases cell
- **WHEN** the current docker calls `leave_dock()` or is removed
- **THEN** the dock cell is released in SpatialHash, `docker_undocked` emits, and the next queued client becomes current

#### Scenario: Get queue size
- **WHEN** `get_queue_size()` is called
- **THEN** the component returns the current number of queued (non-current) clients

#### Scenario: Has dock type check
- **WHEN** `has_dock_type("harvest")` is called on a component with `dock_types = ["harvest", "repair"]`
- **THEN** returns true

#### Scenario: Foundation read from sibling
- **WHEN** DockHostComponent needs the building's foundation size
- **THEN** it reads from FoundationComponent sibling via `get_parent().get_node_or_null("FoundationComponent")`

### Requirement: DockClientComponent
The system SHALL provide a `DockClientComponent.gd` (script-attached Node) for entities that dock at DockHostComponent buildings. It SHALL handle host discovery, reservation-before-movement, and occupancy-aware selection.

#### Scenario: Configure dock client
- **WHEN** a DockClientComponent is configured with `can_dock_with = ["PROC"]`
- **THEN** the component searches for buildings with entity ID "PROC"

#### Scenario: Find nearest host
- **WHEN** `find_nearest_host(parent)` is called
- **THEN** it searches the "Buildings" group for entities with DockHostComponent where entity ID is in `can_dock_with`, applying `occupancy_penalty` to distance

#### Scenario: Occupancy penalty in distance
- **WHEN** two hosts are at equal straight-line distance but one has 2 queued clients
- **THEN** the host with queue gets `distance + 2 * occupancy_penalty` penalty, preferring the empty host

#### Scenario: Reserve before movement
- **WHEN** `try_reserve_dock(parent)` is called
- **THEN** it finds the nearest host, calls `request_dock()`, and if successful emits `dock_slot_reserved` with the host node

#### Scenario: Try next host on failure
- **WHEN** `try_reserve_dock()` fails at the nearest host (queue full)
- **THEN** it tries the next nearest host, repeating until one succeeds or all are tried

#### Scenario: Emit dock_slot_failed
- **WHEN** `try_reserve_dock()` fails at all reachable hosts
- **THEN** it emits `dock_slot_failed`

#### Scenario: Release reservation
- **WHEN** `release_reservation()` is called and a host is reserved
- **THEN** it calls `leave_dock()` on the host's DockHostComponent

#### Scenario: On slot available callback
- **WHEN** the reserved host emits `slot_available` and the client is queued
- **THEN** DockClientComponent calls `on_slot_available()` which re-triggers `try_reserve_dock()`

#### Scenario: Get dock ID
- **WHEN** `get_dock_id()` is called
- **THEN** it returns the first entry in `can_dock_with` (backward compatibility with HarvestComponent)

### Requirement: DockHostComponent cell reservation via SpatialHash
DockHostComponent SHALL reserve the dock cell in SpatialHash when a client docks and release it when the client leaves.

#### Scenario: Reserve on dock
- **WHEN** a client docks at DockHostComponent
- **THEN** `SpatialHash.instance.force_reserve(dock_cell)` is called

#### Scenario: Release on undock
- **WHEN** the current client leaves the dock
- **THEN** `SpatialHash.instance.release_cell(dock_cell)` is called

### Requirement: DockHostComponent computes dock cell from FoundationComponent
DockHostComponent SHALL compute the dock cell position using the parent entity's position, FoundationComponent's foundation size, and dock_position offset.

#### Scenario: Compute dock cell
- **WHEN** a DockHostComponent is on a building at position (10, 0, 8) with foundation (4, 3) and dock_position Vector3(6, 0, 2)
- **THEN** `_dock_cell` is computed as the world cell corresponding to the dock position offset from the building's top-left corner
