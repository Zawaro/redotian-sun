## MODIFIED Requirements

### Requirement: CellUtil world-to-cell conversion
CellUtil SHALL provide `static func world_to_cell(world_pos: Vector3, grid_cells: Vector2i = Vector2i.ZERO) -> Vector2i` that converts a world position to a cell coordinate. When `grid_cells` is provided and positive, the function SHALL apply the +XZ offset: `cell.x = floori(world_pos.x / CELL_SIZE) - 1` and `cell.y = floori(world_pos.z / CELL_SIZE) - 1`.

#### Scenario: First cell converts from positive world coords
- **WHEN** `world_to_cell(Vector3(2.0, 0, 2.0), Vector2i(32, 24))` is called with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector2i(0, 0)` (first cell)

#### Scenario: Last cell converts from max world coords
- **WHEN** `world_to_cell(Vector3(64.0, 0, 48.0), Vector2i(32, 24))` is called with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector2i(31, 23)` (last cell)

#### Scenario: Origin converts to cell (-1, -1)
- **WHEN** `world_to_cell(Vector3(0, 0, 0), Vector2i(32, 24))` is called
- **THEN** the result is `Vector2i(-1, -1)` (outside grid, below first cell)

### Requirement: CellUtil cell-to-world conversion
CellUtil SHALL provide `static func cell_to_world(cell: Vector2i, grid_cells: Vector2i = Vector2i.ZERO) -> Vector3` that converts a cell coordinate to the center of that cell in world space, offset to +XZ quadrant. Y SHALL be 0.0. The function SHALL compute: `x = (cell.x + 1) * CELL_SIZE`, `z = (cell.y + 1) * CELL_SIZE`.

#### Scenario: Cell (0,0) converts to (2, 0, 2)
- **WHEN** `cell_to_world(Vector2i(0, 0), Vector2i(32, 24))` is called with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(2.0, 0.0, 2.0)`

#### Scenario: Cell (31,23) converts to (64, 0, 48)
- **WHEN** `cell_to_world(Vector2i(31, 23), Vector2i(32, 24))` is called with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(64.0, 0.0, 48.0)`

#### Scenario: All cells are in positive XZ
- **WHEN** `cell_to_world` is called for any valid cell `(i, j)` where `0 <= i < W` and `0 <= j < H`
- **THEN** the result has `x > 0` and `z > 0`

### Requirement: CellUtil cell-origin-to-world
CellUtil SHALL provide `static func cell_origin_to_world(origin: Vector2i, footprint: Vector2i) -> Vector3` that returns the world-space center of a foundation placed at `origin` with the given `footprint` dimensions, offset to +XZ quadrant. Y SHALL be 0.0. The function SHALL compute: `x = (origin.x + footprint.x * 0.5) * CELL_SIZE`, `z = (origin.y + footprint.y * 0.5) * CELL_SIZE`.

#### Scenario: 1x1 foundation at cell (0,0)
- **WHEN** `cell_origin_to_world(Vector2i(0, 0), Vector2i(1, 1))` is called with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(1.0, 0.0, 1.0)` (foundation center, not cell center)

#### Scenario: 3x3 foundation at cell (5,5)
- **WHEN** `cell_origin_to_world(Vector2i(5, 5), Vector2i(3, 3))` is called with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(13.0, 0.0, 13.0)` (center of 3x3 block)
