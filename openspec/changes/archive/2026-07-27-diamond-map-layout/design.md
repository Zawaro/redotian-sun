## Context

The map system currently uses a centered coordinate grid where `CellUtil.cell_to_world` subtracts `grid_half` from cell positions, placing cell `(0,0)` at negative world coordinates. The `BoundsSystem` draws an axis-aligned rectangle for bounds visualization, and containment checks use `abs(cx)/hx + abs(cz)/hz <= 1.0`.

Tiberian Sun maps are diamond-shaped — rotated rectangles at ±45° to the world axes. The camera views the map from a 45° angle, so the diamond appears as a rectangle on screen. All cells should live in the +XZ quadrant (positive x, positive z).

## Goals / Non-Goals

**Goals:**
- Shift all cells to +XZ quadrant (cell `(0,0)` at world `(2, 0, 2)`)
- Define diamond boundary as a parallelogram with edges at ±45°
- Draw bounds mesh from 4 computed corner positions
- Clip EditorGrid lines to diamond boundary
- Provide `CellUtil.is_in_diamond()` for containment checks

**Non-Goals:**
- Changing cell indexing or orientation (cells remain axis-aligned)
- Changing TerrainSystem cell storage or vertex grid allocation
- Changing JSON save format
- Modifying gameplay systems that work in cell coordinates (SpatialHash, MovementController, BuildingManager)

## Decisions

### 1. Cell offset: +1 cell from origin

**Choice**: `cell_to_world(cell) = Vector3((cell.x + 1) * CELL_SIZE, 0.0, (cell.y + 1) * CELL_SIZE)`

Cell `(0,0)` → world `(2, 0, 2)`. Cell `(W-1, H-1)` → world `(W*2, 0, H*2)`.

**Alternatives considered**:
- Offset by `grid_half` (keep centering, just flip sign): Rejected — doesn't produce the diamond layout the user described
- No offset (cell at world origin): Rejected — cell center at `(1, 0, 1)` is cleaner, avoids edge-at-origin issues

**Rationale**: The +1 offset places the first cell center at `(CELL_SIZE, 0, CELL_SIZE)`, giving a 1-cell margin from the axes. This matches the user's specification that cell origin is at `(1,1)` in cell units.

### 2. Diamond containment: Parallelogram formula

**Choice**: For a W×H map, point `(x, z)` is inside the diamond when:
```
(x + z) / ((W + H) * CELL_SIZE) <= 0.5
AND (when W != H)
|x - z| / ((W - H) * CELL_SIZE) <= 0.5
```

When `W == H`, only the first condition applies (skip second to avoid division by zero).

**Alternatives considered**:
- `abs(cx)/hx + abs(cz)/hz <= 1.0` (current rectangular diamond): Rejected — produces wrong shape for rectangular maps
- Pre-computed bitmask: Rejected — overkill for this scale

**Rationale**: The parallelogram formula correctly handles asymmetric diamonds (W ≠ H) and reduces to the square case when W = H. Derived from the perpendicular distances between parallel edge pairs at ±45°.

### 3. Bounds mesh: corner computation with odd/even parity

**Choice**: The diamond vertex count depends on whether `W + H` is odd or even.

**Odd W+H** (e.g., 32×23, sum=55): Edges connect directly at corners. 4 vertices:
- `(0, W*2)`, `(W*2, 0)`, `((W+H)*2, H*2)`, `(H*2, (W+H)*2)`

**Even W+H** (e.g., 32×24, sum=56): Each edge has a `CELL_SIZE` (2-unit) offset before the next starts. 8 vertices:
- Width edge 1: `(0, W*2) → (W*2, 0)`
- Connector: `(W*2, 0) → (W*2 + offset, 0)` (horizontal)
- Height edge 1: `(W*2 + offset, 0) → ((W+H)*2, H*2)`
- Connector: `((W+H)*2, H*2) → ((W+H)*2, H*2 + offset)` (vertical)
- Width edge 2: `((W+H)*2, H*2 + offset) → (H*2 + offset, (W+H)*2)`
- Connector: `(H*2 + offset, (W+H)*2) → (H*2, (W+H)*2)` (horizontal)
- Height edge 2: `(H*2, (W+H)*2) → (0, W*2 + offset)`
- Connector: `(0, W*2 + offset) → (0, W*2)` (vertical)

Where `offset = (W + H) % 2 * CELL_SIZE` (0 for odd, 2 for even).

**Alternatives considered**:
- Always use 8 vertices: Rejected — odd case has no gaps, adding phantom vertices is wrong
- Always use 4 vertices: Rejected — even case needs connectors to close the shape

**Rationale**: The parity-dependent vertex count correctly represents the diamond geometry. The containment formula is the same for both cases (edge lines don't change), only the mesh drawing differs.

### 4. Diamond corner coordinates (odd/even parity)

**Choice**: For a W×H map, the diamond vertices depend on `(W + H) % 2`:

**Odd sum** (4 vertices, edges meet at corners):
- `(0, W*2)`, `(W*2, 0)`, `((W+H)*2, H*2)`, `(H*2, (W+H)*2)`

**Even sum** (8 vertices, 2-unit connectors at corners):
- `(0, W*2)`, `(W*2, 0)`, `(W*2+2, 0)`, `((W+H)*2, H*2)`, `((W+H)*2, H*2+2)`, `(H*2+2, (W+H)*2)`, `(H*2, (W+H)*2)`, `(0, W*2+2)`

Width edges run at -45° (slope -1), height edges at +45° (slope +1). The2-unit offset for even sums comes from the parallelogram geometry — the last point of one edge is shared with the first point of the next when the sum is odd, but offset by `CELL_SIZE` when even.

**Rationale**: Derived from the intersection of parallel edge pairs. Verified against user's example coordinates for 32×24 map (even) and 32×23 map (odd).

### 5. Grid clipping to diamond

**Choice**: EditorGrid draws vertical and horizontal lines clipped to the diamond boundary. For each grid line at position `p`, compute the intersection with the diamond edges to get the visible segment.

**Rationale**: Drawing full grid lines and clipping to diamond is simpler than computing which cells exist and drawing cell-by-cell.

## Risks / Trade-offs

- **[Breaking world coordinates]** → 43+ callers of `cell_to_world` and 48+ of `world_to_cell` produce different results. Mitigated by: most gameplay logic uses cell coordinates, not world coordinates. Visual systems (meshes, particles) need position updates.
- **[Tests break]** → Expected world coordinates in tests change. Mitigated by: straightforward update of expected values.
- **[TerrainSystem center-offset]** → `get_cell_type`, `get_cell_max_height`, `get_cell_corner_heights` use `grid_cells.x >> 1` for center offset. Must update to use new layout. Mitigated by: these functions are well-contained.
- **[Camera clamping]** → Must clamp to diamond AABB `[0, (W+H)*2]` instead of centered rectangle. Simple change.
