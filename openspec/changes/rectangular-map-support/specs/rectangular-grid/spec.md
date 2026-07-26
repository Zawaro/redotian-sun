## ADDED Requirements

### Requirement: TerrainSystem uses Vector2i grid dimensions
TerrainSystem SHALL store grid dimensions as `Vector2i grid_cells` where `.x` is the horizontal cell count and `.y` is the vertical cell count. The vertex grid SHALL be allocated as `(grid_cells.x + 1) × (grid_cells.y + 1)`.

#### Scenario: Initialize rectangular grid
- **WHEN** `init_grid(50, 80)` is called
- **THEN** `grid_cells` equals `Vector2i(50, 80)` and the vertex grid has 51 rows × 81 columns

#### Scenario: Default grid is square
- **WHEN** TerrainSystem initializes without calling `init_grid`
- **THEN** `grid_cells` equals `Vector2i(64, 64)`

### Requirement: CellUtil accepts Vector2i grid dimensions
`CellUtil.world_to_cell`, `cell_to_world`, and `cell_origin_to_world` SHALL accept `grid_cells: Vector2i` and use `.x` for the x-axis and `.y` for the z-axis independently.

#### Scenario: World to cell conversion with rectangular grid
- **WHEN** `world_to_cell(Vector3(0, 0, 0), Vector2i(50, 80))` is called
- **THEN** the returned cell x is `floori((0 + 50 * 2.0 * 0.5) / 2.0) = 25` and cell y is `floori((0 + 80 * 2.0 * 0.5) / 2.0) = 40`

#### Scenario: Cell to world conversion with rectangular grid
- **WHEN** `cell_to_world(Vector2i(25, 40), Vector2i(50, 80))` is called
- **THEN** the returned world position is `Vector3(0.0, 0.0, 0.0)` (center of grid)

### Requirement: BoundsSystem uses rectangular diamond
BoundsSystem SHALL draw and check a rectangular diamond (rhombus) with separate half-extents for x and z axes. The diamond check formula SHALL be `abs(cx)/half_x + abs(cz)/half_z <= 1.0`.

#### Scenario: Map bounds check with rectangular diamond
- **WHEN** `grid_cells = Vector2i(50, 80)` and `is_in_map_bounds(Vector2i(20, 0))` is called
- **THEN** the check computes `abs(20.5)/24.0 + abs(0.5)/39.0 = 0.854 + 0.013 = 0.867 <= 1.0` and returns `true`

#### Scenario: Out of bounds with rectangular diamond
- **WHEN** `grid_cells = Vector2i(50, 80)` and `is_in_map_bounds(Vector2i(24, 0))` is called
- **THEN** the check computes `abs(24.5)/24.0 + abs(0.5)/39.0 = 1.021 + 0.013 = 1.034 > 1.0` and returns `false`

#### Scenario: Diamond mesh uses separate extents
- **WHEN** `_draw_diamond_mesh` is called with `half_diag = Vector2(24.0, 39.0)`
- **THEN** the 4 corners are `(0, 0, -39.0)`, `(24.0, 0, 0)`, `(0, 0, 39.0)`, `(-24.0, 0, 0)`

### Requirement: EditorGrid draws rectangular diamond
EditorGrid SHALL draw grid lines for a rectangular diamond using separate cell counts for x and z axes.

#### Scenario: Vertical lines use x-axis count
- **WHEN** `grid_cells = Vector2i(50, 80)`
- **THEN** the vertical line loop iterates `range(51)` (cells_x + 1)

#### Scenario: Horizontal lines use z-axis count
- **WHEN** `grid_cells = Vector2i(50, 80)`
- **THEN** the horizontal line loop iterates `range(81)` (cells_z + 1)

### Requirement: Pathfinder uses Vector2i grid dimensions
Pathfinder.find_path SHALL accept `grid_cells: Vector2i` for path reconstruction and coordinate conversion.

#### Scenario: Path reconstruction with rectangular grid
- **WHEN** `find_path` is called with a rectangular map
- **THEN** waypoints are converted using `CellUtil.cell_to_world(cell, grid_cells)` with the correct Vector2i value

### Requirement: JSON export uses array format
TerrainSystem.export_to_json SHALL write `grid_cells` as a two-element array `[x, z]`.

#### Scenario: Export rectangular map
- **WHEN** `export_to_json("map.json")` is called with `grid_cells = Vector2i(50, 80)`
- **THEN** the JSON contains `"grid_cells": [50, 80]`

#### Scenario: Import rectangular map
- **WHEN** `import_from_json("map.json")` reads a file with `"grid_cells": [50, 80]`
- **THEN** `grid_cells` is set to `Vector2i(50, 80)` and the vertex grid is 51×81
