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

## MODIFIED Requirements

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
