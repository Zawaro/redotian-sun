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

### 5. BoxMesh placeholder for all buildings

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
