## ADDED Requirements

### Requirement: DockHostComponent manages queue and stale clients
The system SHALL provide a `DockHostComponent.gd` that manages a FIFO queue of dock clients, reserves/releases the dock cell in SpatialHash, emits signals on dock/undock, and auto-evicts stale clients that don't complete the dock sequence within `stale_timeout` seconds. The queue is unbounded — `request_dock()` never rejects for fullness.

#### Scenario: Immediate dock on empty slot
- **WHEN** a client calls `request_dock()` and `current_docker == null`
- **THEN** the client becomes the current docker, `docker_docked` emits immediately, the stale timer resets, and the dock cell is reserved in SpatialHash

#### Scenario: Queue when occupied
- **WHEN** a client calls `request_dock()` and `current_docker != null`
- **THEN** the client is appended to the queue and `request_dock()` returns false

#### Scenario: Re-dock accepted for current docker
- **WHEN** a client calls `request_dock()` and it is already `current_docker`
- **THEN** `request_dock()` returns true without re-emitting signals

#### Scenario: Wait ticks before promoting from queue
- **WHEN** the slot is free, the queue is non-empty, and `dock_wait_ticks = 10`
- **THEN** the component waits 10 `_process` ticks before promoting the first valid queued client (skipping any freed entries)

#### Scenario: Leave dock awaits vacate then promotes next
- **WHEN** the current docker calls `leave_dock()` and the queue is non-empty
- **THEN** the host enters `_awaiting_vacate`, polls until the dock cell is physically clear (or `VACATE_TIMEOUT` elapses), then releases and re-reserves the cell, promotes the next valid queued client, and emits `docker_docked` + `slot_available`

#### Scenario: Leave dock with empty queue
- **WHEN** the current docker calls `leave_dock()` and the queue is empty
- **THEN** the dock cell is released immediately and `docker_undocked` emits

#### Scenario: Stale client eviction
- **WHEN** a client is `current_docker` and hasn't completed the dock sequence within `stale_timeout` seconds
- **THEN** the host emits `dock_timeout(docker)` and calls `leave_dock()`, which drives the client's cleanup via `docker_undocked`

#### Scenario: Stale timer covers approach then unload
- **WHEN** a reserved client arrives at the dock cell, and again when unloading begins
- **THEN** the client calls `reset_stale_timer()` so the timeout bounds each phase rather than the whole reserve-to-complete span

#### Scenario: Queue purged on host teardown
- **WHEN** the host leaves the tree (`_exit_tree`)
- **THEN** `_clear_queue()` calls `on_dock_cancelled()` on each queued client (no signal emission — teardown-safe)

#### Scenario: Foundation read from sibling
- **WHEN** DockHostComponent needs the building's foundation size
- **THEN** it reads from FoundationComponent sibling via `_get_foundation()`

### Requirement: DockClientComponent is thin and reactive
The system SHALL provide a `DockClientComponent.gd` that handles host discovery, reservation-before-movement, and occupancy-aware selection via an explicit state machine (`IDLE`, `MOVING`, `ROTATING`, `UNLOADING`, `QUEUED`). DockClientComponent SHALL NOT manage per-state timeouts or queue rechecking — it SHALL be reactive to signals from DockHostComponent.

#### Scenario: Configure dock client
- **WHEN** a DockClientComponent is configured with `can_dock_with = ["PROC"]`
- **THEN** the component searches for buildings with entity ID "PROC"

#### Scenario: Find nearest host
- **WHEN** `find_nearest_host(parent)` is called
- **THEN** it searches the "Buildings" group for entities with DockHostComponent where entity ID is in `can_dock_with`, ranking by `distance² + effective_queue_size * occupancy_penalty²`

#### Scenario: Reserve before movement
- **WHEN** `seek_dock(parent)` is called and a host slot is reserved via `request_dock()`
- **THEN** the client enters `MOVING` and paths to the dock cell

#### Scenario: Queue when host occupied
- **WHEN** `seek_dock(parent)` binds no free host
- **THEN** the client enters `QUEUED` and moves to a wait cell; `dock_slot_failed` emits only when no compatible host is reachable at all

#### Scenario: Rotate then unload on arrival
- **WHEN** the client reaches the dock cell
- **THEN** it enters `ROTATING`, aligns to `dock_rotation`, then `UNLOADING` (calling `DockUnloadComponent.begin_unload()`)

#### Scenario: Release reservation
- **WHEN** `release_reservation()` is called and a host is reserved
- **THEN** it disconnects the undock signal, calls `leave_dock()` on the host, and clears the reserved/queued host references

#### Scenario: Cancel from any sub-state
- **WHEN** `cancel()` is called (e.g. a player move order mid-dock)
- **THEN** the client leaves the reserved slot or the queue and fully resets to `IDLE` via `_reset()` — no dangling `_state`/`_target_host`

#### Scenario: On slot available callback
- **WHEN** the reserved host emits `slot_available` and the client is `QUEUED`
- **THEN** DockClientComponent promotes to `MOVING` (rebinding if needed) via `on_slot_available()`

#### Scenario: Undock resets to idle
- **WHEN** the host emits `docker_undocked` for this client
- **THEN** `on_dock_undocked()` resets all state to `IDLE` and re-emits `dock_undocked`

### Requirement: DockUnloadComponent validates cargo categories
The system SHALL provide a `DockUnloadComponent.gd` that drains cargo from the docked entity's TransportComponent at `unload_rate` per second, looks up `ResourceType.value` for each cargo type, adds credits to EconomyManager, and validates cargo against `accepted_resource_categories` before unloading. Empty `accepted_resource_categories` SHALL accept all cargo types. The accepted categories are copied from EntityData in `configure()`.

#### Scenario: Resolve transport from docked entity
- **WHEN** unloading begins and `current_docker` is the DockClientComponent
- **THEN** DockUnloadComponent reads the TransportComponent from the docker's parent entity

#### Scenario: Unload accepted cargo
- **WHEN** a dock client has cargo `{"tiberium_green": 100}`, `accepted_resource_categories = ["tiberium"]`, and the type value is `1.0`
- **THEN** 100 credits are added to the player's treasury

#### Scenario: Reject unaccepted cargo category
- **WHEN** a dock client has cargo `{"vehicle_parts": 50}` and `accepted_resource_categories = ["tiberium"]`
- **THEN** the cargo is NOT unloaded and `leave_dock()` is called immediately

#### Scenario: Empty categories accept all
- **WHEN** `accepted_resource_categories = []` and a dock client has cargo
- **THEN** all cargo is accepted for unloading

#### Scenario: Leave dock when empty
- **WHEN** cargo reaches 0.0 after unloading
- **THEN** DockUnloadComponent calls `dock.leave_dock(docker_node)`

### Requirement: Dock system unit tests
The system SHALL provide comprehensive unit tests covering the dock host-client interaction pattern including reservation, queue promotion, vacate, stale eviction, cancellation, and cargo validation.

#### Scenario: Test request dock when empty
- **WHEN** `test_request_dock_succeeds_when_empty()` runs
- **THEN** DockHostComponent accepts the client immediately and sets `current_docker`

#### Scenario: Test queue when occupied
- **WHEN** `test_seek_dock_queues_when_host_occupied()` runs
- **THEN** the second client enters `QUEUED` and is appended to the host's queue

#### Scenario: Test leave dock promotes next
- **WHEN** `test_leave_dock_promotes_next_queued_docker()` runs
- **THEN** the next queued client becomes `current_docker` and the dock cell is re-reserved

#### Scenario: Test stale client eviction
- **WHEN** `test_stale_client_evicted_after_stale_timeout()` runs
- **THEN** DockHostComponent evicts the client after `stale_timeout` and emits `dock_timeout`

#### Scenario: Test cancel from any sub-state
- **WHEN** `test_cancel_from_queued_leaves_queue_and_idles()` and `test_cancel_from_reserved_frees_slot_and_idles()` run
- **THEN** the client ends in `IDLE`, is removed from the queue / frees the slot, with no dangling host references

#### Scenario: Test cargo validation
- **WHEN** the cargo-validation test runs with an unaccepted category
- **THEN** DockUnloadComponent calls `leave_dock()` without unloading
