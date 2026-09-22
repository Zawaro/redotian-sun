## ADDED Requirements

### Requirement: Mission override precedence
Starting a mission SHALL resolve per-player values with precedence **mission > map > global rules**:
a mission value that is set SHALL win, otherwise the map's own value SHALL be used, otherwise the
active game's `GlobalRules`. `PlayerManager` SHALL apply the resolved `starting_credits` and
`player_house` to the local player when a mission starts.

#### Scenario: Mission credits beat global
- **WHEN** a mission with `starting_credits = 50` starts while `GlobalRules.starting_credits = 10000`
- **THEN** the local player's credits are `50`

#### Scenario: Inherit falls back to global
- **WHEN** a mission with `starting_credits = -1` starts
- **THEN** the local player's credits equal `GlobalRules.starting_credits`

#### Scenario: Mission house overrides the default faction
- **WHEN** a mission with `player_house = "GDI"` starts
- **THEN** the local player's faction is `GDI`

### Requirement: Mission map loading
Starting a mission SHALL load the mission's `map_path` JSON into the gameplay node
(`MainScene/Gameplay`) using the existing `MapLoader`, after the mission's overrides are applied.
A missing or unreadable map file SHALL log an error and leave the gameplay node empty.

#### Scenario: Mission map loads entities
- **WHEN** a mission whose map JSON contains entities is started
- **THEN** those entities are instantiated under the gameplay node and `GameContext.current_mission`
  remains the started mission

#### Scenario: Missing map reported
- **WHEN** a mission's `map_path` does not exist
- **THEN** an error is logged and no map entities are created

### Requirement: Mission start camera
When a mission defines `home_cell` (`"x,y"`), starting the mission SHALL center the gameplay
camera on that cell, overriding the map's own start location. When `home_cell` is empty, the map's
existing start-location framing SHALL apply.

#### Scenario: Home cell centers the camera
- **WHEN** a mission with `home_cell = "10,20"` starts
- **THEN** the camera pivot is centered on cell `(10, 20)`

#### Scenario: Empty home cell defers to the map
- **WHEN** a mission with `home_cell = ""` starts on a map with a local-player start location
- **THEN** the camera centers on the map's start location for the local player

### Requirement: Mission entry points
The system SHALL support starting a mission from a `--mission <id>` command-line flag, applying the
same boot flow as the campaign dialog. The flag SHALL be recognized in both `OS.get_cmdline_args()`
and `OS.get_cmdline_user_args()`, mirroring `--game`.

#### Scenario: CLI flag starts a mission
- **WHEN** the game is launched with `--mission gdi01`
- **THEN** `GameContext.current_mission.id` is `"gdi01"` after boot

#### Scenario: No flag starts no mission
- **WHEN** the game is launched without `--mission`
- **THEN** `GameContext.current_mission` is `null`
