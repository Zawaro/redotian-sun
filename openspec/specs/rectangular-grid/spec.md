## ADDED Requirements

### Requirement: TerrainSystem uses Vector2i grid dimensions
TerrainSystem SHALL store grid dimensions as `Vector2i grid_cells` where `.x` is the horizontal cell count and `.y` is the vertical cell count. The vertex grid SHALL be allocated as `(grid_cells.x + 1) × (grid_cells.y + 1)`.

#### Scenario: Initialize rectangular grid
- **WHEN** `init_grid(50, 80)` is called
- **THEN** `grid_cells` equals `Vector2i(50, 80)` and the vertex grid has 51 rows × 81 columns

#### Scenario: Default grid is square
- **WHEN** TerrainSystem initializes without calling `init_grid`
- **THEN** `grid_cells` equals `Vector2i(50, 50)`

### Requirement: CellUtil accepts Vector2i grid dimensions
`CellUtil.world_to_cell`, `cell_to_world`, and `cell_origin_to_world` SHALL accept `grid_cells: Vector2i`. Because the cell-coordinate square has extent `W+H` on both axes, conversions SHALL use the common center offset `(W+H)/2`.

#### Scenario: World to cell conversion with rectangular grid
- **WHEN** `world_to_cell(Vector3(0, 0, 0), Vector2i(50, 80))` is called
- **THEN** the returned cell is `Vector2i(65,65)`

#### Scenario: Cell to world conversion with rectangular grid
- **WHEN** `cell_to_world(Vector2i(65, 65), Vector2i(50, 80))` is called
- **THEN** the returned world position is `Vector3(1.0, 0.0, 1.0)` because the origin lies between four cell centers

### Requirement: BoundsSystem uses rectangular diamond
BoundsSystem SHALL draw and check a 45° rotated rectangle with 90° corners aligned to the half-open owned-cell raster. The raster center is `Vector3(-CS/2, 0, 0)`, while the gameplay and camera origin remains `Vector3.ZERO`. The diamond vertices for effective dimensions W×H use:
- `long = (W + H) / 2 * CS` — vertex component on the long axis
- `small = (H - W) / 2 * CS` — signed vertex component
- `offset_x = -CS/2` — half-cell raster alignment

Vertices (world XZ): N=(-small+offset_x, -long), E=(long+offset_x, small), S=(small+offset_x, long), W=(-long+offset_x, -small).

South SHALL equal `-North + 2*offset` and West SHALL equal
`-East + 2*offset`, where `offset = Vector3(offset_x, 0, 0)`. Adjacent edge
vectors SHALL have equal-magnitude X/Z components and a zero dot product,
guaranteeing 45° edges and 90° corners.

#### Scenario: Diamond mesh vertices for 24×20 map (W > H)
- **WHEN** `_compute_diamond_vertices(Vector2i(24, 20))` is called with `CELL_SIZE = 2.0`
- **THEN** the 4 vertices are `N(3, 0, -44)`, `E(43, 0, -4)`, `S(-5, 0, 44)`, `W(-45, 0, 4)`

#### Scenario: Diamond mesh vertices for 50×50 map (W = H)
- **WHEN** `_compute_diamond_vertices(Vector2i(50, 50))` is called with `CELL_SIZE = 2.0`
- **THEN** the 4 vertices are `N(-1, 0, -100)`, `E(99, 0, 0)`, `S(-1, 0, 100)`, `W(-101, 0, 0)`

#### Scenario: Opposite quadrants mirror for every parity
- **WHEN** vertices are computed for 50×50, 51×50, 50×51, and 51×51 maps
- **THEN** opposite vertices mirror around `Vector3(-CS/2, 0, 0)`
- **AND** adjacent edges remain at 45° with 90° corners

#### Scenario: Diamond bounds check — cell inside
- **WHEN** `is_in_map_bounds(Vector2i(23, 1))` is called on a 24×20 grid
- **THEN** the half-open check passes and returns `true`

#### Scenario: Diamond bounds check — cell outside
- **WHEN** `is_in_map_bounds(Vector2i(0, 0))` is called on a 24×20 grid
- **THEN** `sum=1 < W=24` and returns `false`

### Requirement: Red map bounds
The red map bounds diamond SHALL use effective dimensions
`(W - 0.5, H - 0.5)`, placing the line through the centers of the outer
owned-cell edges.

#### Scenario: Red bounds for 24×20 map
- **WHEN** red bounds are computed for a 24×20 map with `CELL_SIZE = 2.0`
- **THEN** the effective dimensions are `(23.5, 19.5)` and the vertices are `N(3, 0, -43)`, `E(42, 0, -4)`, `S(-5, 0, 43)`, `W(-44, 0, 4)`

### Requirement: Blue visible bounds
The blue visible bounds diamond SHALL be the red map diamond shrunk independently
by four per-edge insets in cell units: `left_inset`, `right_inset`, `top_inset`,
`bottom_inset`. Defaults SHALL be `left=right=5, top=bottom=4`. In the sum/diff
frame the visible diamond is a rectangle bounded by `sum ∈ [-h+top, h-bottom]`
and `diff ∈ [-w+left, w-right]`.

#### Scenario: Blue bounds for 24×20 map
- **WHEN** blue bounds are computed on a 24×20 map with defaults left=right=5, top=bottom=4
- **THEN** the visible diamond spans `sum ∈ [-16, 15]` and `diff ∈ [-19, 18]`

#### Scenario: Asymmetric insets shift the visible diamond
- **WHEN** insets are `left=8, right=2, top=2, bottom=6` on a 24×20 map
- **THEN** the visible diamond spans `sum ∈ [-18, 13]` and `diff ∈ [-16, 21]`, off the map center

#### Scenario: Zero insets equal the map diamond
- **WHEN** all four insets are `0`
- **THEN** `is_in_play_area(cell)` matches `is_in_map_bounds(cell)` for every cell

### Requirement: BoundsSystem clamp uses centered constraints
BoundsSystem SHALL clamp gameplay and camera points around world origin using
`a = ux + uz ∈ [-H, H]` and `b = ux - uz ∈ [-W, W]`.

#### Scenario: Point at origin stays at origin
- **WHEN** `clamp_to_map_diamond(Vector3.ZERO)` is called
- **THEN** the result is `Vector3.ZERO`

### Requirement: Camera and minimap center on world origin
The gameplay camera pivot and minimap camera SHALL center on world origin. The
minimap camera SHALL use orthographic size `(W+H) * CELL_SIZE`.

#### Scenario: Rectangular map camera center
- **WHEN** a rectangular map is initialized
- **THEN** the gameplay camera pivot XZ and minimap camera XZ are both zero

### Requirement: EditorGrid draws rectangular diamond
EditorGrid SHALL draw grid lines clipped to the diamond boundary. Vertical lines SHALL iterate `range(W+H+1)` and horizontal lines SHALL iterate `range(W+H+1)`. Clipping SHALL use the diamond containment check: for each line position, compute `a` and `b` from the cell coordinate and check against the diamond bounds.

#### Scenario: Grid lines iterate full diamond extent
- **WHEN** `grid_cells = Vector2i(24, 20)` and `CELL_SIZE = 2.0`
- **THEN** both vertical and horizontal line loops iterate `range(45)` (24+20+1)

### Requirement: Pathfinder uses Vector2i grid dimensions
Pathfinder.find_path SHALL accept `grid_cells: Vector2i` for path reconstruction and coordinate conversion. Path waypoints SHALL be converted using centered `CellUtil.cell_to_world(cell, grid_cells)`.

#### Scenario: Path reconstruction with rectangular grid
- **WHEN** `find_path` is called with a rectangular map
- **THEN** waypoints are converted using `CellUtil.cell_to_world(cell, grid_cells)` which applies the centered formula

### Requirement: JSON export uses array format
TerrainSystem.export_to_json SHALL write `grid_cells` as a two-element array `[x, z]`.

#### Scenario: Export rectangular map
- **WHEN** `export_to_json("map.json")` is called with `grid_cells = Vector2i(50, 80)`
- **THEN** the JSON contains `"grid_cells": [50, 80]`

#### Scenario: Import rectangular map
- **WHEN** `import_from_json("map.json")` reads a file with `"grid_cells": [50, 80]`
- **THEN** `grid_cells` is set to `Vector2i(50, 80)` and the vertex grid is 51×81
