## MODIFIED Requirements

### Requirement: MapLoader reads JSON v3 with entities
`MapLoader.gd` SHALL read a JSON map file and restore both terrain data and entities. MapLoader SHALL use `resource_type_id` in the override key list when restoring tiberium entities.

#### Scenario: Load terrain
- **WHEN** MapLoader reads a JSON file with `"vertices"` and `"cells"`
- **THEN** it calls `TerrainSystem.import_from_json()` with those values

#### Scenario: Load entities
- **WHEN** MapLoader reads a JSON file with an `"entities"` array
- **THEN** it calls `EntityFactory.create_entity(id, overrides)` for each entry and adds the entity to the scene

#### Scenario: Load tiberium entity with resource_type_id
- **WHEN** MapLoader reads an entity entry with `resource_type_id = "tiberium_green"` in overrides
- **THEN** the entity is created with the correct resource type

#### Scenario: Empty entities array
- **WHEN** the `"entities"` array is empty or missing
- **THEN** MapLoader skips entity creation (no error)
