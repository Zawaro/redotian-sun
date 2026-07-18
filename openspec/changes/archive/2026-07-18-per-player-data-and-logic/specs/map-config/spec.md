## ADDED Requirements

### Requirement: MapConfig resource
The system SHALL provide a `MapConfig.gd` resource class for per-map player definitions. Each map SHALL have an associated MapConfig as a child node of the map scene.

#### Scenario: MapConfig with two players
- **WHEN** a MapConfig resource is created with `players` array containing 2 PlayerConfig entries
- **THEN** the resource holds both player configurations

#### Scenario: Empty MapConfig
- **WHEN** a MapConfig resource is created with an empty `players` array
- **THEN** PlayerManager creates default players (player 0 = human, player 1 = AI)

### Requirement: PlayerConfig per-player overrides
The system SHALL allow each PlayerConfig to override global defaults for starting credits, starting units, and power output.

#### Scenario: Override starting credits
- **WHEN** a PlayerConfig has `starting_credits = 5000`
- **THEN** PlayerManager uses 5000 as the starting credits for that player instead of GlobalRules.starting_credits

#### Scenario: Use global default credits
- **WHEN** a PlayerConfig has `starting_credits = -1`
- **THEN** PlayerManager uses GlobalRules.starting_credits as the starting credits for that player

#### Scenario: Starting units (field only)
- **WHEN** a PlayerConfig has `starting_units = ["E1", "E1", "BGY"]`
- **THEN** the field is stored on PlayerConfig but no units are spawned (spawning not yet implemented)

#### Scenario: No starting units
- **WHEN** a PlayerConfig has `starting_units = []`
- **THEN** no units are spawned for that player

### Requirement: PlayerConfig identity fields
The system SHALL allow each PlayerConfig to specify display name, faction, team, color, spawn index, and bot status.

#### Scenario: Full player config
- **WHEN** a PlayerConfig is created with all fields set
- **THEN** the PlayerData created from it has matching values

#### Scenario: Bot player
- **WHEN** a PlayerConfig has `is_bot = true`
- **THEN** the resulting PlayerData has `is_bot = true` and can be identified as an AI player

### Requirement: MapConfig loading
PlayerManager SHALL find MapConfig as a child node of the current scene at _ready() time. It SHALL iterate children to find a node of type MapConfig.

#### Scenario: MapConfig found
- **WHEN** the current scene has a MapConfig child node
- **THEN** PlayerManager uses it to initialize players

#### Scenario: MapConfig not found
- **WHEN** the current scene has no MapConfig child node
- **THEN** PlayerManager creates default players (player 0 = human GDI team 1, player 1 = AI Nod team 2) with GlobalRules.starting_credits
