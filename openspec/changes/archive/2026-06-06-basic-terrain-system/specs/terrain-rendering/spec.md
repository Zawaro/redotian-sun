## ADDED Requirements

### Requirement: TerrainRenderer shall use MultiMesh for efficient rendering
The TerrainRenderer SHALL use MultiMeshInstance3D for each mesh variant (clear01-08, slope01-06). Each MultiMesh supports up to 10,000 instances. Cells are placed into the correct MultiMesh based on their mesh name. MultiMeshes SHALL start with `visible_instance_count = 0` and grow dynamically as instances are added.

#### Scenario: MultiMesh per variant
- **WHEN** TerrainRenderer initializes
- **THEN** one MultiMeshInstance3D is created for each mesh variant found in the GLB

#### Scenario: MultiMesh starts empty
- **WHEN** TerrainRenderer initializes
- **THEN** each MultiMesh has `visible_instance_count = 0` (no instances rendered until cells are added)

### Requirement: GLB mesh loading shall be centralized
The TerrainRenderer SHALL load the terrain GLB as a PackedScene once and extract meshes by node name. Meshes are stored in a cache keyed by clean name (e.g., "clear01", "slope01").

#### Scenario: GLB loaded once
- **WHEN** TerrainRenderer initializes
- **THEN** the GLB is loaded, meshes extracted by node name, and cached

### Requirement: Renderer shall use cell_data from signal directly
When the renderer receives a `cell_changed` signal, it SHALL use the `cell_data` dictionary from the signal directly to determine the mesh name, height, and rotation. The renderer SHALL NOT recalculate via `TerrainSystem.calculate_cell_mesh()`.

#### Scenario: Renderer uses signal data
- **WHEN** the renderer receives `cell_changed("5,3", { "height": 1, "type": "slope", "variant": 1, "direction": "north", "rotation": 0.0 })`
- **THEN** it renders the cell using "slope01" mesh at Y = 1 * 0.815 with rotation 0°

#### Scenario: Renderer falls back to recalculate if data incomplete
- **WHEN** the renderer receives `cell_changed` with data missing the "type" field
- **THEN** it falls back to `TerrainSystem.calculate_cell_mesh()` to get complete data

### Requirement: Terrain cells shall be positioned at cell centers
Each terrain cell SHALL be positioned at the center of its grid cell: (cell_x * CELL_SIZE + CELL_SIZE * 0.5, height * HEIGHT_STEP, cell_y * CELL_SIZE + CELL_SIZE * 0.5).

#### Scenario: Cell center positioning
- **WHEN** a cell at grid position (2, 3) with height 1 is rendered
- **THEN** the mesh is positioned at (5.0, 0.815, 7.0)

### Requirement: Terrain cells shall support rotation
Each terrain cell instance SHALL support Y-axis rotation for slope direction. Rotation is specified in degrees and applied via `Basis(Vector3.UP, deg_to_rad(rotation))`.

#### Scenario: Slope rotation
- **WHEN** a slope cell with rotation 180.0 is rendered
- **THEN** the transform basis is set to `Basis(Vector3.UP, deg_to_rad(180.0))`

### Requirement: Materials shall come from GLB
Terrain cell meshes SHALL retain the materials embedded in the GLB. Materials are duplicated during extraction to avoid shared state.

#### Scenario: GLB materials preserved
- **WHEN** a mesh is extracted from the GLB
- **THEN** its surface materials are duplicated and preserved

### Requirement: Renderer shall replace existing instances on cell update
When a cell is rendered and already has an instance in the MultiMesh, the old instance SHALL be removed (swap-with-last) before the new instance is added. The renderer SHALL enforce a maximum of `MAX_INSTANCES_PER_MESH` instances per variant — if the limit is reached, new cells for that variant are silently dropped.

#### Scenario: Cell update replaces instance
- **WHEN** cell (5, 3) is re-rendered with a different mesh variant
- **THEN** the old instance is removed from its MultiMesh and the new instance is added to the correct MultiMesh

#### Scenario: Cell deletion removes instance
- **WHEN** a `cell_changed` signal is received with empty data
- **THEN** the cell's instance is removed from its MultiMesh

#### Scenario: Instance limit enforced
- **WHEN** a MultiMesh has 10,000 active instances and a new cell is added
- **THEN** the new cell is silently dropped (no crash, no render)

### Requirement: Renderer shall track instance positions
The renderer SHALL maintain a dictionary mapping cell keys to their mesh name and instance index within the MultiMesh. This enables O(1) removal via swap-with-last.

#### Scenario: Instance tracking
- **WHEN** cell (5, 3) is rendered as "slope01" at index 42
- **THEN** `_instance_data["5,3"] = { "mesh_name": "slope01", "index": 42 }`

### Requirement: Renderer shall update AABB for frustum culling
The renderer SHALL maintain a custom AABB for each MultiMesh that encompasses all rendered instances. The AABB is updated when instances are added.

#### Scenario: AABB update
- **WHEN** a new instance is added to a MultiMesh
- **THEN** the MultiMesh's `custom_aabb` is merged to include the new instance's position

### Requirement: Renderer shall reset state on clear_all
When `clear_all()` is called, the renderer SHALL reset all instance counts to 0, set `visible_instance_count = 0` on each MultiMesh, and clear all tracking dictionaries. This ensures no stale geometry is rendered.

#### Scenario: clear_all resets visible instances
- **WHEN** `clear_all()` is called after rendering 500 cells
- **THEN** each MultiMesh has `visible_instance_count = 0` and no stale transforms remain

### Requirement: Batch signal emission ensures single render per cell
The deformation system emits `cell_changed` for all affected cells in a single batch after all calculations complete. Each cell emits exactly once with complete data (height, type, variant, direction, rotation).

#### Scenario: Single render per cell
- **WHEN** a deformation affects 20 cells
- **THEN** exactly 20 `cell_changed` signals are emitted, and each cell renders exactly once

#### Scenario: No partial renders during deformation
- **WHEN** the deformation system is executing
- **THEN** no `cell_changed` signals are emitted until all 4 phases (heights, expand, recalculate, render) complete
