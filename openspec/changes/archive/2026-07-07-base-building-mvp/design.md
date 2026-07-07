## Context

The project has a working grid system (2m × 2m cells), pathfinding (A* with diagonal movement), spatial hashing for unit tracking, and terrain collision. Structures exist (GDIConyard01) but aren't tracked by the pathfinding system — they're excluded from the "entities" group and invisible to SpatialHash.

Current architecture:
- `SpatialHash` rebuilds `_blocked_cells` every physics frame from entities in "entities" group
- `MovementController._build_blocked_cells()` merges blocked + reserved cells for pathfinding
- `Pathfinder.find_path()` takes `blocked_cells: Dictionary` and avoids those cells
- `MouseHandler` raycasts at collision layer 15 for entity selection and ground movement

Buildings are semantically separate from units: they don't move, don't have MovementControllers, and occupy multiple cells permanently.

## Goals / Non-Goals

**Goals:**
- Players can select a building from a UI menu and place it on the terrain
- Ghost preview follows cursor, snaps to grid, shows valid/invalid placement
- Foundation preview uses procedural ImmediateMesh that follows terrain slopes
- Grid wireframe extends 3 cells beyond foundation for spatial awareness
- Diamond-shaped bounds checking with play area margin
- Placed buildings permanently block their cells for pathfinding
- Zero changes to Pathfinder or MovementController
- All 6 GDI buildings available with placeholder cube meshes

**Non-Goals:**
- Build queue or construction timers
- Power grid system
- Resource costs or economy
- Tech tree prerequisites
- Adjacency requirements
- Building sell/demolish
- Faction-specific buildings (Nod)
- Real building models (placeholder cubes only)

## Decisions

### 1. SpatialHash._building_cells layer (not separate BuildingRegistry)

**Choice**: Add `_building_cells: Dictionary` to SpatialHash, merged into `get_blocked_cells()`.

**Alternatives considered**:
- Separate BuildingRegistry queried by MovementController — rejected: requires modifying MovementController to merge two sources, breaks the "single source of truth" pattern
- Buildings in `_blocked_cells` directly — rejected: `rebuild()` clears `_blocked_cells` every frame, buildings would vanish

**Rationale**: SpatialHash already owns "which cells are blocked." Buildings are just another type of occupancy. The merge in `get_blocked_cells()` means MovementController and Pathfinder need zero changes. The `_building_cells` layer persists across `rebuild()` calls because it's never cleared by the dynamic entity rebuild.

### 2. BuildingManager as autoload singleton

**Choice**: Register in `project.godot` alongside existing autoloads (SelectionManager, DebugVisualizer, SpatialHashSingleton, TerrainSystem).

**Alternatives considered**:
- Regular node in Gameplay scene — rejected: needs global access from MouseHandler and BuildMenu which are in different scene branches
- Static instance pattern (like SpatialHash) — rejected: redundant when project already uses 4 autoloads

**Rationale**: Consistent with existing architecture. Guaranteed availability before scene loads. No wiring needed.

### 3. BuildingType as custom Resource

**Choice**: `class_name BuildingType extends Resource` with `@export` fields, instantiated as `.tres` files.

**Alternatives considered**:
- JSON/YAML data files — rejected: not native to Redot, requires parsing, can't reference PackedScene/Texture2D directly
- Dictionary constants in BuildingManager — rejected: scattered data, hard to extend, no editor support

**Rationale**: Native Godot resources. Can reference scenes and textures directly. Editable in the inspector. Type-safe with autocomplete.

### 4. PlacementPreview as child of BuildingManager (not MouseHandler)

**Choice**: BuildingManager owns PlacementPreview as a child node. Preview position updated in `BuildingManager._process()`.

**Alternatives considered**:
- Preview as sibling in scene tree — rejected: adds wiring complexity, preview is logically part of build mode
- Preview managed by MouseHandler — rejected: MouseHandler shouldn't know about building visuals

**Rationale**: Cohesion — build mode state, validation, and preview are all BuildingManager's responsibility. Single node manages the full lifecycle.

### 5. Procedural ImmediateMesh foundation (not BoxMesh or PlaneMesh)

**Choice**: Foundation tiles built from procedural ImmediateMesh using `get_cell_corner_heights()` vertex grid data. Mesh instance at Y=0, vertices carry absolute heights. Building preview at 33% alpha with original materials.

**Alternatives considered**:
- PlaneMesh per cell — rejected: flat, doesn't follow terrain slopes; would show gaps on uneven terrain
- GLB mesh lookup from TerrainRenderer — rejected: couples BuildingManager to internal TerrainRenderer implementation, vertex data format may change
- Single BoxMesh for entire foundation — rejected: doesn't show per-cell terrain variation

**Rationale**: Procedural ImmediateMesh is self-contained, follows terrain slopes naturally, and uses the vertex grid as source of truth. `get_cell_corner_heights()` already provides [h_nw, h_ne, h_sw, h_se] with offset applied, so heights are absolute Y values. No coupling to TerrainRenderer internals.

### 6. Diamond-shaped bounds via cell centers

**Choice**: Bounds check uses cell centers (not origins) via `absf(float(cell.x) + 0.5) + absf(float(cell.y) + 0.5) <= half_diagonal`. Two tiers: map_size (hard outer edge) and visible_bounds_size (play area margin).

**Alternatives considered**:
- Origin-based bounds (`absf(float(cell.x)) + absf(float(cell.y))`) — rejected: causes visual offset at map edges, cells at the boundary appear partially outside bounds
- Axis-aligned rectangular bounds — rejected: map is diamond-shaped (45° rotation), rectangular bounds would allow building outside the visible play area
- Single bounds tier — rejected: no distinction between "can't build here" (margin) and "outside map entirely" (hard edge)

**Rationale**: Center-based check matches the visual representation — cell centers are where buildings actually sit. The 0.5 offset accounts for the `cell_to_world` offset (`(cell + Vector2i(grid_cells >> 1)) * CELL_SIZE`). Diamond shape matches the 45° rotated map bounds from BoundsSystem. Two tiers give clear visual feedback: red margin zone vs hidden outside-map.

### 7. Grid wireframe as ImmediateMesh quads

**Choice**: Circular wireframe grid extending 3 cells beyond foundation, using thick ImmediateMesh quads (0.05 width) with CULL_DISABLED at 10% white opacity. Occupied/slope cells in grid area show red.

**Alternatives considered**:
- PRIMITIVE_LINES — rejected: no visible thickness, lines are 1px regardless of zoom
- Texture-based grid overlay — rejected: requires texture creation, resolution-dependent, doesn't follow terrain
- No grid beyond foundation — rejected: player can't see spatial context for placement decisions

**Rationale**: ImmediateMesh quads give visible thickness (0.05 width) and CULL_DISABLED ensures visibility from any camera angle. Grid follows terrain slopes via vertex grid heights. Y+0.001 offset prevents z-fighting with foundation cells. 10% opacity keeps grid subtle.

### 8. Invalid placement keeps build mode active

**Choice**: `place_building() -> bool` returns success/failure. Only successful placement exits build mode. Invalid placement keeps preview active.

**Alternatives considered**:
- Cancel build mode on any click — rejected: frustrating for player, must re-select building from menu
- Cancel build mode on invalid placement — rejected: same UX issue, player loses context
- Show error message on invalid placement — rejected: MVP scope, visual feedback (red cells) is sufficient

**Rationale**: Standard RTS UX — player stays in build mode until they successfully place or explicitly cancel. Red cells provide immediate feedback on why placement failed.

### 9. BoxMesh placeholder for all buildings

**Choice**: Single `BoxMesh` sized to `footprint × CELL_SIZE`, semi-transparent `StandardMaterial3D`.

**Alternatives considered**:
- Per-building GLB placeholders — rejected: overkill for MVP, user will replace with real models
- Wireframe outline — rejected: harder to see, less intuitive for placement feedback

**Rationale**: Simplest visual that communicates footprint clearly. Green/red color feedback is immediate and unambiguous.

## Risks / Trade-offs

- **Performance**: `get_blocked_cells()` now duplicates a larger dictionary (dynamic + building cells). Mitigation: buildings are few (<50), dictionary is small, and this is already the pattern. Can optimize with cached merge if needed.

- **Terrain height mismatch**: Buildings placed on uneven terrain may float or clip. Mitigation: placement validation checks `max_height - min_height ≤ 1` across footprint. Building Y position uses max height.

- **Building scenes are cubes**: Placeholder meshes won't look like real buildings. Mitigation: explicit MVP scope, user will provide real models later.

- **No sell/demolish**: Once placed, buildings can't be removed in MVP. Mitigation: clear scope, future phase.

- **Procedural mesh per frame**: Foundation tiles rebuild ImmediateMesh each frame the preview is visible. Mitigation: footprint is small (max 4×3 = 12 cells), ImmediateMesh construction is O(cells), negligible at 60fps.

- **Diamond bounds may confuse players**: Rectangular footprints near diamond edges may have some cells inside and some outside. Mitigation: red cells on the invalid cells provide clear feedback; player learns to avoid edges.

- **Grid wireframe density**: 3-cell extension adds significant grid area for large footprints. Mitigation: circular clipping via bounds check, 10% opacity keeps it subtle.
