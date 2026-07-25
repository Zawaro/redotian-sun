## Context

`CellUtil` is the low-level coordinate conversion layer for the entire grid system. Currently, `cell_to_world()` returns first-quadrant coords (cell (0,0) → world (1,1)), and every caller manually subtracts `grid_half` to center the grid at world origin. This pattern is repeated 36 times across 9 files.

The centering offset exists because the 45° camera rotation makes (0,0,0) the natural origin — symmetric camera clamping, symmetric raycasting, and clean diamond bounds all depend on centered coords.

## Goals / Non-Goals

**Goals:**
- `CellUtil.cell_to_world()` returns coords centered at (0,0,0)
- `CellUtil.world_to_cell()` handles centered coords internally
- All 36 manual `±grid_half` offset sites removed
- Existing tests pass with updated assertions
- No changes to function signatures

**Non-Goals:**
- Changing the grid coordinate system (cells are still non-negative array indices)
- Changing cell_to_world for callers that intentionally work in cell-space (SpatialHash, ResourceGrowthSystem, entity components)
- Updating the JSON map format (separate concern)
- Touching scene files

## Decisions

### 1. Bake offset into CellUtil (not a wrapper function)

**Choice**: Modify `cell_to_world()` directly to subtract `grid_half` internally.

**Alternatives considered**:
- New function `cell_to_world_centered()` — rejected: adds API surface, callers must remember which to use
- Wrapper class with state — rejected: CellUtil is static, adding state breaks the pattern
- Keep CellUtil raw, add offset at call sites — this is the status quo we're fixing

**Rationale**: The centered coord is what every caller needs. The first-quadrant output was an implementation detail that leaked into 36 call sites. Making CellUtil handle it eliminates the leak.

### 2. grid_cells as parameter (not global state)

**Choice**: `cell_to_world()` and `world_to_cell()` accept an optional `grid_cells: int` parameter for centering math. Default to `TerrainSystem.grid_cells` when omitted.

**Alternatives considered**:
- Hardcode `TerrainSystem.grid_cells` access inside CellUtil — rejected: couples static utility to autoload, breaks @tool scripts
- Store grid_cells as class variable — rejected: CellUtil is stateless static, adding mutable state is a pattern break
- Pass grid_half instead — rejected: less readable, callers would need to compute it

**Rationale**: Optional parameter preserves backward compatibility. Callers that don't pass it get the autoload default. Callers in @tool or test contexts can pass explicitly.

### 3. Remove get_grid_half_size()

**Choice**: Delete `TerrainSystem.get_grid_half_size()` after all callers are migrated.

**Alternatives considered**:
- Deprecate with warning — rejected: this is an internal utility, no external consumers
- Keep as convenience — rejected: if CellUtil handles centering, half_size is only needed for diamond bounds (already handled by BoundsSystem)

**Rationale**: The function exists solely to support the manual offset pattern. Once CellUtil handles centering, no caller needs it.

### 4. Migrate callers in dependency order

**Choice**: Migrate leaf utilities first (CellUtil), then core systems (TerrainSystem, Pathfinder), then game systems (MapEditor, MapLoader), then UI (EditorGrid, Minimap).

**Alternatives considered**:
- All-at-once migration — rejected: too risky, can't isolate failures
- Bottom-up by file — same as proposed order

**Rationale**: Dependency order ensures each layer works before its consumers are migrated.

## Risks / Trade-offs

- **[Breaking change to cell-util spec]** → All existing scenarios change. Mitigated by updating spec in this change.
- **[36 call sites to migrate]** → Mechanical but easy to miss one. Mitigated by grep-based verification and running full test suite.
- **[Tests will fail during migration]** → Some tests assert first-quadrant coords. Mitigated by updating test assertions as part of the migration.
- **[Pathfinder output changes]** → Path endpoints shift to centered coords. callers that use path positions (MovementController) work in centered space already, so this is correct.
- **[JSON map format unaffected]** → Maps still store cell coords (non-negative). The centering is purely a runtime world-space concern. No migration needed.
