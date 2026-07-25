## Why

`CellUtil.cell_to_world()` returns first-quadrant coordinates (cell (0,0) → world (1, 1)). Every game-system caller that needs world-centered coords manually subtracts `grid_half` to center the grid at origin (0,0,0). This offset is scattered across 9 files with 36 call sites, creating duplication and a maintenance hazard — any new code that forgets the offset gets misaligned entities, broken pathfinding, or offset terrain.

## What Changes

- **BREAKING**: `CellUtil.cell_to_world()` returns coords centered at world origin (0,0,0) instead of first-quadrant. Cell (0,0) → world (0, 0, 0) instead of (1, 1).
- **BREAKING**: `CellUtil.world_to_cell()` handles centered coords internally (adds grid_half before conversion).
- **BREAKING**: `CellUtil.cell_origin_to_world()` returns centered coords.
- Remove all 36 manual `±grid_half` offset sites across 9 files.
- Remove or deprecate `TerrainSystem.get_grid_half_size()` (no longer needed by callers).
- Existing tests updated to match new centered coordinate system.

## Capabilities

### Modified Capabilities

- `cell-util`: Core coordinate conversion contract changes — `cell_to_world()` and `world_to_cell()` now handle centering internally. All scenario examples change (cell (0,0) → (0,0,0) instead of (1,1)).
- `pathfinder`: Pathfinder uses `cell_to_world()` for path endpoints — output coords shift to centered system. No logic change, just different world positions returned.

### New Capabilities

None.

## Impact

- **CellUtil.gd**: `cell_to_world()`, `world_to_cell()`, `cell_origin_to_world()` signatures unchanged, behavior changes
- **TerrainSystem.gd**: 8 offset sites removed from `get_cell_at_world()`, `get_height_at_world()`, `get_height_at_world_smooth()`, `get_normal_at_world()`
- **TerrainRenderer.gd**: 2 offset sites removed from `render_cell()`
- **TerrainCollision.gd**: 2 offset sites removed
- **Pathfinder.gd**: 2 offset sites removed from `find_path()`
- **MapLoader.gd**: 2 offset sites removed from entity positioning
- **MapEditor.gd**: 6 offset sites removed from cell queries and entity placement
- **EditorGrid.gd**: 4 offset sites removed from grid rendering
- **Minimap.gd**: 2 offset sites removed
- **EntityProperties.gd**: 3 offset sites removed from coordinate display
- **Test files**: `test_pathfinder.gd`, `test_cell_sub_positions.gd`, `test_spatial_hash.gd` assertions updated
- **No scene file changes** — all changes are in GDScript
- **No API changes** — function signatures stay the same, only return values shift
