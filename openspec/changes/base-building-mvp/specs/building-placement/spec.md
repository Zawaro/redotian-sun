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
BuildingManager SHALL display a translucent BoxMesh preview when in build mode. The preview SHALL:
- Show per-cell foundation tiles at each grid cell's terrain height + 0.01m
- Use green color (50% alpha, unshaded) for valid cells and red for invalid cells individually
- Snap to grid cells following the mouse cursor
- Show the building scene preview at the highest foundation cell's terrain height
- Preserve the building's original materials with 33% alpha transparency

#### Scenario: Preview follows cursor in build mode
- **WHEN** the player is in build mode and moves the mouse
- **THEN** the preview meshes follow the cursor, snapped to the nearest grid cell origin

#### Scenario: Per-cell foundation coloring
- **WHEN** the preview footprint overlaps a mix of valid and invalid cells
- **THEN** each foundation tile is colored independently: green for free cells, red for occupied cells

#### Scenario: Foundation cells follow terrain height
- **WHEN** the preview is over terrain with varying heights
- **THEN** each foundation tile is positioned at the cell's max vertex height + 0.01m (read directly from vertex grid, no interpolation)

#### Scenario: Building preview at highest point
- **WHEN** the preview is shown over terrain with varying heights
- **THEN** the building scene preview is positioned at the highest foundation cell's terrain height

#### Scenario: Building preview preserves original materials
- **WHEN** the building scene preview is displayed
- **THEN** all mesh materials retain their original textures and shading, rendered at 33% alpha

### Requirement: Placement validation checks all constraints
BuildingManager SHALL validate placement by checking all cells in the footprint against:
1. Within grid bounds (0 to grid_cells - 1)
2. Not already occupied by a building
3. Not occupied by an idle unit
4. Terrain type is "clear" (not cliff or slope)
5. Height variation across footprint ≤ 1 step

#### Scenario: Valid placement on empty flat terrain
- **WHEN** the player clicks to place a building on empty, flat, clear terrain within bounds
- **THEN** the building is instantiated at the grid-snapped position and registered in SpatialHash

#### Scenario: Placement rejected for out-of-bounds
- **WHEN** any cell in the footprint falls outside grid bounds
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

### Requirement: Building is instantiated at correct position
When placement is valid, BuildingManager SHALL:
1. Instantiate the building scene from BuildingType
2. Position it at the center of the footprint in world space
3. Set Y position to max terrain height across footprint × HEIGHT_STEP
4. Add it as a child of the Buildings parent node

#### Scenario: Building positioned at footprint center
- **WHEN** a 3×3 building is placed at origin cell (5, 5)
- **THEN** the building's world position is at the center of the 3×3 footprint

#### Scenario: Building height matches terrain
- **WHEN** a building is placed on terrain with max height 2
- **THEN** the building's Y position equals 2 × HEIGHT_STEP

### Requirement: Placed buildings are selectable
Placed buildings SHALL have SelectComponent with `select_box_type = Structure`, making them clickable via the existing mouse raycast system (collision layer 15).

#### Scenario: Click on placed building selects it
- **WHEN** the player left-clicks on a placed building
- **THEN** the building is selected and its selection box is displayed
