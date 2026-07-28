## MODIFIED Requirements

### Requirement: Diamond vertex formula
BoundsSystem SHALL compute diamond vertices for a W×H map as a 45° rotated rectangle with 90° corners aligned to the half-open owned-cell raster. The raster center is `Vector3(-CS/2, 0, 0)`, while the gameplay and camera origin remains `Vector3.ZERO`. The vertex formula uses:
- `long = (W + H) / 2 * CS` — the vertex component on the long axis
- `small = (H - W) / 2 * CS` — the signed vertex component
- `offset_x = -CS/2` — the half-cell alignment required by the raster ownership rule

The four vertices (in world XZ) are:
- North: `(-small + offset_x, 0, -long)`
- East: `(long + offset_x, 0, small)`
- South: `(small + offset_x, 0, long)`
- West: `(-long + offset_x, 0, -small)`

South SHALL equal `-North + 2 * offset` and West SHALL equal
`-East + 2 * offset`, where `offset = Vector3(offset_x, 0, 0)`. Adjacent edge
vectors SHALL have equal-magnitude X/Z components (45°) and a dot product of
zero (90° corners).

#### Scenario: Diamond vertices for 24×20 map (W > H)
- **WHEN** `_compute_diamond_vertices(Vector2i(24, 20))` is called with `CELL_SIZE = 2.0`
- **THEN** `long = 44`, `small = -4`, `offset_x = -1`, and the vertices are `N(3, 0, -44)`, `E(43, 0, -4)`, `S(-5, 0, 44)`, `W(-45, 0, 4)`

#### Scenario: Diamond vertices for 50×50 map (W = H)
- **WHEN** `_compute_diamond_vertices(Vector2i(50, 50))` is called with `CELL_SIZE = 2.0`
- **THEN** `long = 100`, `small = 0`, `offset_x = -1`, and the vertices are `N(-1, 0, -100)`, `E(99, 0, 0)`, `S(-1, 0, 100)`, `W(-101, 0, 0)`

#### Scenario: Diamond vertices for 20×24 map (H > W)
- **WHEN** `_compute_diamond_vertices(Vector2i(20, 24))` is called with `CELL_SIZE = 2.0`
- **THEN** `long = 44`, `small = 4`, `offset_x = -1`, and the vertices are `N(-5, 0, -44)`, `E(43, 0, 4)`, `S(3, 0, 44)`, `W(-45, 0, -4)`

#### Scenario: Opposite quadrants mirror for every parity
- **WHEN** vertices are computed for 50×50, 51×50, 50×51, and 51×51 maps
- **THEN** opposite vertices mirror around `Vector3(-CS/2, 0, 0)` for each map
- **AND** adjacent edges remain at 45° with 90° corners

### Requirement: Diamond containment formula (is_in_diamond)
CellUtil SHALL provide `static func is_in_diamond(cell: Vector2i, grid_cells: Vector2i) -> bool` that returns true if the cell lies within the rotated rectangle diamond. The check SHALL use a half-open integer mask:
- `sum = cell.x + cell.y + 1`
- `difference = cell.x - cell.y`

The cell is inside if and only if: `sum ≥ W` AND `sum < W + 2*H` AND `difference ≥ -W` AND `difference < W`.

This is a half-open interval (one edge inclusive, the opposite exclusive) that assigns each raster boundary cell to exactly one side, producing exactly `2 * W * H` cells for any W×H map. The visual outline SHALL align to the raster midpoint at `Vector3(-CS/2, 0, 0)`.

This is the fundamental diamond containment check. It is used by:
- `BoundsSystem.is_in_map_bounds()` — absolute map boundary for building placement
- `MapEditor._prefill_terrain()` — which cells get initial terrain data
- `TerrainSystem.import_from_json()` — which cells to import
- `Minimap._is_in_diamond()` — minimap visualization

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

### Requirement: Red outer bounds
The red map bounds diamond SHALL follow the same vertex formula using effective cells `(W - 0.5, H - 0.5)`, placing the line through the centers of the outer owned-cell edges.

#### Scenario: Red outer bounds for 24×20 map
- **WHEN** red outer bounds are computed for a 24×20 map with `CELL_SIZE = 2.0`
- **THEN** the effective cells are `(23.5, 19.5)`, giving `long = 43`, `small = -4`, and vertices at `N(3, 0, -43)`, `E(42, 0, -4)`, `S(-5, 0, 43)`, `W(-44, 0, 4)`

### Requirement: Blue visible bounds
The blue visible bounds diamond SHALL follow the same vertex formula, reduced by configurable margins. Default margins SHALL be `Vector2i(5, 4)`, configurable via `visible_offset_x` and `visible_offset_z`. The effective cells SHALL be `(W - offset_x - 0.5, H - offset_z - 0.5)`.

#### Scenario: Blue visible bounds for 24×20 map with default margins
- **WHEN** blue visible bounds are computed for a 24×20 map with default margins `(5, 4)`
- **THEN** the effective cells are `(18.5, 15.5)`, giving `long = 34`, `small = -3`, and vertices at `N(2, 0, -34)`, `E(33, 0, -3)`, `S(-4, 0, 34)`, `W(-35, 0, 3)`

#### Scenario: Custom visible bounds margins
- **WHEN** `visible_offset_x = 3` and `visible_offset_z = 2` on a 24×20 map
- **THEN** the effective cells are `(20.5, 17.5)`, producing a larger visible area

### Requirement: BoundsSystem clamp uses centered diamond constraints
BoundsSystem `_clamp_to_diamond()` SHALL clamp a world point into the diamond using centered sum/diff constraints: `a = ux + uz ∈ [-H, H]` and `b = ux - uz ∈ [-W, W]`, where `ux = p.x / CS` and `uz = p.z / CS`. The result is reconstructed as `ux = (a + b) / 2`, `uz = (a - b) / 2`.

#### Scenario: Point at origin stays at origin
- **WHEN** `clamp_to_map_diamond(Vector3(0, 0, 0))` is called
- **THEN** the result is `Vector3(0, 0, 0)` (origin is inside the diamond)

#### Scenario: Point outside diamond is clamped
- **WHEN** `clamp_to_map_diamond(Vector3(200, 0, 200))` is called on a 50×50 grid
- **THEN** the result is clamped to the diamond boundary

### Requirement: Camera centers on diamond at origin
BoundsSystem `_center_camera_on_diamond()` SHALL position the camera pivot at `Vector3(0, y, 0)` where y is the current Y position.

#### Scenario: Camera pivot at origin
- **WHEN** `_center_camera_on_diamond()` is called
- **THEN** `camera_pivot.global_position` is `Vector3(0, y, 0)`

### Requirement: Minimap camera centered
Minimap SHALL position its orthographic camera at `Vector3(0, 100, 0)` regardless of map size. Camera size SHALL be `(W+H) * CELL_SIZE`.

#### Scenario: Minimap camera position
- **WHEN** minimap initializes on a 50×50 grid
- **THEN** the camera position is `Vector3(0, 100, 0)` and size is `200.0`

### Requirement: Cloud overlay centered
BoundsSystem `_position_cloud_overlay()` SHALL position the cloud overlay at the midpoint between the camera and the diamond center (origin).

#### Scenario: Cloud overlay at origin
- **WHEN** `_position_cloud_overlay()` is called with camera at origin
- **THEN** the cloud overlay position is `Vector3(0, y, 0)`
