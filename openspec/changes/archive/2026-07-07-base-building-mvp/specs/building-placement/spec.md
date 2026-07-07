## ADDED Requirements

### Requirement: BuildingType resource defines building metadata
Each building type SHALL be defined as a `BuildingType` Resource with the following fields:
- `id: String` — unique identifier (e.g., "gdi_power_plant")
- `display_name: String` — human-readable name (e.g., "Power Plant")
- `footprint: Vector2i` — size in grid cells (e.g., Vector2i(2, 2))
- `scene: PackedScene` — the building scene to instantiate
- `cameo: Texture2D` — icon for the build menu (placeholder allowed)
- `cost: int` — resource cost (default 0 for MVP)
- `build_time: float` — construction time in seconds (default 0 for MVP)

#### Scenario: BuildingType resource is loadable
- **WHEN** a `.tres` file referencing BuildingType is loaded
- **THEN** all exported fields are accessible and typed correctly

### Requirement: PlacementPreview shows ghost building at cursor
BuildingManager SHALL display a translucent preview when in build mode. The preview SHALL:
- Show per-cell foundation tiles as procedural ImmediateMesh built from vertex grid heights (`get_cell_corner_heights()`)
- Position foundation tiles at each cell's terrain height (vertex heights already include absolute Y from `get_cell_corner_heights()`, mesh instance at Y=0)
- Use green color (75% alpha, unshaded) for valid cells and red (75% alpha) for invalid cells individually
- Snap to grid cells following the mouse cursor
- Show the building scene preview at the highest foundation cell's terrain height
- Preserve the building's original materials with 33% alpha transparency
- Hide the building scene preview at map bounds (not play area bounds)

#### Scenario: Preview follows cursor in build mode
- **WHEN** the player is in build mode and moves the mouse
- **THEN** the preview meshes follow the cursor, snapped to the nearest grid cell origin

#### Scenario: Per-cell foundation coloring
- **WHEN** the preview footprint overlaps a mix of valid and invalid cells
- **THEN** each foundation tile is colored independently: green for free cells, red for occupied cells

#### Scenario: Foundation cells follow terrain height via vertex grid
- **WHEN** the preview is over terrain with varying heights
- **THEN** each foundation tile is built from a procedural ImmediateMesh using `get_cell_corner_heights(cell)` which returns [h_nw, h_ne, h_sw, h_se] with offset applied; the mesh instance is positioned at Y=0 since vertex heights already carry absolute Y values

#### Scenario: Building preview at highest point
- **WHEN** the preview is shown over terrain with varying heights
- **THEN** the building scene preview is positioned at the highest foundation cell's terrain height

#### Scenario: Building preview preserves original materials
- **WHEN** the building scene preview is displayed
- **THEN** all mesh materials retain their original textures and shading, rendered at 33% alpha

### Requirement: Grid wireframe extends beyond foundation
BuildingManager SHALL display a circular wireframe grid extending 3 cells beyond the foundation footprint. The grid SHALL use thick ImmediateMesh quads (0.05 width) at 10% white opacity with CULL_DISABLED for visibility from any angle. Grid lines SHALL follow terrain slopes using vertex grid heights. Grid SHALL be rendered at Y+0.001 offset to avoid z-fighting with foundation cells.

#### Scenario: Grid wireframe visible beyond foundation
- **WHEN** the player is in build mode
- **THEN** a circular wireframe grid is visible extending 3 cells beyond the foundation footprint

#### Scenario: Grid cells beyond foundation are white
- **WHEN** grid cells are outside the foundation footprint and within bounds
- **THEN** grid cells render as white lines at 10% opacity

#### Scenario: Grid cells overlapping occupied/slope cells are red
- **WHEN** a grid cell outside the foundation overlaps an occupied or slope cell
- **THEN** that grid cell renders as red at 10% opacity

#### Scenario: Grid follows terrain slopes
- **WHEN** the grid extends over terrain with varying heights
- **THEN** grid lines follow the terrain surface using vertex grid heights

### Requirement: Diamond-shaped bounds checking via cell centers
BuildingManager SHALL validate placement using diamond-shaped bounds checks. The bounds check SHALL use cell centers (not origins) via the formula: `absf(float(cell.x) + 0.5) + absf(float(cell.y) + 0.5) <= half_diagonal`. Two bounds tiers SHALL apply:
- **Map bounds** (`map_size`): hard outer edge — cells beyond are not rendered in preview
- **Play area bounds** (`visible_bounds_size`): inner margin — cells between play area and map bounds are shown as red/rejected by `can_place()`

#### Scenario: Placement at map edge is rejected
- **WHEN** any cell in the footprint falls outside map bounds
- **THEN** placement is rejected and the building is not instantiated

#### Scenario: Placement in margin zone is rejected
- **WHEN** any cell in the footprint is between play area bounds and map bounds
- **THEN** placement is rejected and the building is not instantiated

#### Scenario: Preview hides at map bounds
- **WHEN** the cursor moves to a cell outside map bounds
- **THEN** the building scene preview is hidden but foundation cells still render (red)

#### Scenario: Preview visible at play area bounds
- **WHEN** the cursor moves to a cell at the play area boundary
- **THEN** the building scene preview remains visible (cell is rejected but not hidden)

#### Scenario: Grid cells outside map bounds are not rendered
- **WHEN** the grid wireframe extends beyond map bounds
- **THEN** only cells within map bounds are rendered; cells beyond are skipped

#### Scenario: Margin zone cells all red in grid
- **WHEN** grid cells are between play area bounds and map bounds
- **THEN** those cells render as red in the grid wireframe

### Requirement: Placement validation checks all constraints
BuildingManager SHALL validate placement by checking all cells in the footprint against:
1. Within diamond-shaped map bounds (cell center check)
2. Within diamond-shaped play area bounds (cell center check)
3. Not already occupied by a building
4. Not occupied by an idle unit
5. Terrain type is "clear" (not cliff or slope)
6. Height variation across footprint ≤ 1 step

#### Scenario: Valid placement on empty flat terrain
- **WHEN** the player clicks to place a building on empty, flat, clear terrain within bounds
- **THEN** the building is instantiated at the grid-snapped position and registered in SpatialHash

#### Scenario: Placement rejected for out-of-bounds
- **WHEN** any cell in the footprint falls outside diamond-shaped map bounds
- **THEN** placement is rejected and the building is not instantiated

#### Scenario: Placement rejected for building overlap
- **WHEN** any cell in the footprint overlaps an existing building's cells
- **THEN** placement is rejected and the building is not instantiated

#### Scenario: Placement rejected for unit overlap
- **WHEN** any cell in the footprint is occupied by an idle unit
- **THEN** placement is rejected and the building is not instantiated

#### Scenario: Placement rejected for uneven terrain
- **WHEN** the height difference across the footprint exceeds 1 step
- **THEN** placement is rejected and the building is not instantiated

### Requirement: Invalid placement keeps build mode active
When the player attempts to place a building at an invalid location, BuildingManager SHALL remain in build mode. The `place_building()` method SHALL return a boolean indicating success. Only successful placement SHALL exit build mode.

#### Scenario: Invalid placement stays in build mode
- **WHEN** the player clicks to place a building at an invalid location
- **THEN** build mode remains active and the preview continues following the cursor

#### Scenario: Valid placement exits build mode
- **WHEN** the player clicks to place a building at a valid location
- **THEN** build mode exits and the preview disappears

### Requirement: Building is instantiated at correct position
When placement is valid, BuildingManager SHALL:
1. Instantiate the building scene from BuildingType
2. Position it at the center of the footprint in world space (offset by half footprint × CELL_SIZE)
3. Set Y position to max terrain height across footprint × HEIGHT_STEP
4. Add it as a child of the Buildings parent node

#### Scenario: Building positioned at footprint center
- **WHEN** a 3×3 building is placed at origin cell (5, 5)
- **THEN** the building's world position is at the center of the 3×3 footprint (origin offset by half footprint)

#### Scenario: Building height matches terrain
- **WHEN** a building is placed on terrain with max height 2
- **THEN** the building's Y position equals 2 × HEIGHT_STEP

### Requirement: Placed buildings are selectable
Placed buildings SHALL have SelectComponent with `select_box_type = Structure`, making them clickable via the existing mouse raycast system (collision layer 15).

#### Scenario: Click on placed building selects it
- **WHEN** the player left-clicks on a placed building
- **THEN** the building is selected and its selection box is displayed
