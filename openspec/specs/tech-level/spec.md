# tech-level Specification

## Purpose
TBD - created by archiving change add-veterancy-and-tech-gating. Update Purpose after archive.
## Requirements
### Requirement: Current tech level per player
`PlayerData` SHALL carry `tech_level: int`, resolved when a match or mission begins. Resolution SHALL prefer a mission override, then the active `GlobalRules` default. Every playing house in a non-campaign session SHALL receive the same session value. The value SHALL be readable per player for the build-list gate.

#### Scenario: Mission override wins
- **WHEN** a mission sets `tech_level = 3` and the rules default is 10
- **THEN** the player's `PlayerData.tech_level` is 3

#### Scenario: Rules default applied
- **WHEN** a session starts with no mission override
- **THEN** every player's `PlayerData.tech_level` equals the `GlobalRules` default

#### Scenario: Read per player
- **WHEN** two players have different assigned levels
- **THEN** each player's `tech_level` reports its own value

### Requirement: Tech level gates the build list
`PrerequisiteSystem.can_build(player_id, entity_data)` SHALL reject a type with `tech_level == -1` outright, and SHALL reject any type whose positive `tech_level` exceeds the requesting player's current tech level. This follows original TS (`house.cpp`): `-1` is permanently unbuildable, while a positive level at or below the house's level is buildable. The gate SHALL apply to both the sidebar build list and production order checks, since both route through `can_build`. The debug `no_prereqs` override SHALL continue to bypass the gate.

> Note: an omitted `EntityData.tech_level` defaults to `-1` and is therefore unbuildable, matching OpenTS's stored default of `255`. Player-buildable types must carry a positive level.

#### Scenario: Type at or below the current level is buildable
- **WHEN** a player at tech level 5 requests a type with `tech_level = 5`
- **THEN** `can_build` returns true

#### Scenario: Type above the current level is rejected
- **WHEN** a player at tech level 3 requests a type with `tech_level = 7`
- **THEN** `can_build` returns false

#### Scenario: Negative level is permanently unbuildable
- **WHEN** a player at any tech level requests a type with `tech_level = -1`
- **THEN** `can_build` returns false

#### Scenario: Gate applies to orders, not just the sidebar
- **WHEN** a type above the player's level is queued directly through production
- **THEN** the order is refused

#### Scenario: Debug override bypasses the gate
- **WHEN** the debug `no_prereqs` override is active
- **THEN** `can_build` returns true regardless of tech level

### Requirement: Tech level data sources
`Mission` SHALL expose `tech_level: int = -1`, using `-1` as the inherit sentinel consistent with `starting_credits`. `GlobalRules` SHALL expose a default tech level (default `10`, matching the OpenTS non-campaign default) used when no mission override is present.

#### Scenario: Inherit sentinel defers to rules
- **WHEN** `Mission.tech_level` is `-1`
- **THEN** the resolved level comes from `GlobalRules`

#### Scenario: Explicit mission level is used
- **WHEN** `Mission.tech_level` is `4`
- **THEN** the resolved level is 4

