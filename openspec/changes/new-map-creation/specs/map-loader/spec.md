## MODIFIED Requirements

### Requirement: JSON format v3
The map JSON SHALL use format version 4, which extends v3 with map dimension fields. Loaders SHALL remain backward compatible with v3 files.

#### Scenario: Version field
- **WHEN** a map is exported
- **THEN** the JSON `"version"` field is `4`

#### Scenario: Dimension fields present in v4
- **WHEN** a map is exported
- **THEN** the JSON includes `"map_size": [grid_cells.x, grid_cells.y]` and `"visible_bounds": [left_inset, right_inset, top_inset, bottom_inset]`

#### Scenario: Backward compatibility with v3
- **WHEN** MapLoader reads a file with `"version": 3` and no `map_size` / `visible_bounds`
- **THEN** it loads terrain and entities without error, deriving bounds from the fallback

### Requirement: MapEditor saves entities to JSON
The MapEditor SHALL serialize tracked entities into the `"entities"` array on save, and SHALL always write the map file (terrain and dimensions) regardless of whether any entities exist.

#### Scenario: Save with entities
- **WHEN** the player clicks Save and the editor has painted entities
- **THEN** the JSON includes an `"entities"` array with each entity's id, cell position, and component overrides

#### Scenario: Save without entities
- **WHEN** the player clicks Save and there are no tracked entities
- **THEN** the map file is still written, with an empty `"entities"` array, and the terrain and dimension fields are preserved

## ADDED Requirements

### Requirement: Map dimensions persist and restore
`TerrainSystem.export_to_json` SHALL write the full grid extent as `map_size` and the four visible-bounds insets as `visible_bounds`, and `MapLoader` SHALL restore the visible bounds onto `BoundsSystem` when loading a map.

#### Scenario: Round-trip custom visible bounds
- **WHEN** a map with grid `40×40` and visible-bounds insets `(left=5, right=5, top=4, bottom=4)` is exported and then loaded
- **THEN** the JSON `visible_bounds` is `[5, 5, 4, 4]` and after load `BoundsSystem.left_inset == 5`, `right_inset == 5`, `top_inset == 4`, `bottom_inset == 4`

#### Scenario: Round-trip asymmetric visible bounds
- **WHEN** a map with grid `40×40` and asymmetric insets `(left=8, right=2, top=2, bottom=6)` is exported and then loaded
- **THEN** the JSON `visible_bounds` is `[8, 2, 2, 6]` and each inset round-trips unchanged (asymmetry is preserved)

#### Scenario: Bounds applied after terrain import
- **WHEN** MapLoader loads a v4 map
- **THEN** it imports terrain first (syncing `BoundsSystem.grid_cells`) and then applies `visible_bounds`, triggering a bounds redraw

#### Scenario: v3 fallback to default insets
- **WHEN** MapLoader loads a file with no `visible_bounds`
- **THEN** `BoundsSystem` visible-bounds insets are set to the default `(5, 5, 4, 4)`

#### Scenario: Clamp negative insets
- **WHEN** a hand-authored `visible_bounds` contains negative values
- **THEN** the recovered insets are clamped to a minimum of `0`
