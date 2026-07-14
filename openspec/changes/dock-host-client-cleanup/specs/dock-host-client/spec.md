## ADDED Requirements

### Requirement: DockHostComponent manages queue and stale clients
The system SHALL provide a `DockHostComponent.gd` that manages a FIFO queue of dock clients, reserves/releases the dock cell in SpatialHash, emits signals on dock/undock, and auto-evicts stale clients that don't complete the dock sequence within `stale_timeout` seconds.

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

#### Scenario: Leave dock releases cell and promotes next
- **WHEN** the current docker calls `leave_dock()` and queue is non-empty
- **THEN** the dock cell is released, next queued client becomes current, dock cell is re-reserved, `docker_docked` emits for new client, and `slot_available` emits

#### Scenario: Leave dock with empty queue
- **WHEN** the current docker calls `leave_dock()` and queue is empty
- **THEN** the dock cell is released and `docker_undocked` emits

#### Scenario: Stale client eviction
- **WHEN** a client is docked (current_docker) and hasn't completed dock sequence within `stale_timeout` seconds
- **THEN** the host evicts the client via `leave_dock()`, emits `dock_timeout(docker)` signal, and promotes next queued client

#### Scenario: Foundation read from sibling
- **WHEN** DockHostComponent needs the building's foundation size
- **THEN** it reads from FoundationComponent sibling via `_get_foundation()`

### Requirement: DockClientComponent is thin and reactive
The system SHALL provide a `DockClientComponent.gd` that handles host discovery, reservation-before-movement, and occupancy-aware selection. DockClientComponent SHALL NOT manage timing, retry cooldowns, or queue rechecking — it SHALL be reactive to signals from DockHostComponent.

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

### Requirement: DockUnloadComponent validates cargo categories
The system SHALL provide a `DockUnloadComponent.gd` that drains cargo from TransportComponent at `unload_rate` per second, looks up `ResourceType.value` for each cargo type, adds credits to EconomyManager, and validates cargo against `accepted_resource_categories` before unloading. Empty `accepted_resource_categories` SHALL accept all cargo types.

#### Scenario: Unload accepted cargo
- **WHEN** a dock client has cargo `{"tiberium_green": 100}` and DockUnloadComponent has `accepted_resource_categories = ["tiberium"]` and `value_per_unit = 1.0`
- **THEN** 100 credits are added to the player's treasury

#### Scenario: Reject unaccepted cargo category
- **WHEN** a dock client has cargo `{"vehicle_parts": 50}` and DockUnloadComponent has `accepted_resource_categories = ["tiberium"]`
- **THEN** the cargo is NOT unloaded and `leave_dock()` is called immediately

#### Scenario: Empty categories accept all
- **WHEN** DockUnloadComponent has `accepted_resource_categories = []` and a dock client has cargo
- **THEN** all cargo is accepted for unloading

#### Scenario: Leave dock when empty
- **WHEN** cargo reaches 0.0 after unloading
- **THEN** DockUnloadComponent calls `dock.leave_dock(docker_node)`

### Requirement: Dock system unit tests
The system SHALL provide comprehensive unit tests covering the dock host-client interaction pattern including reservation, queue promotion, timeout handling, and cargo validation.

#### Scenario: Test request dock when empty
- **WHEN** `test_request_dock_immediate()` runs
- **THEN** DockHostComponent accepts the client immediately and sets `current_docker`

#### Scenario: Test queue overflow
- **WHEN** `test_request_dock_queue_full()` runs
- **THEN** DockHostComponent rejects the client when queue is at `max_queue_length`

#### Scenario: Test leave dock promotes next
- **WHEN** `test_leave_dock_reserves_cell_for_next_docker()` runs
- **THEN** the next queued client becomes `current_docker` and dock cell is re-reserved

#### Scenario: Test stale client eviction
- **WHEN** `test_stale_client_eviction()` runs
- **THEN** DockHostComponent evicts the client after `stale_timeout` and emits `dock_timeout`

#### Scenario: Test cargo validation
- **WHEN** `test_cargo_validation_rejects_unaccepted()` runs
- **THEN** DockUnloadComponent calls `leave_dock()` when cargo category doesn't match `accepted_resource_categories`
