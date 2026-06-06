## ADDED Requirements

### Requirement: MapEditor shall provide isometric camera view
The MapEditor scene SHALL use the existing CameraController with isometric projection for terrain editing.

#### Scenario: Isometric camera setup
- **WHEN** MapEditor.tscn is loaded
- **THEN** the camera uses orthographic projection with 45-degree Y rotation and ~30-degree pitch

#### Scenario: Camera panning
- **WHEN** user presses WASD or moves mouse to edge
- **THEN** camera pans across the terrain grid

### Requirement: MapEditor shall display grid overlay at vertex positions
A grid overlay SHALL visualize the terrain grid using ImmediateMesh with PRIMITIVE_LINES. Grid lines SHALL be drawn at vertex positions (integer grid coordinates), forming a rectangular grid as seen from the isometric camera. Lines are clipped to a diamond-shaped boundary.

#### Scenario: Grid lines at vertex positions
- **WHEN** MapEditor is active
- **THEN** grid lines are drawn along integer vertex X and Z positions

#### Scenario: Grid lines clipped to diamond boundary
- **WHEN** grid lines are drawn
- **THEN** each line is clipped to the diamond boundary

#### Scenario: Hovered cell highlighted
- **WHEN** mouse hovers over a cell
- **THEN** the cell is highlighted with a distinct color, positioned at the cell's current height

### Requirement: MapEditor shall support height painting via drag
Users SHALL be able to left-click on a cell and drag up/down to increase/decrease height. The drag SHALL stay on the active cell (the cell that was clicked), not follow the cursor. Each threshold crossing SHALL call TerrainSystem.raise_cell() or TerrainSystem.lower_cell().

#### Scenario: Raise cell height
- **WHEN** user left-clicks on cell (5, 3) and drags upward
- **THEN** `TerrainSystem.raise_cell(Vector2i(5, 3))` is called for each drag threshold crossed

#### Scenario: Lower cell height
- **WHEN** user left-clicks on cell (5, 3) and drags downward
- **THEN** `TerrainSystem.lower_cell(Vector2i(5, 3))` is called for each drag threshold crossed

#### Scenario: Drag stays on active cell
- **WHEN** user left-clicks on cell (5, 3) and drags upward while cursor moves to cell (5, 4)
- **THEN** cell (5, 3)'s height changes, NOT cell (5, 4)

#### Scenario: Height bounds enforced by cascade
- **WHEN** user drags to set height below 0 or above maximum
- **THEN** the raise/lower method clamps all 4 vertices to valid range (0 to MAX_HEIGHT) before cascading

### Requirement: MapEditor shall cascade terrain dynamically via vertex system
When a cell's height changes via raise/lower, the terrain system SHALL automatically cascade height changes through the vertex grid (4-directional, ±1 constraint). All affected cells SHALL recompute their types from the updated vertex heights in a single batch.

#### Scenario: Raising cell creates slopes
- **WHEN** cell (5, 5) is raised from base height 0 to 1
- **WHEN** all 4 vertices of (5,5) go from 0 to 1
- **THEN** neighboring vertices are cascaded if diff > 1, then affected cells recompute types

#### Scenario: Lowering cell flattens slopes
- **WHEN** cell (5, 5) is lowered from base height 1 to 0
- **THEN** its 4 vertices decrement, cascade propagates, cells recompute

#### Scenario: Cascade spreads outward through vertices
- **WHEN** raising cell (5, 5) forces neighbor vertex to differ by >1
- **THEN** the neighbor vertex is adjusted by 1 and recursively checked

#### Scenario: All cells with changed vertices are recomputed
- **WHEN** cascade adjusts vertices
- **THEN** every cell sharing an adjusted vertex is recomputed (cell type derived from 4 vertices)

#### Scenario: No premature rendering during deformation
- **WHEN** a cascade is executing
- **THEN** no `cell_changed` signals are emitted until all vertices are stable and all cell types recomputed

### Requirement: MapEditor shall auto-select slope variant from vertices
The editor SHALL NOT calculate cell types from neighbors. Instead, every cell's type, variant, direction, and rotation SHALL be computed purely from its 4 corner vertex heights.

#### Scenario: Cell type from vertex pattern
- **WHEN** a cell's 4 vertices have heights [2, 2, 2, 2]
- **THEN** the cell is clear01 (flat)

#### Scenario: Cell variant from vertex pattern
- **WHEN** a cell's 4 vertices have heights [3, 3, 2, 2]
- **THEN** the cell is slope01 (single ramp), direction "north"

#### Scenario: No neighbor comparison
- **WHEN** a cell's variant is computed
- **THEN** only its own 4 vertex heights are checked, not neighboring cell data

### Requirement: MapEditor shall provide SubViewport minimap
A SubViewport SHALL render a top-down view of the terrain with color-coded terrain types. The minimap SHALL read cell data from the cell cache (which is computed from vertices).

#### Scenario: Minimap display
- **WHEN** MapEditor is active
- **THEN** a minimap in the corner shows terrain overview updated from cell cache

#### Scenario: Minimap updates on cascade
- **WHEN** `cell_changed` signal fires after cascade
- **THEN** minimap redraws affected regions

### Requirement: MapEditor shall support JSON save/load
The editor SHALL provide UI buttons to save terrain to JSON and load terrain from JSON. The JSON format SHALL store both vertex grid (non-zero heights only) and pre-computed cell cache.

#### Scenario: Save button
- **WHEN** user clicks "Save" button
- **THEN** a file dialog opens to select save location, terrain is exported to JSON (v2 format with vertex grid)

#### Scenario: Load button
- **WHEN** user clicks "Load" button
- **THEN** a file dialog opens to select JSON file, terrain is imported (vertex grid populated, cell cache recomputed from vertices)

#### Scenario: Load triggers batch render
- **WHEN** terrain is imported from JSON
- **THEN** `cell_changed` is emitted for every cell in the grid

### Requirement: MapEditor shall have minimal UI
The editor UI SHALL contain only essential controls: Save, Load, and height display.

#### Scenario: UI layout
- **WHEN** MapEditor is active
- **THEN** a VBoxContainer with Save/Load buttons and current height label is visible

### Requirement: MapEditor shall pre-fill grid with flat clear cells
The MapEditor SHALL populate all cells within a diamond boundary on scene load. Pre-fill SHALL set all vertices within the boundary to height 0, then cascade and batch-render.

#### Scenario: Grid pre-fill on open
- **WHEN** MapEditor.tscn is loaded
- **THEN** all vertices within the diamond boundary are set to height 0 and cells are computed as clear01

### Requirement: MapEditor shall clear terrain on scene exit
The MapEditor SHALL clear all terrain data when the scene is exited, resetting the vertex grid and cell cache.

#### Scenario: Scene exit cleanup
- **WHEN** the MapEditor scene is exited
- **THEN** all vertex heights are reset to 0 and cell cache is cleared