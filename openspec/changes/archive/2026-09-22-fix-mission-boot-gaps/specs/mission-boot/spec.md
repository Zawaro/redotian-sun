## MODIFIED Requirements

### Requirement: Mission override precedence
Starting a mission SHALL resolve per-player values with precedence **mission > map > global rules**:
a mission value that is set SHALL win, otherwise the map's own value SHALL be used, otherwise the
active game's `GlobalRules`. The map layer SHALL be sourced from the map's `MapConfig` — built from
the map JSON's optional top-level `players` array — and SHALL be resolved by
`PlayerManager.begin_mission(mission, map_config)`. `PlayerManager` SHALL apply the resolved
`starting_credits` and `player_house` to the local player when a mission starts.

#### Scenario: Mission credits beat global
- **WHEN** a mission with `starting_credits = 50` starts while `GlobalRules.starting_credits = 10000`
- **THEN** the local player's credits are `50`

#### Scenario: Inherit falls back to global
- **WHEN** a mission with `starting_credits = -1` starts
- **THEN** the local player's credits equal `GlobalRules.starting_credits`

#### Scenario: Mission house overrides the default faction
- **WHEN** a mission with `player_house = "GDI"` starts
- **THEN** the local player's faction is `GDI`

#### Scenario: Map credits used when the mission inherits
- **WHEN** a mission with `starting_credits = -1` starts on a map whose `players` array sets the
  local player's `starting_credits = 200`
- **THEN** the local player's credits are `200`

## ADDED Requirements

### Requirement: Mission start occludes menu overlays
Starting a mission SHALL hide the menu overlays so the running mission is the only visible surface:
the main menu and the boot screen SHALL both be hidden.

#### Scenario: Boot screen hidden on mission start
- **WHEN** a mission starts with the boot screen visible
- **THEN** both the boot screen and the main menu are hidden

#### Scenario: Main menu hidden on mission start
- **WHEN** a mission starts with the main menu visible
- **THEN** both the main menu and the boot screen are hidden
