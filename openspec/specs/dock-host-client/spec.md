## MODIFIED Requirements

### Requirement: Dock interaction via HarvestComponent targeter
Dock interaction SHALL be handled by HarvestComponent's `get_order_for_target()` returning an ENTER order when the target has DockHostComponent. SelectionManager.request_dock() SHALL be removed. DockHostComponent.request_dock() remains as the low-level dock binding API (called by HarvestComponent's execute callback).

#### Scenario: Docking via order targeter
- **WHEN** a harvester is selected and cursor is over a DockHostComponent entity
- **THEN** HarvestComponent.get_order_for_target() SHALL return ENTER cursor and dock execute callback

#### Scenario: DockHostComponent.request_dock stays
- **WHEN** HarvestComponent's execute callback needs to bind to a dock
- **THEN** it SHALL call DockHostComponent.request_dock() directly (not through SelectionManager)

#### Scenario: SelectionManager.request_dock removed
- **WHEN** SelectionManager.request_dock() is called
- **THEN** it SHALL not exist (method removed)

## ADDED Requirements

### Requirement: Dock host rejects foreign dockers
`DockHostComponent.request_dock()` SHALL compare the docker entity's owner (`StatsComponent.player_id` on the docker's parent entity) against the host building's own owner (`StatsComponent.player_id` on the component's parent). A request SHALL be rejected (returns `false`) when the owners differ or when either side has an unset owner id (`< 0` or missing `StatsComponent`). This gate applies to all callers regardless of how the docker discovered the host.

#### Scenario: Same owner docks
- **WHEN** a docker owned by player 1 requests a dock at a refinery owned by player 1
- **THEN** `request_dock()` SHALL behave as before the ownership rule (dock or queue normally)

#### Scenario: Foreign docker rejected
- **WHEN** a docker owned by player 2 requests a dock at a refinery owned by player 1
- **THEN** `request_dock()` SHALL return `false` and the docker SHALL not enter the dock or its queue

#### Scenario: Unset owner rejected
- **WHEN** either the docker entity or the host building has no `StatsComponent` or a negative `player_id`
- **THEN** `request_dock()` SHALL return `false`

### Requirement: Dock client discovers hosts across the whole scene
`DockClientComponent.find_nearest_host()` SHALL locate compatible dock hosts by scanning the `entities` group (via `get_tree().get_nodes_in_group("entities")`) rather than restricting the search to a `Buildings` child node of the current scene. The existing filters SHALL remain: the host must have a `DockHostComponent`, its entity id must match `can_dock_with` (when non-empty), and candidates SHALL be ranked by cell distance plus the occupancy penalty (`queue_size * occupancy_penalty^2`). In addition, a candidate SHALL be skipped when its building owner does not exactly match the seeking entity's owner, or when either side has an unset owner id (`< 0` or missing `StatsComponent`).

#### Scenario: Map-loaded refinery is discoverable
- **WHEN** a refinery with DockHostComponent is a child of the map root (not under a `Buildings` node)
- **AND** a harvester calls `find_nearest_host()`
- **THEN** the refinery SHALL be returned when it is the nearest compatible same-owner host

#### Scenario: Player-built refinery is discoverable
- **WHEN** a refinery with DockHostComponent is a child of a `Buildings` node
- **AND** a harvester calls `find_nearest_host()`
- **THEN** the refinery SHALL be returned when it is the nearest compatible same-owner host

#### Scenario: Incompatible dock type is skipped
- **WHEN** a building's DockHostComponent entity id is not in the harvester's `can_dock_with`
- **THEN** `find_nearest_host()` SHALL skip it

#### Scenario: Occupancy ranking is preserved
- **WHEN** two compatible hosts are at similar distance but one has a longer queue
- **THEN** the less-occupied host SHALL rank first

#### Scenario: No compatible host
- **WHEN** no entity in the scene has a compatible DockHostComponent
- **THEN** `find_nearest_host()` SHALL return null

#### Scenario: Foreign-owned host is skipped
- **WHEN** the nearest dock-compatible building belongs to a different player than the harvester
- **THEN** `find_nearest_host()` SHALL skip it and consider only same-owner hosts

#### Scenario: Only foreign hosts exist
- **WHEN** every dock-compatible building within search radius belongs to other players
- **THEN** `find_nearest_host()` SHALL return null and the caller SHALL receive the existing failure path (`seek_dock` emits `dock_slot_failed`)

#### Scenario: Ownerless client finds nothing
- **WHEN** the seeking entity has no valid owner id
- **THEN** `find_nearest_host()` SHALL return null regardless of available hosts

### Requirement: Active unload is never evicted
The dock host's `stale_timeout` SHALL bound only the approach and rotation phase of a dock sequence. While the current docker is actively unloading, the host SHALL NOT evict it for exceeding `stale_timeout`. The docker SHALL deposit its entire accepted cargo before the dock releases it; release SHALL occur only when cargo is empty, the cargo is rejected, or the docker is no longer valid.

#### Scenario: Full unload completes past the stale window
- **WHEN** a docked harvester with 28 bales of accepted cargo unloads at about 2.0 bales/s (about 14 s) with `stale_timeout = 5.0`
- **THEN** the dock SHALL NOT evict it mid-unload, no `dock_timeout` SHALL be emitted, and cargo SHALL reach 0 before `docker_undocked`

#### Scenario: Credits equal cargo bales times value
- **WHEN** the full load above completes
- **THEN** the refinery owner SHALL receive `28 x 25 = 700` credits and `TransportComponent.cargo` SHALL be empty

#### Scenario: Stuck docker is still evicted
- **WHEN** a docker occupies the dock and never begins or completes unloading within `stale_timeout`
- **THEN** the host SHALL still evict it and emit `dock_timeout`

#### Scenario: Rejected cargo still leaves
- **WHEN** a docker carrying an unaccepted resource category finishes the approach
- **THEN** the dock SHALL release it without depositing credits

### Requirement: Reference unload cadence
Unloading SHALL be incremental at approximately 2.0 bales per real second, using the project's 2x TS time base (30 logic ticks/second): ~15 TS ticks per bail (HarvesterDumpRate = .016 min) gives 30/15 = 2.0 bales/s, so a full 28-bale load deposits in about 14 seconds. Because the rate is per real second and applied via `delta`, the host frame rate SHALL NOT change that duration.

#### Scenario: Unload rate default
- **WHEN** a `DockUnloadComponent` runs with default settings
- **THEN** its unload rate SHALL be approximately 2.0 bales/s

#### Scenario: Incremental deposit
- **WHEN** a full harvester unloads with an economy manager attached
- **THEN** credits SHALL be added gradually across the unload rather than all at once on docking
