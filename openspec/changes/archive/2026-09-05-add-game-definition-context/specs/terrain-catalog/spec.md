## MODIFIED Requirements

### Requirement: TerrainCatalog registry
The system SHALL provide a `TerrainCatalog` autoload (`scripts/core/TerrainCatalog.gd`) that scans the terrain subdirectories (`terrain_objects/`, `art/terrain/`, `theaters/`) of each data-set layer root of the active game — as resolved by GameContext at select time — and caches `TerrainObject`, `TerrainArtData`, and `TheaterData` resources by id. The scan SHALL recurse into subdirectories and register only resources of the expected type. The catalog SHALL expose `get_object(id)`, `get_art(id)`, and `get_theater(id)`.

#### Scenario: Objects scanned and cached
- **WHEN** the catalog scans `games/ts/terrain_objects/`
- **THEN** every `<base>_<dir>` TerrainObject resolves via `get_object(id)`

#### Scenario: Art entries scanned and cached
- **WHEN** the catalog scans `games/ts/art/terrain/`
- **THEN** every per-element TerrainArtData resolves via `get_art(id)`

#### Scenario: Theaters scanned and cached
- **WHEN** the catalog scans `games/ts/theaters/`
- **THEN** every TheaterData resolves via `get_theater(id)`

#### Scenario: Unknown id returns null
- **WHEN** `get_object`, `get_art`, or `get_theater` is called with an unregistered id
- **THEN** it returns null without error
