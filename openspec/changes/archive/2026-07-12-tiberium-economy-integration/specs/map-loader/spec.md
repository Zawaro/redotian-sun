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
