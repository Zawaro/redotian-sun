# factions Specification

## Purpose
TBD - created by archiving change load-factions-from-data-sets. Update Purpose after archive.
## Requirements
### Requirement: Faction resource
The system SHALL provide a `Faction` resource (`scripts/data/Faction.gd`) describing one house: a stable string `id`, a human-readable `display_name`, a default `color`, an integer `order` giving the faction's position in the canonical roster, and a boolean `playable` marking whether it is eligible for the default player roster. Faction ids SHALL be the ownership strings used by `EntityData.owner` and SHALL NOT be interpreted as player-slot indices.

#### Scenario: Faction resource carries roster metadata
- **WHEN** a faction `.tres` is loaded
- **THEN** its `id`, `display_name`, `color`, `order`, and `playable` fields are read from the resource

#### Scenario: Order is explicit, not derived from scan order
- **WHEN** two faction resources are scanned from a directory in an unspecified filesystem order
- **THEN** their roster positions come from their `order` fields, not from the scan order

### Requirement: Faction registry loaded from data sets
The system SHALL provide a `FactionCatalog` autoload that registers `<layer root>/factions/` for every ordered `GameDefinition.data_sets` root, at boot and again on every `game_changed`. It SHALL scan each registered directory recursively for `Faction` resources and cache them by `id`, with later layer roots overriding earlier ones. A missing `factions/` subdirectory SHALL warn and continue, not fail the boot. Registration SHALL be idempotent per path.

#### Scenario: Boot populates the registry
- **WHEN** the active game's layer roots contain a `factions/` directory with faction resources
- **THEN** `FactionCatalog` caches each faction by id and `get_faction(id)` returns it

#### Scenario: Later root overrides an id
- **WHEN** the same faction id is defined in an earlier and a later layer root
- **THEN** the later root's definition is the one returned by `get_faction(id)`

#### Scenario: Missing directory warns without crashing
- **WHEN** a layer root has no `factions/` subdirectory
- **THEN** `FactionCatalog` logs a warning for that root and boot proceeds

#### Scenario: Game switch resets and reloads
- **WHEN** `game_changed` is emitted for a different game
- **THEN** the registry is cleared and repopulated from only the new game's layer roots

#### Scenario: Unload empties the registry
- **WHEN** the active game is unloaded (`game_changed` with no definition)
- **THEN** the registry is cleared and holds no factions

### Requirement: Ordered playable roster access
`FactionCatalog` SHALL expose its roster ordered by ascending `order`, and SHALL expose the subset of factions whose `playable` flag is true. The ordered roster SHALL be the single source used to build the house vocabulary and to pick default players.

#### Scenario: Roster is returned in order
- **WHEN** the registry holds factions with `order` 0, 1, 2, and 3
- **THEN** the ordered roster returns them in ascending `order`

#### Scenario: Playable subset excludes passive factions
- **WHEN** the registry holds some factions with `playable` false
- **THEN** the playable subset contains only the factions with `playable` true

#### Scenario: Default roster picks the first two playable factions
- **WHEN** a default roster of two players is requested from a registry with two or more playable factions
- **THEN** the first player receives the lowest-`order` playable faction and the second player receives the next, with each player's color taken from that faction's resource

### Requirement: Faction colors resolve from the registry
Player and UI code SHALL resolve faction colors from the loaded `Faction` resources rather than from a hardcoded id-to-color table. A consumer that cannot match an owner string to a loaded faction SHALL fall back to a neutral default color.

#### Scenario: Cameo tint comes from the faction resource
- **WHEN** the sidebar renders a build item whose owner matches a loaded faction
- **THEN** the cameo tint is that faction's `color` from the registry

#### Scenario: Unmatched owner falls back
- **WHEN** the sidebar renders a build item whose owner matches no loaded faction
- **THEN** the cameo tint is a neutral default color

