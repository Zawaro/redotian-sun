## MODIFIED Requirements

### Requirement: CellUtil world-to-cell conversion
CellUtil SHALL provide `static func world_to_cell(world_pos: Vector3, grid_cells: Vector2i) -> Vector2i` that converts a centered world position to a cell coordinate. The function SHALL apply the centering offset `(W+H)/2` internally before dividing by `CELL_SIZE`. The optional `grid_cells: Vector2i` parameter SHALL default to `TerrainSystem.grid_cells` when omitted.

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

### Requirement: CellUtil cell-origin-to-world
CellUtil SHALL provide `static func cell_origin_to_world(origin: Vector2i, footprint: Vector2i, grid_cells: Vector2i) -> Vector3` that returns the geometric center of all cell centers in a foundation placed at `origin`. The formula SHALL be `(origin.x + footprint.x * 0.5 - (W+H)/2.0) * CELL_SIZE` for x and `(origin.y + footprint.y * 0.5 - (W+H)/2.0) * CELL_SIZE` for z. Y SHALL be 0.0.

#### Scenario: 3x3 foundation at cell (0,0)
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

### Requirement: CellUtil diamond containment check
CellUtil SHALL provide `static func is_in_diamond(cell: Vector2i, grid_cells: Vector2i) -> bool` that returns true if the cell is owned by the rotated-rectangle raster. The check uses a half-open integer mask: `sum = cell.x + cell.y + 1`, `difference = cell.x - cell.y`. Inside if `sum ≥ W` AND `sum < W + 2*H` AND `difference ≥ -W` AND `difference < W`. This produces exactly `2 * W * H` cells. The visual outline aligns to the half-open raster midpoint at `Vector3(-CELL_SIZE/2, 0, 0)`.

#### Scenario: Cell inside diamond (24×20 map)
- **WHEN** `is_in_diamond(Vector2i(23, 1), Vector2i(24, 20))` is called
- **THEN** `sum=25 ≥ 24`, `sum=25 < 64`, `difference=22 ≥ -24`, `difference=22 < 24` → returns `true`

#### Scenario: Cell outside diamond (24×20 map)
- **WHEN** `is_in_diamond(Vector2i(0, 0), Vector2i(24, 20))` is called
- **THEN** `sum=1 < 24` → returns `false`
