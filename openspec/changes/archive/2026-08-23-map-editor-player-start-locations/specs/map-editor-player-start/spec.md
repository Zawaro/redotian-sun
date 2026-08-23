# map-editor-player-start

## ADDED Requirements

### Requirement: Player start location tool
The system SHALL provide a `Set Player Start` tool in the MapEditor toolbar. The MapEditor SHALL expose a player selector (SpinBox, player 1..8) and an active tool state; when the tool is active, a left-click on a map cell SHALL assign the selected player's start location to that cell, and a right-click on the currently assigned cell SHALL reset that player's start location to the default map-center cluster.

#### Scenario: Assign a start location
- **WHEN** the `Set Player Start` tool is active with player N selected and the user left-clicks an in-diamond cell
- **THEN** player N's start location becomes that cell and a marker appears there

#### Scenario: Assign outside the diamond is rejected
- **WHEN** the `Set Player Start` tool is active and the user left-clicks a cell outside the map's diamond bounds
- **THEN** the assignment is ignored and a warning is reported

#### Scenario: Reset a start location to default
- **WHEN** the `Set Player Start` tool is active and the user right-clicks the cell currently assigned to the selected player
- **THEN** that player's start location resets to the default map-center cluster and the marker moves to the default position

#### Scenario: Player selector bounds
- **WHEN** the player selector is set above the map's player count
- **THEN** the editor still allows placing that start (player count does not gate placement)

### Requirement: Default start locations
The system SHALL compute default start locations for all players clustered near the map center, following the FinalSun convention: every player starts at the center cluster until individually moved; deleting a placement restores that player to the cluster. The default cluster SHALL position players adjacent to each other around the map-center cell using a deterministic offset pattern.

#### Scenario: All players default to center cluster
- **WHEN** a map has N players and no start-location overrides are set
- **THEN** every player start is a distinct cell adjacent to the map-center cell

#### Scenario: Default start is inside the diamond
- **WHEN** computing the default start cell for any player on a valid even, odd, or asymmetric map grid
- **THEN** the resulting cell is inside that map's diamond bounds

#### Scenario: Reset returns to the same default
- **WHEN** a player's start is reset after having been moved
- **THEN** it returns to the identical cell it would have had with no override, matching the offset cluster for that player index

### Requirement: Start location persistence
The system SHALL persist player start locations in the map JSON v4 format as a top-level `start_locations` array. Each entry SHALL contain `player_id` and `cell` (a `"x,y"` key string). Only overridden (non-default) start locations SHALL be written. Maps written before this capability and maps without the key SHALL load with all players on their default cluster.

#### Scenario: Save writes only overrides
- **WHEN** a map is saved with two players where only player 2 has a moved start
- **THEN** the JSON contains a single `start_locations` entry for player 2 and no entry for player 1

#### Scenario: Load absent key uses defaults
- **WHEN** a map JSON without a `start_locations` key is loaded
- **THEN** all players use the default center cluster

#### Scenario: Load applies overrides
- **WHEN** a map JSON with `start_locations` is loaded
- **THEN** each listed player uses its stored cell and unlisted players use the default cluster

#### Scenario: Round-trip preserves override
- **WHEN** a start location is assigned, saved, and the map reloaded in the editor
- **THEN** the marker reappears at the stored cell

### Requirement: Camera starts at local player start
The system SHALL position the gameplay camera on the local player's start location when a map loads into gameplay. If the local player has an overridden start, the camera centers on that cell; otherwise it centers on that player's default cluster cell. Maps with no player start data SHALL fall back to the current behavior (camera stays centered).

#### Scenario: Override present
- **WHEN** gameplay loads a map whose `start_locations` contains the local player's cell
- **THEN** the camera pivot centers on that cell's world position

#### Scenario: Default present
- **WHEN** gameplay loads a map and the local player has no overridden start
- **THEN** the camera pivot centers on the default cluster cell for the local player

#### Scenario: No start data
- **WHEN** gameplay loads a map with no `start_locations` key
- **THEN** the camera retains its existing default behavior (no change from today)

### Requirement: Camera pivot resolution
The system SHALL resolve the camera pivot from the gameplay scene hierarchy even though it is centered only during map load. Because the `BoundsSystem` autoload is ready before the gameplay scene exists, the pivot SHALL be discoverable later, once the scene (and its camera) are in the tree; the search SHALL match the camera nested under the pivot node (pivot → `Camera3D`), not only camera nodes that are direct children.

#### Scenario: Pivot resolved after scene load
- **WHEN** the `BoundsSystem` autoload was ready before the gameplay scene (and its camera pivot) existed
- **THEN** the pivot is resolved from the scene hierarchy at map load and the camera is framed on the local player's start cell

### Requirement: Start marker rendering
The system SHALL render a visible world-space marker in the editor for every player start. Each player marker SHALL use the player's color when available and be distinct from the terrain grid and cell highlight.

#### Scenario: Marker at default
- **WHEN** the editor is opened with no overrides for a player
- **THEN** a marker is rendered at that player's default cluster cell

#### Scenario: Marker moves on assign
- **WHEN** the user assigns a start location to a new cell
- **THEN** the marker renders at the new cell and no longer at the previous cell