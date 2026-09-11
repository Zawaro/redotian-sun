## MODIFIED Requirements

### Requirement: PlayerManager autoload
The system SHALL provide a `PlayerManager.gd` autoload singleton that serves as the central player registry. It SHALL own all PlayerData instances and provide lookup methods for player queries. PlayerManager SHALL be registered immediately after `GameContext` and `FactionCatalog`, before every other autoload.

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
The system SHALL initialize players from a MapConfig resource at `_ready()`. MapConfig is found as a child node of the current scene. If no MapConfig is found, it SHALL build the default roster from the loaded faction registry: player 0 = local human using the first playable faction (lowest `order`), player 1 = AI bot using the next playable faction, each with that faction's `color`; if fewer than two playable factions are loaded, a missing slot SHALL use an empty faction id and the default color. Player display names, teams, and spawn indices SHALL remain engine-assigned.

#### Scenario: Initialize from MapConfig
- **WHEN** PlayerManager._ready() runs and a MapConfig child node is found in the current scene
- **THEN** it creates PlayerData instances for each PlayerConfig in MapConfig.players

#### Scenario: Initialize with defaults from factions
- **WHEN** PlayerManager._ready() runs and no MapConfig child node is found
- **THEN** it creates player 0 (local human, first playable faction, team 1) and player 1 (AI bot, second playable faction, team 2) with those factions' colors and GlobalRules.starting_credits

#### Scenario: Empty registry falls back gracefully
- **WHEN** PlayerManager._ready() runs with no MapConfig and no loaded factions
- **THEN** it still creates player 0 and player 1 with empty faction ids and the default color, without crashing

### Requirement: PlayerManager autoload order
The system SHALL register the player and faction autoloads in the order `GameContext`, `FactionCatalog`, `PlayerManager`, then all remaining autoloads in `project.godot`, so PlayerManager may read the resolved game's factions in its `_ready()`.

#### Scenario: Autoload order
- **WHEN** the game starts
- **THEN** GameContext resolves the active game first, FactionCatalog registers that game's factions second, and PlayerManager._ready() runs third, before EconomyManager and all other autoloads
