## Why

The map diamond is offset into the +XZ quadrant via a hardcoded 1-cell origin shift in CellUtil (`+1.5` in `cell_to_world`, `-1` in `world_to_cell`). This creates asymmetric world coordinates where cell (0,0) maps to world (3,3). Every bounds check, camera clamp, and height query must account for this offset, scattering coordinate math across 9+ files. The previous centering change (commit `4b39526`) was reverted by the diamond-map-layout change (commit `375a70c`) which chose the +XZ quadrant approach. This change re-applies centering with a cleaner design that supports asymmetric (rectangular) maps.

## What Changes

- **BREAKING**: `CellUtil.cell_to_world()` returns coords centered at world origin (0,0,0). Cell (0,0) maps to `(-(W+H)/2 + 0.5) * CS` instead of `(0 + 1.5) * CS`.
- **BREAKING**: `CellUtil.world_to_cell()` handles centered coords internally (adds `(W+H)/2` before conversion).
- **BREAKING**: `CellUtil.cell_origin_to_world()` returns centered coords.
- **BREAKING**: `Pathfinder.cell_to_world_with_height()` uses centered coords.
- Remove all 36+ manual offset sites across components, editors, and systems.
- **BoundsSystem**: Diamond vertices use centered dimensions plus a `-CS/2` X offset to align with the half-open owned-cell raster. Red bounds use `(W-0.5, H-0.5)`; blue bounds subtract their configured inset from those dimensions.
- **TerrainSystem**: Remove hardcoded `-1.0` offsets in `get_height_at_world_smooth` and `get_normal_at_world`.
- **Minimap**: Camera at `(0, 100, 0)` instead of `(total*0.5, 100, total*0.5)`.
- **BoundsSystem**: `_center_camera_on_diamond` positions pivot at `(0, y, 0)`. Cloud overlay centered at origin.
- Existing tests updated to match centered coordinate system.

## Capabilities

### Modified Capabilities

- `cell-util`: Core coordinate conversion contract changes — `cell_to_world()` and `world_to_cell()` now handle centering internally using `(W+H)/2` offset. All scenario examples change.
- `pathfinder`: `cell_to_world_with_height` uses centered coords. `find_path` output waypoints shift to centered system.
- `rectangular-grid`: Diamond vertex positions change to centered formula. Bounds check examples update.

### New Capabilities

None.

## Impact

- **CellUtil.gd**: `cell_to_world()`, `world_to_cell()`, `cell_origin_to_world()` behavior changes
- **BoundsSystem.gd**: `MAP_OFFSET` removed, `_compute_diamond_vertices` centered, `_clamp_to_diamond` simplified, `_center_camera_on_diamond` → origin, `_position_cloud_overlay` → origin
- **TerrainSystem.gd**: `get_height_at_world_smooth`, `get_normal_at_world` remove `-1.0` offsets
- **Pathfinder.gd**: `cell_to_world_with_height` centered
- **Minimap.gd**: Camera position centered
- **~80 call sites** across components, editors, systems — mechanical updates
- **Test files**: `test_pathfinder.gd`, `test_terrain_system.gd`, `test_cell_sub_positions.gd`
- No scene file changes, no JSON format changes
