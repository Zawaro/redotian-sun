## ADDED Requirements

### Requirement: Waypoint placement
The editor SHALL provide a Waypoint tool that places numbered waypoints on cells. The first free index ≥ 8 is assigned automatically; waypoint 0–7 remain reserved for player starting points (PlayerStartTool). A marker SHALL render on each placed waypoint.

#### Scenario: Place a waypoint
- **WHEN** the player clicks a cell with the Waypoint tool and no waypoints exist
- **THEN** waypoint 8 is placed on that cell and a marker renders there

#### Scenario: Indexes skip reserved range
- **WHEN** the player places several waypoints
- **THEN** indexes continue from 8 upward (0–7 never assigned by the tool)

#### Scenario: Duplicate cell rejected
- **WHEN** the player places a waypoint on a cell that already has one
- **THEN** the editor warns and does not create a duplicate

### Requirement: Waypoint deletion
The Delete tool SHALL remove the waypoint (if any) on each brushed cell.

#### Scenario: Delete removes waypoint
- **WHEN** the player deletes over a cell holding waypoint 8
- **THEN** waypoint 8 is removed and its marker disappears

#### Scenario: Deleting frees the index
- **WHEN** waypoint 8 is deleted and a new waypoint is placed
- **THEN** the new waypoint reuses index 8

### Requirement: Waypoints persist in map JSON
`TerrainSystem.export_to_json` SHALL write waypoints as `"waypoints": {"<index>": [x, z]}` and the loader SHALL restore them into the editor and expose them to gameplay consumers. Waypoint 0–7 SHALL NOT be written by the waypoint system (start_locations remains their persistence path). Loading a map without `waypoints` SHALL leave none.

#### Scenario: Round-trip waypoints
- **WHEN** a map with waypoints 8–10 is exported and reloaded
- **THEN** all three exist at the same cells with the same indexes

#### Scenario: Old maps load clean
- **WHEN** a pre-existing map JSON without `waypoints` is loaded
- **THEN** no waypoints exist and nothing errors
