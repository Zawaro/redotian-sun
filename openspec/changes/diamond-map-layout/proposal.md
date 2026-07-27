## Why

The current map system centers the grid at world origin (0,0), placing half the cells in negative XZ space. Tiberian Sun maps are diamond-shaped (rotated rectangles at ±45° to world axes) and should occupy the +XZ quadrant only. The bounds visualization currently draws an axis-aligned rectangle, but the actual playable area is a parallelogram. This causes visual mismatches and negative coordinate issues.

## What Changes

- **BREAKING**: `CellUtil.cell_to_world` offset shifts from centered-at-origin to +XZ quadrant. Cell `(0,0)` world center becomes `(CELL_SIZE, 0, CELL_SIZE)` instead of `(-grid_half, 0, -grid_half)`.
- **BREAKING**: `CellUtil.world_to_cell` inverse offset change.
- **BREAKING**: `CellUtil.cell_origin_to_world` same offset shift.
- **BREAKING**: BoundsSystem containment check changes from rectangular diamond (`abs(cx)/hx + abs(cz)/hz <= 1.0`) to parallelogram formula.
- **BREAKING**: BoundsSystem mesh drawing changes from axis-aligned rectangle to 4-corner diamond (rotated rectangle).
- New: `CellUtil.is_in_diamond(cell, grid_cells) -> bool` — parallelogram containment check.
- EditorGrid draws grid lines clipped to diamond boundary.
- MapEditor terrain prefill uses diamond check.
- TerrainSystem center-offset calculations updated for +XZ layout.

## Capabilities

### New Capabilities

- `diamond-map-layout`: Diamond containment formula, +XZ cell offset, 4-corner bounds visualization

### Modified Capabilities

- `cell-util`: `cell_to_world`, `world_to_cell`, `cell_origin_to_world` offset change; new `is_in_diamond()` function
- `rectangular-grid`: BoundsSystem containment and mesh drawing change from rectangular diamond to parallelogram

## Impact

- **Core systems**: `CellUtil.gd` (coordinate conversion), `BoundsSystem.gd` (bounds visuals + gameplay API), `TerrainSystem.gd` (center-offset queries)
- **Editor**: `EditorGrid.gd` (grid clipping), `MapEditor.gd` (terrain prefill)
- **Pathfinder**: `Pathfinder.gd` (inherits CellUtil change automatically)
- **Callers**: 43+ callers of `cell_to_world`, 48+ callers of `world_to_cell` — world positions change but cell-coordinate logic is unaffected
- **Tests**: `test_pathfinder.gd`, `test_terrain_system.gd` — expected world coordinates change
