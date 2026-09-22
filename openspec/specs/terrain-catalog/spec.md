# terrain-catalog Specification

## Purpose
TBD - created by archiving change terrain-art-theater-reframe. Update Purpose after archive.
## Requirements
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

### Requirement: Active theater from map authority
The system SHALL select the active theater from the map JSON: `MapLoader` SHALL read the map's `theater_id` and pass it to `TerrainCatalog.set_active_theater(theater_id)`. `TerrainCatalog` SHALL expose `get_active_theater()` returning the selected theater, falling back to the first registered theater when none is set. Setting an unknown id SHALL fall back to the first registered theater and emit a warning. `GlobalRules` SHALL NOT own theater selection.

#### Scenario: Map theater_id selects the theater
- **WHEN** a map with `"theater_id": "snow"` is loaded
- **THEN** `get_active_theater()` returns the `snow` theater

#### Scenario: No active theater uses the first registered
- **WHEN** no theater has been selected
- **THEN** `get_active_theater()` returns the first registered theater

#### Scenario: Unknown theater id falls back
- **WHEN** `set_active_theater("not_a_theater")` is called
- **THEN** the active theater is the first registered and a warning is emitted

### Requirement: Art resolution through the catalog
The system SHALL resolve a cell's mesh through `TerrainCatalog.resolve_art(object_id, theater_id)`: look up the object, delegate to its `art_data.resolve(object_id, theater_id)`, and return the glb path, submesh id, and rotation. `resolve_cell_art(cell_data, cell)` SHALL resolve a cell pin first when a cell is supplied — a pinned `TerrainObject` id SHALL be resolved for the active theater before the baked `object_id` and the legacy type/variant family; an unknown pinned id SHALL fall back to the derived paths with a warning. Callers without cell context MAY omit the cell, in which case no pin check is performed. When the object has no `art_data`, or resolution has no `model_path`, the catalog SHALL return an invalid resolution and the renderer SHALL draw a pink placeholder mesh for that cell with a warning.

#### Scenario: Resolves shared art for a directional object
- **WHEN** `resolve_art("cliff01_e", "temperate")` is called
- **THEN** it returns the `cliff01` art entry's glb, its submesh, and a 270° rotation

#### Scenario: Theater override changes the mesh
- **WHEN** `resolve_art("cliff01_n", "snow")` is called and the entry overrides snow
- **THEN** it returns the snow GLB path with the same submesh and a 0° rotation

#### Scenario: Pin drives cell resolution
- **WHEN** a cell is pinned to `"cliff01_e"` and `resolve_cell_art` is called for it
- **THEN** the resolution comes from the pinned object, not the cell's derived family

#### Scenario: Unknown pin falls back
- **WHEN** a cell is pinned to an unregistered object id and `resolve_cell_art` is called for it
- **THEN** a warning is emitted and resolution falls back to the derived family

#### Scenario: No cell context ignores pins
- **WHEN** `resolve_cell_art` is called without a cell
- **THEN** no pin check is performed and the derived family resolves

#### Scenario: Missing art renders a pink placeholder
- **WHEN** an object has no `art_data` or its art has no `model_path`
- **THEN** resolution is invalid, a warning is emitted, and the cell renders a pink placeholder mesh

### Requirement: Terrain fallback declared per game
`TerrainCatalog` SHALL obtain its fallback terrain scene from the active `GameDefinition` (`fallback_terrain_scene`), not a hardcoded `res://games/ts/...` path. When no fallback is declared, missing theater art SHALL warn and return null rather than loading another game's asset.

#### Scenario: Declared fallback
- **WHEN** the active game declares a fallback terrain scene
- **THEN** missing theater art resolves to that scene

#### Scenario: No fallback
- **WHEN** the active game declares no fallback and theater art is missing
- **THEN** the catalog warns, returns null, and does not load a TS asset

