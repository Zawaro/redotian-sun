## MODIFIED Requirements

### Requirement: PlayerData resource
The system SHALL provide a `PlayerData.gd` resource class for per-player identity and economy state. Economy state SHALL be stored as a category-keyed map of stored values (`stored_by_category`) plus a separate `free_credits` counter. `stored_by_category` holds harvested/deposited value per category (subject to storage capacity, and what the storage bar reflects); `free_credits` holds starting credits, crate bonuses, debug money, and sell refunds (never subject to capacity).

#### Scenario: Create player with identity fields
- **WHEN** a PlayerData resource is created with `player_id = 0`, `faction_id = "GDI"`, `color = Color.BLUE`, `team_id = 1`, `spawn_index = 0`, `display_name = "Player 1"`, `is_bot = false`
- **THEN** the resource holds all specified values

#### Scenario: Default values
- **WHEN** a PlayerData is created without setting fields
- **THEN** `player_id = 0`, `stored_by_category` is empty, `free_credits = 0`, `faction_id = ""`, `color = Color.WHITE`, `team_id = 0`, `spawn_index = 0`, `display_name = ""`, `is_bot = false`

#### Scenario: Create player with starting credits as free credits
- **WHEN** a PlayerData resource is created and `free_credits = 1000`
- **THEN** `free_credits` holds 1000 and `stored_by_category` is empty

#### Scenario: Stored and free coexist
- **WHEN** a PlayerData has 500 in its tiberium stored category and `free_credits = 1000`
- **THEN** `stored_by_category["tiberium"]` holds 500 and `free_credits` holds 1000

#### Scenario: Bot player
- **WHEN** a PlayerData has `is_bot = true`
- **THEN** the player can be identified as an AI player
