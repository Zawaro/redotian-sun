# campaign-catalog Specification

## Purpose
Defines the per-game campaign and mission content registry: the Campaign and Mission resource shapes and CampaignCatalog discovery, layering, lookup, and reset.
## Requirements
### Requirement: Campaign resource
The system SHALL provide a `Campaign` resource class (`scripts/data/Campaign.gd`) describing a
linear campaign: `id: String`, `display_name: String`, `faction_id: String`, and
`missions: PackedStringArray` (mission ids in win order). A campaign's first mission SHALL be the
first entry of `missions`.

#### Scenario: Campaign exposes its first mission
- **WHEN** a campaign is created with `missions = ["gdi01", "gdi02"]`
- **THEN** its first mission id is `"gdi01"`

#### Scenario: Empty campaign
- **WHEN** a campaign has an empty `missions` array
- **THEN** it has no first mission and booting from it is refused

### Requirement: Mission resource
The system SHALL provide a `Mission` resource class (`scripts/data/Mission.gd`) describing a
single-player mission overlaid on a map JSON: `id: String`, `display_name: String`,
`map_path: String`, `briefing: String`, `show_briefing: bool` (default `true`),
`player_house: String`, `starting_credits: int` (default `-1`), `home_cell: String`,
and `next_mission_id: String`. Inherit semantics SHALL follow the `MapConfig` convention:
`starting_credits < 0` means inherit, and an empty `player_house` / `home_cell` means inherit.

#### Scenario: Defaults inherit
- **WHEN** a `Mission` is created without setting `starting_credits`, `player_house`, or `home_cell`
- **THEN** `starting_credits` is `-1`, `player_house` is `""`, `home_cell` is `""`, and
  `show_briefing` is `true`

#### Scenario: Explicit override values stored
- **WHEN** a mission sets `starting_credits = 50`, `player_house = "GDI"`, and `home_cell = "49,63"`
- **THEN** the resource returns those exact values

### Requirement: Per-game campaign and mission catalog
The system SHALL provide a `CampaignCatalog` autoload that discovers campaigns from
`<data_set>/campaigns/` and missions from `<data_set>/missions/` for the active game, recursing
into subdirectories and caching each by id (later layer roots win). It SHALL reset and re-register
on `game_changed`, and SHALL tolerate missing directories and failed loads with a warning instead
of crashing.

#### Scenario: Campaigns and missions registered from layer roots
- **WHEN** the active game's data set contains `campaigns/gdi.tres` and `missions/gdi01.tres`
- **THEN** `get_campaign("gdi")` and `get_mission("gdi01")` return those resources

#### Scenario: Later data set wins on id collision
- **WHEN** two layer roots both define a campaign with the same id
- **THEN** the later root's campaign is the one returned

#### Scenario: Missing directories are non-fatal
- **WHEN** a layer root has no `campaigns/` or `missions/` directory
- **THEN** a warning is logged and discovery continues without an error

#### Scenario: Game switch resets content
- **WHEN** `game_changed` fires for a different game
- **THEN** previously registered campaigns and missions are cleared before the new game's are
  registered

### Requirement: Catalog lookup contract
`CampaignCatalog` SHALL expose `list_campaigns() -> Array[Campaign]`, `get_campaign(id) -> Campaign`,
and `get_mission(id) -> Mission`, returning `null` for unknown ids and an empty array when no game
or no content is loaded.

#### Scenario: Unknown id returns null
- **WHEN** `get_mission("nope")` is called
- **THEN** it returns `null`

#### Scenario: Listing with no active game
- **WHEN** no game is selected
- **THEN** `list_campaigns()` returns an empty array

