## ADDED Requirements

### Requirement: CellUtil constants
CellUtil SHALL define `CELL_SIZE: float = 2.0`, `SQRT2: float = 1.41421356237`, and `CELL_KEY_OFFSET: int = 512` as class constants.

#### Scenario: CELL_SIZE is accessible
- **WHEN** `CellUtil.CELL_SIZE` is referenced
- **THEN** the value is `2.0`

#### Scenario: SQRT2 is accessible
- **WHEN** `CellUtil.SQRT2` is referenced
- **THEN** the value is `1.41421356237`

### Requirement: CellUtil world-to-cell conversion
CellUtil SHALL provide `static func world_to_cell(world_pos: Vector3) -> Vector2i` that converts a world position to a cell coordinate. The function SHALL apply the +1 offset (cell 0,0 maps to world (CELL_SIZE, CELL_SIZE)).

#### Scenario: Origin converts to cell at (-1, -1)
- **WHEN** `world_to_cell(Vector3(0, 0, 0))` is called
- **THEN** the result is `Vector2i(-1, -1)` (outside the grid)

#### Scenario: Cell (0,0) center
- **WHEN** `world_to_cell(Vector3(2.0, 0, 2.0))` is called with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector2i(0, 0)`

#### Scenario: Cell (4,6) center
- **WHEN** `world_to_cell(Vector3(10.0, 0, 14.0))` is called with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector2i(4, 6)`

### Requirement: CellUtil cell-to-world conversion
CellUtil SHALL provide `static func cell_to_world(cell: Vector2i) -> Vector3` that converts a cell coordinate to the center of that cell in world space. The formula SHALL be `(cell.x + 1) * CELL_SIZE` for x and `(cell.y + 1) * CELL_SIZE` for z. Y SHALL be 0.0.

#### Scenario: Cell (0,0) converts to (CELL_SIZE, 0, CELL_SIZE)
- **WHEN** `cell_to_world(Vector2i(0, 0))` is called with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(2.0, 0.0, 2.0)`

#### Scenario: Cell (4,6) converts to world
- **WHEN** `cell_to_world(Vector2i(4, 6))` is called with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(10.0, 0.0, 14.0)`

#### Scenario: Cell (31,31) converts to world on 32×32 grid
- **WHEN** `cell_to_world(Vector2i(31, 31))` is called with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(64.0, 0.0, 64.0)`

### Requirement: CellUtil integer cell key
CellUtil SHALL provide `static func cell_key(cell: Vector2i) -> int` that produces a unique integer key for any cell coordinate, suitable for use as a Dictionary key. The key SHALL be deterministic and collision-free within the valid cell range.

#### Scenario: Deterministic key
- **WHEN** `cell_key(Vector2i(0, 0))` is called twice
- **THEN** both calls return the same value

#### Scenario: Different cells produce different keys
- **WHEN** `cell_key(Vector2i(0, 0))` and `cell_key(Vector2i(1, 0))` are called
- **THEN** the results are different

### Requirement: CellUtil string cell key
CellUtil SHALL provide `static func cell_key_str(cell: Vector2i) -> String` that produces a string key in the format `"x,y"`.

#### Scenario: String key format
- **WHEN** `cell_key_str(Vector2i(3, 7))` is called
- **THEN** the result is `"3,7"`

### Requirement: CellUtil A* heuristic
CellUtil SHALL provide `static func heuristic(a: Vector2i, b: Vector2i) -> float` that returns the octile distance between two cells, using `CELL_SIZE` and `SQRT2`.

#### Scenario: Same cell returns zero
- **WHEN** `heuristic(Vector2i(5, 5), Vector2i(5, 5))` is called
- **THEN** the result is `0.0`

#### Scenario: Adjacent cell returns CELL_SIZE
- **WHEN** `heuristic(Vector2i(0, 0), Vector2i(1, 0))` is called
- **THEN** the result is `CELL_SIZE`

#### Scenario: Diagonal cell returns CELL_SIZE * SQRT2
- **WHEN** `heuristic(Vector2i(0, 0), Vector2i(1, 1))` is called
- **THEN** the result is `CELL_SIZE * SQRT2`

### Requirement: CellUtil spiral first free
CellUtil SHALL provide `static func spiral_first_free(center: Vector2i, max_radius: int, is_occupied: Callable) -> Vector2i` that returns the first cell in an expanding spiral from `center` where `is_occupied.call(cell)` returns `false`. If `center` is already free, it SHALL be returned immediately. If no free cell is found within `max_radius`, `center` SHALL be returned as fallback.

#### Scenario: Center is free
- **WHEN** `spiral_first_free(Vector2i(5, 5), 4, func(c): return false)` is called
- **THEN** the result is `Vector2i(5, 5)`

#### Scenario: Center occupied, neighbor free
- **WHEN** `spiral_first_free(Vector2i(5, 5), 4, func(c): return c == Vector2i(5, 5))` is called
- **THEN** the result is a cell adjacent to `(5, 5)` at radius 1

#### Scenario: No free cell found
- **WHEN** `spiral_first_free(Vector2i(5, 5), 1, func(c): return true)` is called
- **THEN** the result is `Vector2i(5, 5)` (fallback)

### Requirement: CellUtil cell-origin-to-world
CellUtil SHALL provide `static func cell_origin_to_world(origin: Vector2i, footprint: Vector2i) -> Vector3` that returns the world-space center of a foundation placed at `origin` with the given `footprint` dimensions. The formula SHALL be `(origin.x + footprint.x * 0.5) * CELL_SIZE` for x and `(origin.y + footprint.y * 0.5) * CELL_SIZE` for z. Y SHALL be 0.0.

#### Scenario: 3x3 foundation at cell (0,0)
- **WHEN** `cell_origin_to_world(Vector2i(0, 0), Vector2i(3, 3))` is called with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(3.0, 0.0, 3.0)`

#### Scenario: 1x1 foundation at cell (4,6)
- **WHEN** `cell_origin_to_world(Vector2i(4, 6), Vector2i(1, 1))` is called with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(10.0, 0.0, 14.0)`

### Requirement: CellUtil max height across footprint
CellUtil SHALL provide `static func get_max_height(origin: Vector2i, footprint: Vector2i, get_height: Callable) -> float` that returns the maximum value of `get_height.call(cell)` across all cells in the foundation footprint.

#### Scenario: Flat terrain
- **WHEN** all cells return height 0.0
- **THEN** the result is `0.0`

#### Scenario: Varied terrain
- **WHEN** cells return heights `[0.0, 2.0, 1.0]`
- **THEN** the result is `2.0`
