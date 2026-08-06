## ADDED Requirements

### Requirement: Resource-occupied cells resolve to the resource land type
`TerrainSystem.get_land_type(cell)` SHALL return the land type `"resource"` for
any cell occupied by a resource crystal, using the existing `SpatialHash`
resource-cell registry as the source of truth. When a cell is not occupied by a
resource crystal, `get_land_type(cell)` SHALL behave as before (painted overlay,
then the default land type). The resolution SHALL stay in sync as crystals are
spawned and depleted, with no resource-component changes.

#### Scenario: Occupied resource cell reads as resource
- **WHEN** a resource crystal occupies a cell and `get_land_type(cell)` is queried
- **THEN** it returns `"resource"` regardless of any painted land type

#### Scenario: Depleted resource cell reverts
- **WHEN** a resource crystal's cell is unregistered from the resource registry
- **THEN** `get_land_type(cell)` returns the cell's painted/default land type again

#### Scenario: No crystal is unchanged
- **WHEN** no resource crystal occupies a cell
- **THEN** `get_land_type(cell)` returns the painted land type or the default
  `"clear"`, exactly as before

### Requirement: Resource resolution drives movement, not routing only
The `resource` land type resolution SHALL be consumed by both the pathfinder's
per-locomotor passability/cost and `MovementController`'s terrain speed factor,
so crystal fields slow actual movement speed as well as pathfinding cost.

#### Scenario: Unit speed slows over a crystal field
- **WHEN** a ground unit with a `resource` terrain speed moves over a
  resource-occupied cell
- **THEN** its effective movement speed is multiplied by its `resource` speed
