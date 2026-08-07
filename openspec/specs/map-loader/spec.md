## ADDED Requirements

### Requirement: MapLoader reads JSON v3 with entities
`MapLoader.gd` SHALL read a JSON map file and restore both terrain data and entities.

#### Scenario: Load terrain
- **WHEN** MapLoader reads a JSON file with `"vertices"` and `"cells"`
- **THEN** it calls `TerrainSystem.import_from_json()` with those values

#### Scenario: Load entities
- **WHEN** MapLoader reads a JSON file with an `"entities"` array
- **THEN** it calls `EntityFactory.create_entity(id, overrides)` for each entry and adds the entity to the scene

#### Scenario: Empty entities array
- **WHEN** the `"entities"` array is empty or missing
- **THEN** MapLoader skips entity creation (no error)

### Requirement: MapEditor saves entities to JSON
The MapEditor SHALL serialize tracked entities into the `"entities"` array on save.

#### Scenario: Save with entities
- **WHEN** the player clicks Save and the editor has painted entities
- **THEN** the JSON includes an `"entities"` array with each entity's id, cell position, and component overrides

#### Scenario: Save without entities
- **WHEN** there are no tracked entities
- **THEN** the `"entities"` array is empty or omitted

### Requirement: JSON format v3
The map JSON SHALL use format version 3.

#### Scenario: Version field
- **WHEN** MapLoader reads a JSON file
- **THEN** it checks the `"version"` field for format compatibility

### Requirement: JSON format v4
The map JSON SHALL support format version 4, which extends v3 with map dimension fields. Loaders SHALL remain backward compatible with v3 files.

#### Scenario: Version field
- **WHEN** a map is exported
- **THEN** the JSON `"version"` field is `4`

#### Scenario: Dimension fields present in v4
- **WHEN** a map is exported
- **THEN** the JSON includes `"map_size": [grid_cells.x, grid_cells.y]` and `"visible_bounds": [left_inset, right_inset, top_inset, bottom_inset]`

#### Scenario: Backward compatibility with v3
- **WHEN** MapLoader reads a file with `"version": 3` and no `map_size` / `visible_bounds`
- **THEN** it loads terrain and entities without error, deriving bounds from the fallback

### Requirement: Map dimensions persist and restore
`TerrainSystem.export_to_json` SHALL write the full grid extent as `map_size` and the four visible-bounds insets as `visible_bounds`, and `MapLoader` SHALL restore the visible bounds onto `BoundsSystem` when loading a map.

#### Scenario: Round-trip custom visible bounds
- **WHEN** a map with grid `40×40` and insets `(left=5, right=5, top=4, bottom=4)` is exported and then loaded
- **THEN** the JSON `visible_bounds` is `[5, 5, 4, 4]` and after load each `BoundsSystem` inset equals its saved value

#### Scenario: Bounds applied after terrain import
- **WHEN** MapLoader loads a v4 map
- **THEN** it imports terrain first (syncing `BoundsSystem.grid_cells`) and then applies `visible_bounds`, triggering a bounds redraw

#### Scenario: v3 fallback to default insets
- **WHEN** MapLoader loads a file with no `visible_bounds`
- **THEN** `BoundsSystem` visible-bounds insets are set to the default `(5, 5, 4, 4)`

#### Scenario: Clamp negative insets
- **WHEN** a hand-authored `visible_bounds` contains negative values
- **THEN** the recovered insets are clamped to a minimum of `0`

### Requirement: Entity override keys
MapLoader SHALL pass entity overrides using the current field names from EntityData. The override key for resource type SHALL be `resource_type_id` (not the legacy `tiberium_type`).

#### Scenario: Resource entity overrides
- **WHEN** a JSON entity entry has `"resource_type_id": "tiberium_green"`
- **THEN** MapLoader passes `{"resource_type_id": "tiberium_green"}` as overrides to EntityFactory

#### Scenario: Resource amount overrides
- **WHEN** a JSON entity entry has `"resource_amount": 300` and `"resource_max_amount": 300`
- **THEN** MapLoader passes these as overrides to configure the ResourceComponent's HealthComponent
