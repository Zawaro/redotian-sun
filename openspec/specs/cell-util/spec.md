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
CellUtil SHALL provide `static func world_to_cell(world_pos: Vector3, grid_cells: Vector2i) -> Vector2i` that converts a centered world position to a cell coordinate. The function SHALL apply the centering offset `(W+H)/2` internally: `floori(world_pos.x / CELL_SIZE + (W+H)/2)` for x and `floori(world_pos.z / CELL_SIZE + (W+H)/2)` for z. The optional `grid_cells: Vector2i` parameter SHALL default to `TerrainSystem.grid_cells` when omitted.

#### Scenario: Origin converts to diamond center cell
- **WHEN** `world_to_cell(Vector3(0, 0, 0))` is called on a 50×50 grid
- **THEN** the result is `Vector2i(50, 50)` (the diamond center)

#### Scenario: World to cell with rectangular grid
- **WHEN** `world_to_cell(Vector3(0, 0, 0), Vector2i(50, 80))` is called
- **THEN** the result is `Vector2i(65, 65)` (the diamond center for 50×80)

#### Scenario: Cell (0,0) center
- **WHEN** `world_to_cell(Vector3(-99.0, 0, -99.0))` is called on a 50×50 grid with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector2i(0, 0)`

### Requirement: CellUtil cell-to-world conversion
CellUtil SHALL provide `static func cell_to_world(cell: Vector2i, grid_cells: Vector2i) -> Vector3` that converts a cell coordinate to the center of that cell in world space, centered at world origin (0,0,0). The formula SHALL be `(cell.x + 0.5 - (W+H)/2.0) * CELL_SIZE` for x and `(cell.y + 0.5 - (W+H)/2.0) * CELL_SIZE` for z. Y SHALL be 0.0. The optional `grid_cells: Vector2i` parameter SHALL default to `TerrainSystem.grid_cells` when omitted.

#### Scenario: Diamond center maps to world origin
- **WHEN** `cell_to_world(Vector2i(50, 50))` is called on a 50×50 grid with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(1.0, 0.0, 1.0)` (near origin, since center is between cells)

#### Scenario: Cell to world with rectangular grid
- **WHEN** `cell_to_world(Vector2i(25, 40), Vector2i(50, 80))` is called
- **THEN** the returned world position is `Vector3(-79.0, 0.0, -49.0)` (offset from center)

#### Scenario: Cell (0,0) converts to negative world coords
- **WHEN** `cell_to_world(Vector2i(0, 0))` is called on a 50×50 grid with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(-99.0, 0.0, -99.0)` (negative quadrant)

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
CellUtil SHALL provide `static func cell_origin_to_world(origin: Vector2i, footprint: Vector2i, grid_cells: Vector2i) -> Vector3` that returns the geometric center of all cell centers in a foundation placed at `origin`. The formula SHALL be `(origin.x + footprint.x * 0.5 - (W+H)/2.0) * CELL_SIZE` for x and `(origin.y + footprint.y * 0.5 - (W+H)/2.0) * CELL_SIZE` for z. Y SHALL be 0.0.

#### Scenario: 3x3 foundation at cell (0,0) on 50×50 grid
- **WHEN** `cell_origin_to_world(Vector2i(0, 0), Vector2i(3, 3))` is called on a 50×50 grid with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(-97.0, 0.0, -97.0)` (centered coords)

#### Scenario: 1x1 foundation at diamond center
- **WHEN** `cell_origin_to_world(Vector2i(50, 50), Vector2i(1, 1))` is called on a 50×50 grid with `CELL_SIZE = 2.0`
- **THEN** the result is `Vector3(1.0, 0.0, 1.0)` (near origin)

### Requirement: CellUtil world-to-cell-origin
CellUtil SHALL provide `static func world_to_cell_origin(world_pos: Vector3, footprint: Vector2i, grid_cells: Vector2i) -> Vector2i` as the inverse of `cell_origin_to_world` for grid-aligned foundations. It SHALL work for odd and even footprint dimensions and all map-size parities.

#### Scenario: Rectangular foundation round-trip
- **WHEN** a 3×2 foundation at cell `(47,49)` is converted to world space and back on a 51×50 map
- **THEN** `world_to_cell_origin` returns `Vector2i(47,49)`

### Requirement: World origin is parity-independent
The continuous map origin SHALL always remain world `Vector3(0,0,0)`. When
`W+H` is odd, one cell center lies exactly at the origin. When `W+H` is even,
the origin is the shared corner between four cell centers.

#### Scenario: Mixed parity map
- **WHEN** a 51×50 map is initialized
- **THEN** cell `(50,50)` is centered at world origin

#### Scenario: Same parity map
- **WHEN** a 51×51 map is initialized
- **THEN** world origin remains `(0,0,0)` and lies between four cell centers

### Requirement: CellUtil max height across footprint
CellUtil SHALL provide `static func get_max_height(origin: Vector2i, footprint: Vector2i, get_height: Callable) -> float` that returns the maximum value of `get_height.call(cell)` across all cells in the foundation footprint.

#### Scenario: Flat terrain
- **WHEN** all cells return height 0.0
- **THEN** the result is `0.0`

#### Scenario: Varied terrain
- **WHEN** cells return heights `[0.0, 2.0, 1.0]`
- **THEN** the result is `2.0`

### Requirement: CellUtil diamond containment check
CellUtil SHALL provide `static func is_in_diamond(cell: Vector2i, grid_cells: Vector2i) -> bool` that returns true if the cell lies within the rotated rectangle diamond defined by `grid_cells` (W×H). The check SHALL use a half-open integer mask to avoid double-counting boundary cells:
- `sum = cell.x + cell.y + 1`
- `difference = cell.x - cell.y`
- Inside if: `sum ≥ W` AND `sum < W + 2*H` AND `difference ≥ -W` AND `difference < W`

This is a half-open interval (one edge inclusive, the opposite exclusive) that assigns each raster boundary cell to exactly one side. It produces exactly `2 * W * H` cells for any W×H map. The visual outline aligns to the half-open raster midpoint at `Vector3(-CELL_SIZE/2, 0, 0)`.

This is the fundamental diamond containment check, used for map bounds, terrain prefill, building placement, and minimap visualization.

#### Scenario: Cell inside diamond (24×20 map)
- **WHEN** `is_in_diamond(Vector2i(24, 0), Vector2i(24, 20))` is called
- **THEN** `sum=25 ≥ 24`, `sum=25 < 64`, `difference=24 ≥ -24`, `difference=24 < 24`? NO → returns `false` (half-open: NE edge excluded)

#### Scenario: Cell inside diamond (24×20 map)
- **WHEN** `is_in_diamond(Vector2i(23, 1), Vector2i(24, 20))` is called
- **THEN** `sum=25 ≥ 24`, `sum=25 < 64`, `difference=22 ≥ -24`, `difference=22 < 24` → returns `true`

#### Scenario: Cell outside diamond (24×20 map)
- **WHEN** `is_in_diamond(Vector2i(0, 0), Vector2i(24, 20))` is called
- **THEN** `sum=1 < 24` → returns `false`

#### Scenario: Square diamond (W = H)
- **WHEN** `is_in_diamond(Vector2i(50, 50), Vector2i(50, 50))` is called
- **THEN** returns `true` (one of the four cells adjacent to world origin)

#### Scenario: Cell count is exactly 2*W*H
- **WHEN** all cells in a 21×33 grid are checked
- **THEN** exactly 1386 cells return `true` (2 × 21 × 33)
