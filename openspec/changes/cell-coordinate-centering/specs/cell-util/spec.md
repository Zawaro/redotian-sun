## MODIFIED Requirements

### Requirement: CellUtil world-to-cell conversion
CellUtil SHALL provide `static func world_to_cell(world_pos: Vector3) -> Vector2i` that converts a centered world position to a cell coordinate. The function SHALL apply the grid centering offset internally before dividing by `CELL_SIZE`.

#### Scenario: Origin converts to cell at grid center
- **WHEN** `world_to_cell(Vector3(0, 0, 0))` is called on a 32×32 grid
- **THEN** the result is `Vector2i(16, 16)` (center cell of the grid)

#### Scenario: Positive coordinates
- **WHEN** `world_to_cell(Vector3(3.0, 0, 5.0))` is called with `CELL_SIZE = 2.0` on a 32×32 grid
- **THEN** the result is `Vector2i(17, 18)`

#### Scenario: Negative coordinates
- **WHEN** `world_to_cell(Vector3(-1.0, 0, -3.0))` is called with `CELL_SIZE = 2.0` on a 32×32 grid
- **THEN** the result is `Vector2i(15, 14)`

### Requirement: CellUtil cell-to-world conversion
CellUtil SHALL provide `static func cell_to_world(cell: Vector2i) -> Vector3` that converts a cell coordinate to the center of that cell in world space, centered at world origin (0,0,0). Y SHALL be 0.0. The function SHALL subtract the grid half-size internally.

#### Scenario: Center cell converts to world origin
- **WHEN** `cell_to_world(Vector2i(16, 16))` is called on a 32×32 grid with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(0.0, 0.0, 0.0)` (world origin)

#### Scenario: Cell (0,0) converts to negative world coords
- **WHEN** `cell_to_world(Vector2i(0, 0))` is called on a 32×32 grid with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(-31.0, 0.0, -31.0)`

#### Scenario: Cell (31,31) converts to positive world coords
- **WHEN** `cell_to_world(Vector2i(31, 31))` is called on a 32×32 grid with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(31.0, 0.0, 31.0)`

### Requirement: CellUtil cell-origin-to-world
CellUtil SHALL provide `static func cell_origin_to_world(origin: Vector2i, footprint: Vector2i) -> Vector3` that returns the world-space center of a foundation placed at `origin` with the given `footprint` dimensions, centered at world origin. Y SHALL be 0.0.

#### Scenario: 3x3 foundation at grid center
- **WHEN** `cell_origin_to_world(Vector2i(15, 15), Vector2i(3, 3))` is called on a 32×32 grid with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(-1.0, 0.0, -1.0)` (centered near origin)

#### Scenario: 1x1 foundation at cell (0,0)
- **WHEN** `cell_origin_to_world(Vector2i(0, 0), Vector2i(1, 1))` is called on a 32×32 grid with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(-31.0, 0.0, -31.0)`
