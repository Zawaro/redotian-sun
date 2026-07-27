## MODIFIED Requirements

### Requirement: BoundsSystem uses rectangular diamond
BoundsSystem SHALL draw and check a rotated rectangle diamond with vertices computed from `grid_cells` (W×H). For odd `W+H`, the diamond SHALL have 4 vertices where edges meet at corners. For even `W+H`, the diamond SHALL have 8 vertices with short connectors at corners. The diamond check formula SHALL use `CellUtil.is_in_diamond(cell, grid_cells)`. The bounds mesh SHALL be drawn as a closed diamond using `PRIMITIVE_LINE_STRIP`.

#### Scenario: Map bounds check with parallelogram diamond
- **WHEN** `grid_cells = Vector2i(32, 24)` and `is_in_map_bounds(Vector2i(0, 0))` is called
- **THEN** the check uses `CellUtil.is_in_diamond(Vector2i(0, 0), Vector2i(32, 24))` and returns `true`

#### Scenario: Out of bounds with parallelogram diamond
- **WHEN** `grid_cells = Vector2i(32, 24)` and `is_in_map_bounds(Vector2i(31, 0))` is called
- **THEN** the check uses `CellUtil.is_in_diamond(Vector2i(31, 0), Vector2i(32, 24))` and returns `false`

#### Scenario: Even sum diamond mesh uses 8 vertices
- **WHEN** `create_bounds_edges()` draws the outer bounds for `grid_cells = Vector2i(32, 24)`
- **THEN** the 8 vertices are `(0, 0, 64)`, `(64, 0, 0)`, `(66, 0, 0)`, `(112, 0, 48)`, `(112, 0, 50)`, `(50, 0, 112)`, `(48, 0, 112)`, `(0, 0, 66)` in world XYZ

#### Scenario: Odd sum diamond mesh uses 4 vertices
- **WHEN** `create_bounds_edges()` draws the outer bounds for `grid_cells = Vector2i(32, 23)`
- **THEN** the 4 vertices are `(0, 0, 64)`, `(64, 0, 0)`, `(110, 0, 46)`, `(46, 0, 110)` in world XYZ

### Requirement: EditorGrid draws rectangular diamond
EditorGrid SHALL draw grid lines clipped to the parallelogram diamond boundary. Vertical lines at each x position SHALL extend between the diamond's z-bounds at that x. Horizontal lines at each z position SHALL extend between the diamond's x-bounds at that z.

#### Scenario: Vertical lines clipped to diamond
- **WHEN** `grid_cells = Vector2i(32, 24)` and the grid draws a vertical line at `x = 32`
- **THEN** the line extends from `z_min` to `z_max` where the line intersects the diamond edges

#### Scenario: Horizontal lines clipped to diamond
- **WHEN** `grid_cells = Vector2i(32, 24)` and the grid draws a horizontal line at `z = 24`
- **THEN** the line extends from `x_min` to `x_max` where the line intersects the diamond edges
