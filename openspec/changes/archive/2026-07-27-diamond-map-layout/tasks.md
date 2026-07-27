## 1. CellUtil — +XZ Offset

- [x] 1.1 Change `cell_to_world` formula to `(cell.x + 1) * CELL_SIZE` for x and `(cell.y + 1) * CELL_SIZE` for z (remove `- grid_half` offset)
- [x] 1.2 Change `world_to_cell` formula to `floori(world_pos.x / CELL_SIZE) - 1` for x and `floori(world_pos.z / CELL_SIZE) - 1` for z
- [x] 1.3 Change `cell_origin_to_world` formula to `(origin.x + footprint.x * 0.5) * CELL_SIZE` for x and `(origin.y + footprint.y * 0.5) * CELL_SIZE` for z
- [x] 1.4 Add `is_in_diamond(cell: Vector2i, grid_cells: Vector2i) -> bool` with rotated rectangle containment formula

## 2. BoundsSystem — Diamond Mesh

- [x] 2.1 Compute diamond vertices based on `(W+H) % 2`: 4 vertices for odd sum, 8 vertices for even sum (with2-unit connectors at corners)
- [x] 2.2 Replace rectangle mesh drawing with `PRIMITIVE_LINE_STRIP` through computed vertices (close loop back to first vertex)
- [x] 2.3 Add terrain-following: sample `get_height_at_world_smooth()` at intermediate points along each diagonal edge
- [x] 2.4 Apply same diamond mesh for visible bounds (with offset applied to W/H)

## 3. BoundsSystem — Gameplay API

- [x] 3.1 Change `is_in_map_bounds(cell)` to use `CellUtil.is_in_diamond(cell, grid_cells)`
- [x] 3.2 Change `is_in_play_area(cell)` to use `CellUtil.is_in_diamond(cell, grid_cells - Vector2i(offset_x, offset_z))`
- [x] 3.3 Update `clamp_camera_position()` to clamp to diamond AABB: `x ∈ [0, (W+H)*2]`, `z ∈ [0, (W+H)*2]`
- [x] 3.4 Update `get_bounds_rect()` to return diamond AABB

## 4. EditorGrid — Diamond Clipping

- [x] 4.1 Rewrite `_draw_grid()` to draw vertical lines clipped to diamond z-bounds at each x
- [x] 4.2 Rewrite horizontal lines to clip to diamond x-bounds at each z
- [x] 4.3 Draw diamond outline as the grid boundary

## 5. TerrainSystem — Center Offset

- [x] 5.1 Update `get_cell_type()` center offset calculation for +XZ layout
- [x] 5.2 Update `get_cell_max_height()` center offset calculation
- [x] 5.3 Update `get_cell_corner_heights()` center offset calculation
- [x] 5.4 Update `get_height_at_world_smooth()` and `get_normal_at_world()` for separate x/z halves

## 6. MapEditor — Terrain Prefill

- [x] 6.1 Update `_prefill_terrain()` to use `CellUtil.is_in_diamond()` instead of `rx + rz >= 1.0`

## 7. Pathfinder — Inherited Changes

- [x] 7.1 Update `Pathfinder.cell_to_world_with_height()` to use new CellUtil offset formula (replace `(cell.x + 0.5) * CELL_SIZE - grid_half_x` with `(cell.x + 1) * CELL_SIZE`)

## 8. Tests

- [x] 8.1 Update `test_pathfinder.gd` — fix `test_cell_to_world_origin` and `test_cell_to_world_roundtrip` expected values
- [x] 8.2 Update `test_terrain_system.gd` — fix any world-coordinate expectations
- [x] 8.3 Add test for `CellUtil.is_in_diamond()` — test inside/outside/boundary cases
- [x] 8.4 Run full test suite: `redot --headless -s test/run_tests.gd`

## 9. Lint and Verify

- [x] 9.1 Run `gdlint` on all modified scripts
- [x] 9.2 Run `gdformat --check` on all modified scripts
- [x] 9.3 Run `grep -P '\t'` to check for tab introduction
- [ ] 9.4 Manual test: open MapEditor, verify diamond bounds, grid clipping, cell positioning
