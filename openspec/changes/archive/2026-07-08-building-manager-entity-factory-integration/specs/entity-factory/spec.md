## MODIFIED Requirements

### Requirement: EntityFactory caching
The factory SHALL cache loaded EntityData resources by id for fast lookup. The factory SHALL provide `get_all_by_type(entity_type: EntityType) -> Array[EntityData]` to query cached entities by category.

#### Scenario: Repeated entity creation
- **WHEN** `create_entity("E1")` is called 10 times
- **THEN** EntityData is loaded once and cached, not re-loaded from disk each time

#### Scenario: Query entities by type
- **WHEN** `get_all_by_type(EntityData.EntityType.BUILDING)` is called
- **THEN** the factory returns an Array[EntityData] containing all cached entities where `entity_type == BUILDING`

#### Scenario: Query returns empty for no matches
- **WHEN** `get_all_by_type(EntityData.EntityType.AIRCRAFT)` is called and no aircraft entities are cached
- **THEN** the factory returns an empty array

#### Scenario: Query includes all subdirectories
- **WHEN** EntityData files exist in `resources/entities/structures/gdi/` and `resources/entities/structures/nod/`
- **THEN** `get_all_by_type(BUILDING)` returns entities from both directories
