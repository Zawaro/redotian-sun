## ADDED Requirements

### Requirement: Building placement blocks on moving units
`BuildingManager._is_cell_free()` SHALL return `false` for any cell occupied by a non-resource entity, regardless of the entity's movement state (IDLE, MOVING, ROTATING, etc.).

#### Scenario: Moving unit blocks placement
- **WHEN** a unit is in MOVING state on cell (5, 5)
- **AND** the player attempts to place a building whose foundation covers cell (5, 5)
- **THEN** `_is_cell_free(Vector2i(5, 5))` returns `false`
- **AND** the foundation preview shows red for that cell

#### Scenario: Idle unit still blocks placement
- **WHEN** a unit is in IDLE state on cell (5, 5)
- **AND** the player attempts to place a building whose foundation covers cell (5, 5)
- **THEN** `_is_cell_free(Vector2i(5, 5))` returns `false`

#### Scenario: Empty cell allows placement
- **WHEN** no entity occupies cell (5, 5)
- **AND** the cell is not a building, resource, or bib cell
- **THEN** `_is_cell_free(Vector2i(5, 5))` returns `true`

#### Scenario: Resource entity does not double-block
- **WHEN** a resource pod entity occupies cell (5, 5)
- **AND** no other entity occupies the cell
- **THEN** `_is_cell_free(Vector2i(5, 5))` returns `false` (via existing `_has_resource_on_cell` check)
- **AND** the new entity occupancy check does not additionally flag it

### Requirement: SpatialHash exposes entity occupancy check
`SpatialHash` SHALL provide an `is_any_entity_on_cell(cell: Vector2i) -> bool` method that returns `true` if any non-resource entity is registered in `_grid` for the given cell.

#### Scenario: Cell with moving entity
- **WHEN** a unit with `MovementController.State.MOVING` is at cell (3, 4)
- **THEN** `SpatialHash.instance.is_any_entity_on_cell(Vector2i(3, 4))` returns `true`

#### Scenario: Cell with idle entity
- **WHEN** a unit with `MovementController.State.IDLE` is at cell (3, 4)
- **THEN** `SpatialHash.instance.is_any_entity_on_cell(Vector2i(3, 4))` returns `true`

#### Scenario: Cell with only resource entity
- **WHEN** only a resource pod entity is at cell (3, 4)
- **THEN** `SpatialHash.instance.is_any_entity_on_cell(Vector2i(3, 4))` returns `false`

#### Scenario: Empty cell
- **WHEN** no entities are at cell (3, 4)
- **THEN** `SpatialHash.instance.is_any_entity_on_cell(Vector2i(3, 4))` returns `false`
