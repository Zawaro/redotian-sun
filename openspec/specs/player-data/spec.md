## ADDED Requirements

### Requirement: PlayerData resource
The system SHALL provide a `PlayerData.gd` resource class for per-player identity and economy state.

#### Scenario: Create player with identity fields
- **WHEN** a PlayerData resource is created with `player_id = 0`, `faction_id = "GDI"`, `color = Color.BLUE`, `team_id = 1`, `spawn_index = 0`, `display_name = "Player 1"`, `is_bot = false`
- **THEN** the resource holds all specified values

#### Scenario: Default values
- **WHEN** a PlayerData is created without setting fields
- **THEN** `player_id = 0`, `credits = 0`, `faction_id = ""`, `color = Color.WHITE`, `team_id = 0`, `spawn_index = 0`, `display_name = ""`, `is_bot = false`

#### Scenario: Create player with starting credits
- **WHEN** a PlayerData resource is created with `credits = 1000`
- **THEN** the resource holds `credits = 1000`

#### Scenario: Bot player
- **WHEN** a PlayerData has `is_bot = true`
- **THEN** the player can be identified as an AI player

### Requirement: Faction resource
The system SHALL provide a `Faction.gd` resource class for faction definitions.

#### Scenario: Create faction
- **WHEN** a Faction resource is created with `id = "GDI"`, `display_name = "Global Defense Initiative"`, `color = Color(0.3, 0.4, 0.6)`
- **THEN** the resource holds all specified values

#### Scenario: Faction file storage
- **WHEN** Faction resources are saved
- **THEN** they are stored as .tres files under `resources/factions/`

### Requirement: MapConfig resource
The system SHALL provide a `MapConfig.gd` resource class for per-map player definitions. MapConfig SHALL be a child node of the map scene.

#### Scenario: Create map config with players
- **WHEN** a MapConfig resource is created with `players` array containing 2 PlayerConfig entries
- **THEN** the resource holds the player configurations

#### Scenario: PlayerConfig overrides
- **WHEN** a PlayerConfig has `starting_credits = 5000` (not -1)
- **THEN** that value overrides GlobalRules.starting_credits for that player

#### Scenario: PlayerConfig default fallback
- **WHEN** a PlayerConfig has `starting_credits = -1`
- **THEN** PlayerManager uses GlobalRules.starting_credits as the default
