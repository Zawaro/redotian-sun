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

### Requirement: Dock client discovers hosts across the whole scene
`DockClientComponent.find_nearest_host()` SHALL locate compatible dock hosts by scanning the `entities` group (via `get_tree().get_nodes_in_group("entities")`) rather than restricting the search to a `Buildings` child node of the current scene. The existing filters SHALL remain: the host must have a `DockHostComponent`, its entity id must match `can_dock_with` (when non-empty), and candidates SHALL be ranked by cell distance plus the occupancy penalty (`queue_size * occupancy_penalty^2`).

#### Scenario: Map-loaded refinery is discoverable
- **WHEN** a refinery with DockHostComponent is a child of the map root (not under a `Buildings` node)
- **AND** a harvester calls `find_nearest_host()`
- **THEN** the refinery SHALL be returned when it is the nearest compatible host

#### Scenario: Player-built refinery is discoverable
- **WHEN** a refinery with DockHostComponent is a child of a `Buildings` node
- **AND** a harvester calls `find_nearest_host()`
- **THEN** the refinery SHALL be returned when it is the nearest compatible host

#### Scenario: Incompatible dock type is skipped
- **WHEN** a building's DockHostComponent entity id is not in the harvester's `can_dock_with`
- **THEN** `find_nearest_host()` SHALL skip it

#### Scenario: Occupancy ranking is preserved
- **WHEN** two compatible hosts are at similar distance but one has a longer queue
- **THEN** the less-occupied host SHALL rank first

#### Scenario: No compatible host
- **WHEN** no entity in the scene has a compatible DockHostComponent
- **THEN** `find_nearest_host()` SHALL return null
