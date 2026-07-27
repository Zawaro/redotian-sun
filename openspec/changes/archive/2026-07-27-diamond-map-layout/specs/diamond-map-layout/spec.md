## ADDED Requirements

### Requirement: Diamond containment formula
CellUtil SHALL provide `static func is_in_diamond(cell: Vector2i, grid_cells: Vector2i) -> bool` that returns true if the cell center is within the rotated rectangle diamond defined by `grid_cells` (W×H). The formula SHALL be: `(cx + cz) / ((W + H) * 0.5) <= 1.0` AND (when `W != H`) `|cx - cz| / ((W - H) * 0.5) <= 1.0`, where `cx = cell.x + 0.5` and `cz = cell.y + 0.5`. When `W == H`, only the first condition applies (the second is skipped to avoid division by zero).

#### Scenario: Cell inside diamond
- **WHEN** `is_in_diamond(Vector2i(0, 0), Vector2i(32, 24))` is called
- **THEN** it returns `true` (cell center `(0.5, 0.5)` satisfies the containment formula)

#### Scenario: Cell outside diamond
- **WHEN** `is_in_diamond(Vector2i(31, 0), Vector2i(32, 24))` is called
- **THEN** it returns `false` (cell center `(31.5, 0.5)` exceeds the diamond boundary)

#### Scenario: Square diamond (W == H)
- **WHEN** `is_in_diamond(Vector2i(15, 15), Vector2i(32, 32))` is called
- **THEN** it returns `true` (center cell of a square diamond)

### Requirement: Diamond corner coordinates
For a W×H map, the diamond boundary vertices SHALL depend on `(W + H) % 2`. When the sum is odd, edges connect directly at corners (4 vertices). When the sum is even, each edge has a `CELL_SIZE` offset at each corner before the next starts (8 vertices).

#### Scenario: Even sum diamond corners (32×24)
- **WHEN** the diamond vertices are computed for `grid_cells = Vector2i(32, 24)` with `CELL_SIZE = 2.0`
- **THEN** the 8 vertices are `(0, 64)`, `(64, 0)`, `(66, 0)`, `(112, 48)`, `(112, 50)`, `(50, 112)`, `(48, 112)`, `(0, 66)` in world XZ

#### Scenario: Odd sum diamond corners (32×23)
- **WHEN** the diamond vertices are computed for `grid_cells = Vector2i(32, 23)` with `CELL_SIZE = 2.0`
- **THEN** the 4 vertices are `(0, 64)`, `(64, 0)`, `(110, 46)`, `(46, 110)` in world XZ

#### Scenario: Square diamond corners (32×32)
- **WHEN** the diamond vertices are computed for `grid_cells = Vector2i(32, 32)` with `CELL_SIZE = 2.0`
- **THEN** the 4 vertices are `(0, 64)`, `(64, 0)`, `(128, 64)`, `(64, 128)` in world XZ (sum=64, even → 8 vertices with connectors)

### Requirement: BoundsSystem draws diamond mesh
BoundsSystem SHALL draw the bounds mesh as a closed diamond using `PRIMITIVE_LINE_STRIP`. For odd `W+H`, the mesh SHALL use 4 vertices (edges meet at corners). For even `W+H`, the mesh SHALL use 8 vertices (4 diagonal edges + 4 short connectors at corners). Each diagonal edge SHALL sample terrain height at intermediate points for terrain-following.

#### Scenario: Even sum mesh closes the loop
- **WHEN** `create_bounds_edges()` draws the outer bounds for `grid_cells = Vector2i(32, 24)`
- **THEN** the mesh draws a connected line through all 8 vertices and back to the first vertex

#### Scenario: Odd sum mesh closes the loop
- **WHEN** `create_bounds_edges()` draws the outer bounds for `grid_cells = Vector2i(32, 23)`
- **THEN** the mesh draws a connected line through all 4 vertices and back to the first vertex

#### Scenario: Terrain-following along edges
- **WHEN** terrain has a hill at a point along a diamond edge
- **THEN** the mesh vertex at that point has Y set to terrain height + 0.02

### Requirement: BoundsSystem gameplay API uses diamond check
`BoundsSystem.is_in_map_bounds(cell)` SHALL use `CellUtil.is_in_diamond(cell, grid_cells)` for the containment check. `BoundsSystem.is_in_play_area(cell)` SHALL use the same check with offset grid_cells: `CellUtil.is_in_diamond(cell, grid_cells - Vector2i(offset_x, offset_z))`.

#### Scenario: Map bounds check
- **WHEN** `is_in_map_bounds(Vector2i(0, 0))` is called on a 32×24 grid
- **THEN** it returns `true`

#### Scenario: Play area check with offset
- **WHEN** `is_in_play_area(Vector2i(0, 0))` is called on a 32×24 grid with `offset_x = 10, offset_z = 8`
- **THEN** it checks `is_in_diamond(Vector2i(0, 0), Vector2i(22, 16))`

### Requirement: Camera clamping to diamond AABB
`BoundsSystem.clamp_camera_position()` SHALL clamp the camera to the axis-aligned bounding box of the diamond: `x ∈ [0, (W+H)*CELL_SIZE]`, `z ∈ [0, (W+H)*CELL_SIZE]`.

#### Scenario: Camera clamped to positive quadrant
- **WHEN** the camera is at `(-10, 0, -10)` on a 32×24 grid
- **THEN** it is clamped to `(0, 0, 0)` (minimum of AABB)
