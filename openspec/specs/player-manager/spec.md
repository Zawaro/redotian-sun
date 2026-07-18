## ADDED Requirements

### Requirement: PlayerManager autoload
The system SHALL provide a `PlayerManager.gd` autoload singleton that serves as the central player registry. It SHALL own all PlayerData instances and provide lookup methods for player queries. PlayerManager SHALL be the first autoload in load order.

#### Scenario: Get local player ID
- **WHEN** `PlayerManager.get_local_player_id()` is called
- **THEN** it returns the integer ID of the local human player (set during initialization from MapConfig)

#### Scenario: Get player data
- **WHEN** `PlayerManager.get_player_data(player_id)` is called with a valid player_id
- **THEN** it returns the PlayerData resource for that player

#### Scenario: Get player data — lazy creation
- **WHEN** `PlayerManager.get_player_data(player_id)` is called with an unknown player_id
- **THEN** it creates a new PlayerData with that player_id, stores it, and returns it

#### Scenario: Check enemy relationship
- **WHEN** `PlayerManager.is_enemy(a_id, b_id)` is called
- **THEN** it returns `true` if the two players have different team_id values, `false` if same team

#### Scenario: Get all players
- **WHEN** `PlayerManager.get_all_players()` is called
- **THEN** it returns an Array of all registered PlayerData resources

#### Scenario: Get players by team
- **WHEN** `PlayerManager.get_players_by_team(team_id)` is called
- **THEN** it returns an Array of PlayerData resources where `team_id` matches

### Requirement: PlayerManager initialization from MapConfig
The system SHALL initialize players from a MapConfig resource at `_ready()`. MapConfig is found as a child node of the current scene. If no MapConfig is found, it SHALL create default players (player 0 = local human with GDI faction, player 1 = AI bot with Nod faction).

#### Scenario: Initialize from MapConfig
- **WHEN** PlayerManager._ready() runs and a MapConfig child node is found in the current scene
- **THEN** it creates PlayerData instances for each PlayerConfig in MapConfig.players

#### Scenario: Initialize with defaults
- **WHEN** PlayerManager._ready() runs and no MapConfig child node is found
- **THEN** it creates player 0 (local human, GDI, team 1) and player 1 (AI bot, Nod, team 2) with GlobalRules.starting_credits

### Requirement: PlayerManager autoload order
The system SHALL register PlayerManager as an autoload BEFORE all other autoloads in project.godot, ensuring PlayerManager is available when other autoloads' _ready() methods run.

#### Scenario: Autoload order
- **WHEN** the game starts
- **THEN** PlayerManager._ready() executes before EconomyManager._ready() and all other autoloads
