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
`CellUtil.world_to_cell`, `cell_to_world`, and `cell_origin_to_world` SHALL accept `grid_cells: Vector2i` and use `.x` for the x-axis and `.y` for the z-axis independently.

#### Scenario: World to cell conversion with rectangular grid
- **WHEN** `world_to_cell(Vector3(0, 0, 0), Vector2i(50, 80))` is called
- **THEN** the returned cell x is `floori((0 + 50 * 2.0 * 0.5) / 2.0) = 25` and cell y is `floori((0 + 80 * 2.0 * 0.5) / 2.0) = 40`

#### Scenario: Cell to world conversion with rectangular grid
- **WHEN** `cell_to_world(Vector2i(25, 40), Vector2i(50, 80))` is called
- **THEN** the returned world position is `Vector3(0.0, 0.0, 0.0)` (center of grid)

### Requirement: BoundsSystem uses rectangular diamond
BoundsSystem SHALL draw and check a rectangular diamond (rhombus) inscribed in a (W+H)*CELL_SIZE square. The diamond vertices SHALL be at world positions:
- Top: (W*CS, 0)
- Left: (0, W*CS)
- Right: ((W+H)*CS, H*CS)
- Bottom: (H*CS, (W+H)*CS)

#### Scenario: Diamond mesh vertices for 32×24 map
- **WHEN** `_compute_diamond_vertices(Vector2i(32, 24))` is called with `CELL_SIZE = 2.0`
- **THEN** the 4 vertices are `(64, 0, 0)`, `(112, 0, 48)`, `(48, 0, 112)`, `(0, 0, 64)`

#### Scenario: Diamond bounds check — cell inside
- **WHEN** `is_in_map_bounds(Vector2i(31, 0))` is called on a 32×24 grid
- **THEN** the check computes `cx=32, cz=1` and verifies `cx+cz=33>=32`, `cx-cz=31<=32`, `cx+cz=33<=80`, `cx-cz=31>=-32` and returns `true`

#### Scenario: Diamond bounds check — cell outside
- **WHEN** `is_in_map_bounds(Vector2i(0, 0))` is called on a 32×24 grid
- **THEN** the check computes `cx=1, cz=1` and `cx+cz=2<32` and returns `false`

### Requirement: EditorGrid draws rectangular diamond
EditorGrid SHALL draw grid lines clipped to the diamond boundary. Vertical lines SHALL iterate `range(W+H+1)` and horizontal lines SHALL iterate `range(W+H+1)`. Clipping formulas SHALL use `|x - W*CS|` and `min(x + W*CS, (W+2H)*CS - x)` for vertical lines.

#### Scenario: Vertical lines use diamond clipping
- **WHEN** `grid_cells = Vector2i(32, 24)` and `CELL_SIZE = 2.0`
- **THEN** the vertical line loop iterates `range(57)` (32+24+1) and at x=64 the z-range is `[0, 96]`

#### Scenario: Horizontal lines use diamond clipping
- **WHEN** `grid_cells = Vector2i(32, 24)` and `CELL_SIZE = 2.0`
- **THEN** the horizontal line loop iterates `range(57)` (32+24+1) and at z=48 the x-range is `[16, 112]`

### Requirement: Pathfinder uses Vector2i grid dimensions
Pathfinder.find_path SHALL accept `grid_cells: Vector2i` for path reconstruction and coordinate conversion.

#### Scenario: Path reconstruction with rectangular grid
- **WHEN** `find_path` is called with a rectangular map
- **THEN** waypoints are converted using `CellUtil.cell_to_world(cell, grid_cells)` which applies the `(cell+1)*CELL_SIZE` formula

### Requirement: JSON export uses array format
TerrainSystem.export_to_json SHALL write `grid_cells` as a two-element array `[x, z]`.

#### Scenario: Export rectangular map
- **WHEN** `export_to_json("map.json")` is called with `grid_cells = Vector2i(50, 80)`
- **THEN** the JSON contains `"grid_cells": [50, 80]`

#### Scenario: Import rectangular map
- **WHEN** `import_from_json("map.json")` reads a file with `"grid_cells": [50, 80]`
- **THEN** `grid_cells` is set to `Vector2i(50, 80)` and the vertex grid is 51×81
