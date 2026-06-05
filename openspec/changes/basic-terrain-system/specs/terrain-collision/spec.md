## ADDED Requirements

### Scope Note
TerrainCollision (per-cell trimesh) is used **only in the MapEditor** for terrain editing workflows. Gameplay scenes (TestMap02, MapBase01, future maps) use mathematical terrain intersection via `TerrainSystem.get_height_at_world_smooth()` for click detection and movement — no collision shapes needed.

**Future**: For weapon projectile collision (rockets, artillery), a `HeightMapShape3D` covering the entire terrain will replace per-cell trimesh. This provides efficient physics collision for projectile impact detection while keeping a single collision shape.

### Requirement: TerrainCollision shall manage collision bodies per cell
The TerrainCollision system SHALL create and manage StaticBody3D nodes with CollisionShape3D for each terrain cell. Collision bodies are organized under a "TerrainCollision" parent node.

#### Scenario: Collision creation on cell set
- **WHEN** a `cell_changed` signal is received with non-empty data
- **THEN** a StaticBody3D with CollisionShape3D is created at the cell's world position

#### Scenario: Collision removal on cell deletion
- **WHEN** a `cell_changed` signal is received with empty data
- **THEN** the cell's StaticBody3D is removed and freed

### Requirement: Collision shall use cell_data from signal directly
When the collision system receives a `cell_changed` signal, it SHALL use the `cell_data` dictionary from the signal directly to determine the mesh variant and create the collision shape. It SHALL NOT recalculate via `TerrainSystem.calculate_cell_mesh()`.

#### Scenario: Collision uses signal data
- **WHEN** the collision system receives `cell_changed("5,3", { "height": 1, "type": "slope", "variant": 1 })`
- **THEN** it creates a collision shape from the "slope01" mesh

#### Scenario: Collision falls back to recalculate if data incomplete
- **WHEN** the collision system receives `cell_changed` with data missing the "type" field
- **THEN** it falls back to `TerrainSystem.calculate_cell_mesh()` to get complete data

### Requirement: Collision shapes shall use mesh faces
The CollisionShape3D SHALL use a ConcavePolygonShape3D created via `Mesh.create_trimesh_shape()` from the terrain mesh, ensuring collision perfectly matches visual geometry.

#### Scenario: ConcavePolygonShape3D from mesh
- **WHEN** a collision body is created for a slope cell
- **THEN** its CollisionShape3D.shape is set to the slope mesh's create_trimesh_shape()

#### Scenario: Collision matches visual
- **WHEN** a slope cell is rendered
- **THEN** its collision shape exactly matches the slope mesh geometry

### Requirement: Collision bodies shall be on layer 1
All terrain StaticBody3D nodes SHALL have collision_layer = 1 and collision_mask = 0 (receives collisions, does not cast).

#### Scenario: Collision layer setup
- **WHEN** a TerrainCollision's StaticBody3D is created
- **THEN** collision_layer = 1 and collision_mask = 0

### Requirement: Collision shall be positioned with the cell
The StaticBody3D SHALL be positioned at the cell's world position: (cell_x * CELL_SIZE + CELL_SIZE * 0.5, height * HEIGHT_STEP, cell_y * CELL_SIZE + CELL_SIZE * 0.5). Rotation SHALL be applied for slope direction.

#### Scenario: Collision positioned at cell center
- **WHEN** a cell at grid position (2, 3) with height 1 is rendered
- **THEN** its StaticBody3D is at position (5.0, 0.815, 7.0)

#### Scenario: Collision rotation matches visual
- **WHEN** a slope cell with rotation 180.0 is rendered
- **THEN** its StaticBody3D has rotation.y = deg_to_rad(180.0)

### Requirement: Batch signal emission ensures single collision update per cell
The deformation system emits `cell_changed` for all affected cells in a single batch. Each cell's collision is updated exactly once with complete data.

#### Scenario: Single collision update per cell
- **WHEN** a deformation affects 20 cells
- **THEN** exactly 20 collision updates occur, each with correct mesh data
