## Context

The map diamond is currently offset into the +XZ quadrant via a hardcoded 1-cell origin shift in CellUtil. Cell (0,0) maps to world (3,3) via `(cell.x + 1.5) * CELL_SIZE`. This offset propagates through every system that converts between cell and world coordinates: bounds checking, camera clamping, height sampling, terrain rendering, entity placement, and pathfinding.

A previous centering change (commit `4b39526`) added optional `grid_cells` parameters to CellUtil functions, but was reverted by the diamond-map-layout change (commit `375a70c`) which chose the +XZ quadrant approach. The +XZ approach was simpler initially but creates ongoing complexity: every new system must remember to apply the offset, and the diamond bounds require translate parameters.

The map outline for a W×H grid is a rectangle rotated 45° inside a
(W+H)×(W+H) cell square. It is a rhombus only when W=H. The center in
cell-coordinate space is `((W+H)/2, (W+H)/2)`.

## Goals / Non-Goals

**Goals:**
- `CellUtil.cell_to_world()` returns coords centered at world origin (0,0,0)
- `CellUtil.world_to_cell()` handles centered coords internally
- All manual offset sites removed (~80 call sites across 9+ files)
- Diamond bounds (red outer, blue visible) use clean centered formulas
- Camera, minimap, and cloud overlay centered at origin
- Works for any W, H including odd-sized maps (50×53)

**Non-Goals:**
- Changing the grid coordinate system (cells are still non-negative array indices)
- Changing the JSON map format (cell coords stored in JSON are unaffected)
- Changing scene files (.tscn)
- Modifying the diamond shape algorithm (still inscribed in (W+H)×(W+H) square)

## Decisions

### 1. Bake centering into CellUtil (not a wrapper)

**Choice**: Modify `cell_to_world()` and `world_to_cell()` directly to apply the `(W+H)/2` centering offset.

**Alternatives considered**:
- New function `cell_to_world_centered()` — rejected: adds API surface, callers must remember which to use
- Keep CellUtil raw, add offset at call sites — this is the status quo we're fixing
- Global state in CellUtil — rejected: CellUtil is stateless static, adding mutable state breaks the pattern

**Rationale**: The centered coord is what every caller needs. The first-quadrant output was an implementation detail that leaked into 80+ call sites. Making CellUtil handle it eliminates the leak.

### 2. grid_cells as optional parameter with TerrainSystem default

**Choice**: `cell_to_world()` and `world_to_cell()` accept an optional `grid_cells: Vector2i` parameter for centering math. Default to `TerrainSystem.grid_cells` when omitted.

**Alternatives considered**:
- Hardcode `TerrainSystem.grid_cells` access inside CellUtil — rejected: couples static utility to autoload, breaks @tool scripts
- Store grid_cells as class variable — rejected: CellUtil is stateless static, adding mutable state is a pattern break
- Always require grid_cells parameter — rejected: too many call sites to change, optional param preserves backward compat

**Rationale**: Optional parameter preserves backward compatibility. Callers that don't pass it get the autoload default. Callers in @tool or test contexts can pass explicitly.

### 3. Diamond math aligned to the half-open raster

**Choice**: All bounds diamonds use the same formula aligned to the half-open raster midpoint at `Vector3(-CS/2, 0, 0)`:

```
long  = (W + H) / 2 * CS
small = (H - W) / 2 * CS
offset_x = -CS / 2
north = (-small + offset_x, -long)
east  = ( long + offset_x,   small)
south = ( small + offset_x,  long)
west  = (-long + offset_x,  -small)
```

Opposite vertices mirror around the raster midpoint. The adjacent edge vectors
reduce to `(H,H)` and `(-W,W)`, so every edge is at 45° and every corner has a
zero dot product (90°).

- Red map bounds: W-0.5, H-0.5
- Blue visible bounds: W-offset_x-0.5, H-offset_z-0.5

**Alternatives considered**:
- Keep MAP_OFFSET translate parameter — rejected: adds complexity to every bounds function
- Compute center in each function — rejected: duplicating the formula

**Rationale**: The half-cell X offset makes the bounds and grid overlays hug
the visually verified owned-cell raster for every map parity and aspect ratio.

### 4. _clamp_to_diamond simplified for centered coords

**Choice**: Remove translate parameter and -1/+1 cell shift from `_clamp_to_diamond`. Centered constraints:

```
a = ux + uz ∈ [-H, H]
b = ux - uz ∈ [-W, W]
```

**Alternatives considered**:
- Keep translate parameter — rejected: unnecessary complexity when centered

**Rationale**: The centered diamond has symmetric constraints around 0. No translate needed.

### 5. Remove get_grid_half_size()

**Choice**: Delete `TerrainSystem.get_grid_half_size()` after all callers are migrated.

**Rationale**: The function exists solely to support the manual offset pattern. Once CellUtil handles centering, no caller needs it.

## Risks / Trade-offs

- **[80+ call sites to migrate]** → Mechanical but easy to miss one. Mitigated by grep-based verification and running full test suite.
- **[Tests will fail during migration]** → Some tests assert first-quadrant coords. Mitigated by updating test assertions as part of the migration.
- **[Pathfinder output changes]** → Path endpoints shift to centered coords. Callers that use path positions (MovementController) work in centered space already, so this is correct.
- **[JSON map format unaffected]** → Maps still store cell coords (non-negative). The centering is purely a runtime world-space concern. No migration needed.
- **[Odd-sized maps]** → Diamond center falls on a cell center (odd W+H) or between cells (even W+H). Both cases handled correctly by float math in cell_to_world.

### 6. Separate continuous geometry from raster ownership

**Choice**: The continuous rectangle is exactly symmetric around world
`(0,0,0)`. Integer cells use half-open sum/difference intervals so an edge cell
is owned once and the map contains exactly `2*W*H` cells.

**Rationale**: A finite integer raster cannot include both opposite boundary
rows without double-counting. The half-open convention is a storage ownership
rule, not a shift of the geometric origin or outline.
