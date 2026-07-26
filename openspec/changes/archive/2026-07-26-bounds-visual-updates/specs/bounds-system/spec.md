## ADDED Requirements

### Requirement: BoundsSystem is autoload singleton
BoundsSystem SHALL be registered as an autoload singleton in `project.godot` and accessible via the global `BoundsSystem` reference.

### Requirement: BoundsSystem depends on TerrainSystem
BoundsSystem SHALL access `TerrainSystem` via `get_node_or_null("/root/TerrainSystem")` for dynamic access. When TerrainSystem is unavailable, BoundsSystem SHALL use a default `grid_cells` value and produce flat meshes at Y=0.02. The `Engine.is_editor_hint()` guard prevents TerrainSystem access when the Redot IDE inspects the autoload — this is distinct from the in-game map editor (which uses `has_meta("is_map_editor")`).

#### Scenario: TerrainSystem available at runtime
- **WHEN** the game is running and TerrainSystem is loaded
- **THEN** BoundsSystem reads `grid_cells` from TerrainSystem

#### Scenario: TerrainSystem unavailable in Redot IDE
- **WHEN** BoundsSystem is inspected by the Redot IDE (`Engine.is_editor_hint() == true`)
- **THEN** BoundsSystem uses default `grid_cells` and mesh vertices have Y=0.02

### Requirement: Gameplay API returns cell units
All gameplay API methods SHALL return values in **cell units** (not world units). The visual mesh multiplies by `CELL_SIZE` for world-space rendering. This keeps the diamond check formula consistent with existing consumer code.

#### Scenario: Cell units vs world units
- **WHEN** `get_map_half_diag()` is called on a 32×32 grid
- **THEN** it returns `15.0` (cell units), not `30.0` (world units)

### Requirement: Outer bounds margin
The outer bounds (red) diamond SHALL use `(grid_cells - 2) / 2.0` as the half-diagonal in cell units, placing the visual boundary 1 cell inwards on both axes from the grid edge. The visual mesh converts to world units: `(grid_cells - 2) * CELL_SIZE / 2.0`.

#### Scenario: Outer bounds half-diagonal on 32×32 grid
- **WHEN** `get_map_half_diag()` is called on a 32×32 grid
- **THEN** it returns `15.0` (cell units)

### Requirement: Visible bounds with configurable offset
The visible bounds (blue) diamond SHALL use configurable offsets from the outer bounds. BoundsSystem SHALL expose `visible_offset_x: int` (default 10) and `visible_offset_z: int` (default 8) exports in cell units. The visible bounds diamond uses the **smaller** offset: `half_diag = (grid_cells - 2 - min(offset_x, offset_z)) / 2.0` in cell units.

#### Scenario: Default visible bounds on 32×32 grid
- **WHEN** `get_play_area_half_diag()` is called on a 32×32 grid with default offsets (x=10, z=8)
- **THEN** it returns `11.0` (cell units) — uses the smaller offset (8)

#### Scenario: Custom offset
- **WHEN** `visible_offset_x` is set to `5` on a 32×32 grid (z stays at 8)
- **THEN** `get_play_area_half_diag()` returns `12.5` (cell units) — uses the smaller offset (5)

### Requirement: Terrain-following bounds mesh
Both outer and visible bounds meshes SHALL sample terrain height at cell centers along each diamond edge using `get_height_at_world_smooth()`, producing multi-vertex meshes that follow terrain contours.

#### Scenario: Mesh vertices follow terrain height
- **WHEN** terrain has a hill at a cell center along a diamond edge with height `2.0`
- **THEN** the bounds mesh vertex at that cell center has Y coordinate `2.0 + 0.02`

#### Scenario: Flat terrain produces flat mesh
- **WHEN** all terrain heights are `0.0`
- **THEN** all bounds mesh vertices have Y coordinate `0.02`

### Requirement: Edge sampling via CELL_SIZE intervals
BoundsSystem SHALL walk each diamond edge at `CELL_SIZE` intervals, sampling `get_height_at_world_smooth()` at each step to produce vertex positions with terrain-sampled Y values. Sampling is inline in `create_bounds_edges()`. Outer and visible bounds share identical loop body — intentional duplication.

### Requirement: Bounds mesh uses PRIMITIVE_LINE_STRIP
Bounds meshes SHALL use `ImmediateMesh` with `PRIMITIVE_LINE_STRIP` to draw connected line segments through all sampled vertices.

### Requirement: Bounds render in x-ray mode
Bounds mesh materials SHALL set `no_depth_test = true` so bounds lines render through terrain and other objects. Materials SHALL also use `SHADING_MODE_UNSHADED` and `render_priority >= 2`.

#### Scenario: Bounds visible through terrain
- **WHEN** a hill terrain vertex is at the same world position as a bounds line vertex
- **THEN** the bounds line is still visible (renders through the terrain)

### Requirement: Bounds hidden by default in gameplay
Bounds mesh instances SHALL start with `visible = false` at runtime. The MapEditor SHALL override to `visible = true`. BoundsSystem SHALL expose `show_bounds: bool` flag to control visibility of both mesh instances.

#### Scenario: Bounds invisible in gameplay by default
- **WHEN** the game starts (not MapEditor)
- **THEN** bounds mesh instances are not visible

#### Scenario: Bounds visible in MapEditor
- **WHEN** the MapEditor scene loads
- **THEN** bounds mesh instances are visible

### Requirement: DebugMenu toggle for bounds
DebugMenu SHALL include a "Map Bounds" checkbox in the overlays section that toggles `BoundsSystem.show_bounds`. Toggling the checkbox SHALL show or hide both bounds mesh instances.

#### Scenario: Toggle bounds on
- **WHEN** the user enables the "Map Bounds" checkbox in DebugMenu
- **THEN** `BoundsSystem.show_bounds` becomes true and both bounds meshes become visible

#### Scenario: Toggle bounds off
- **WHEN** the user disables the "Map Bounds" checkbox in DebugMenu
- **THEN** `BoundsSystem.show_bounds` becomes false and both bounds meshes become invisible

### Requirement: Gameplay API — map bounds query
BoundsSystem SHALL provide `is_in_map_bounds(cell: Vector2i) -> bool` that returns true if the cell center is within the outer bounds diamond. Formula (cell units): `absf(float(cell.x) + 0.5) + absf(float(cell.y) + 0.5) <= get_map_half_diag()`. Note: `Vector2i.y` maps to z-axis in world space.

#### Scenario: Cell inside map bounds
- **WHEN** `is_in_map_bounds(Vector2i(0, 0))` is called on a 32×32 grid
- **THEN** it returns true

#### Scenario: Cell outside map bounds
- **WHEN** `is_in_map_bounds(Vector2i(15, 15))` is called on a 32×32 grid
- **THEN** it returns false

### Requirement: Gameplay API — play area query
BoundsSystem SHALL provide `is_in_play_area(cell: Vector2i) -> bool` that returns true if the cell center is within the visible bounds diamond. Formula (cell units): `absf(float(cell.x) + 0.5) + absf(float(cell.y) + 0.5) <= get_play_area_half_diag()`. The diamond uses the smaller of the two offsets. Note: `Vector2i.y` maps to z-axis in world space.

#### Scenario: Cell inside play area
- **WHEN** `is_in_play_area(Vector2i(0, 0))` is called on a 32×32 grid with default offsets
- **THEN** it returns true

#### Scenario: Cell outside play area but inside map bounds
- **WHEN** `is_in_play_area(Vector2i(12, 12))` is called on a 32×32 grid with default offsets
- **THEN** it returns false

### Requirement: Gameplay API — half-diagonal accessors
BoundsSystem SHALL provide `get_map_half_diag() -> float` and `get_play_area_half_diag() -> float` in cell units. `get_play_area_half_diag()` returns the diamond half-diagonal using the smaller offset.

#### Scenario: Map half-diagonal in cell units
- **WHEN** `get_map_half_diag()` is called on a 128×128 grid
- **THEN** it returns `63.0` (cell units)

#### Scenario: Play area half-diagonal in cell units
- **WHEN** `get_play_area_half_diag()` is called on a 32×32 grid with default offsets (x=10, z=8)
- **THEN** it returns `11.0` (cell units, uses smaller offset 8)

### Requirement: Camera clamping follows visible bounds
`clamp_camera_position()` and `get_bounds_rect()` SHALL clamp to visible bounds (not full grid extent). The visible bounds diamond is symmetric: `half = (grid_cells - 2 - min(offset_x, offset_z)) * CELL_SIZE / 2.0`. Camera stays within the play area.

#### Scenario: Camera clamped to visible bounds
- **WHEN** visible bounds half-diagonal is `11.0` (cell units) on a 32×32 grid
- **THEN** camera position is clamped to `[-22.0, 22.0]` (world units: `11.0 * CELL_SIZE`)
