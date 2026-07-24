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
CellUtil SHALL provide `static func world_to_cell(world_pos: Vector3) -> Vector2i` that converts a world position to a cell coordinate using `CELL_SIZE`.

#### Scenario: Origin converts to cell (0,0)
- **WHEN** `world_to_cell(Vector3(0, 0, 0))` is called
- **THEN** the result is `Vector2i(0, 0)`

#### Scenario: Positive coordinates
- **WHEN** `world_to_cell(Vector3(3.0, 0, 5.0))` is called with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector2i(1, 2)`

#### Scenario: Negative coordinates
- **WHEN** `world_to_cell(Vector3(-1.0, 0, -3.0))` is called with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector2i(-1, -2)`

### Requirement: CellUtil cell-to-world conversion
CellUtil SHALL provide `static func cell_to_world(cell: Vector2i) -> Vector3` that converts a cell coordinate to the center of that cell in world space, with Y=0.

#### Scenario: Cell (0,0) converts to world center
- **WHEN** `cell_to_world(Vector2i(0, 0))` is called
- **THEN** the result is `Vector3(1.0, 0.0, 1.0)` (center of cell at origin)

#### Scenario: Cell (1,2) converts correctly
- **WHEN** `cell_to_world(Vector2i(1, 2))` is called with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(3.0, 0.0, 5.0)`

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
CellUtil SHALL provide `static func cell_origin_to_world(origin: Vector2i, footprint: Vector2i) -> Vector3` that returns the world-space center of a foundation placed at `origin` with the given `footprint` dimensions, using `CELL_SIZE`. Y SHALL be 0.0.

#### Scenario: 3x3 foundation at origin
- **WHEN** `cell_origin_to_world(Vector2i(0, 0), Vector2i(3, 3))` is called with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(3.0, 0.0, 3.0)` (center of 3x3 block)

#### Scenario: 1x1 foundation
- **WHEN** `cell_origin_to_world(Vector2i(5, 5), Vector2i(1, 1))` is called
- **THEN** the result is `Vector3(11.0, 0.0, 11.0)`

### Requirement: CellUtil max height across footprint
CellUtil SHALL provide `static func get_max_height(origin: Vector2i, footprint: Vector2i, get_height: Callable) -> float` that returns the maximum value of `get_height.call(cell)` across all cells in the foundation footprint.

#### Scenario: Flat terrain
- **WHEN** all cells return height 0.0
- **THEN** the result is `0.0`

#### Scenario: Varied terrain
- **WHEN** cells return heights `[0.0, 2.0, 1.0]`
- **THEN** the result is `2.0`
