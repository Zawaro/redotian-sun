## 1. Core CellUtil Changes

- [x] 1.1 Add `grid_half` parameter to `CellUtil.cell_to_world()` with default from `TerrainSystem.grid_cells`; subtract offset internally
- [x] 1.2 Add `grid_half` parameter to `CellUtil.world_to_cell()` with default from `TerrainSystem.grid_cells`; add offset internally
- [x] 1.3 Update `CellUtil.cell_origin_to_world()` to accept optional `grid_cells` parameter and center output
- [ ] 1.4 Run existing CellUtil tests — verify failures are due to changed return values (expected), not logic errors

## 2. TerrainSystem Migration

- [x] 2.1 Remove `grid_half` offset from `get_cell_at_world()` (line 163) — pass centered world_pos directly to `world_to_cell()`
- [x] 2.2 Remove `grid_half` offset from `get_height_at_world()` (line 170)
- [x] 2.3 Remove `grid_half` offset from `get_height_at_world_smooth()` (lines 180-181)
- [x] 2.4 Remove `grid_half` offset from `get_normal_at_world()` (lines 199-200)
- [x] 2.5 Delete `get_grid_half_size()` function

## 3. Renderer & Collision Migration

- [x] 3.1 Remove `grid_half` offset from `TerrainRenderer.render_cell()` (line 116)
- [x] 3.2 Remove `grid_half` offset from `TerrainCollision` (line 54)

## 4. Pathfinder Migration

- [x] 4.1 Remove `grid_half` offset from `Pathfinder.find_path()` (line 17) — cell_to_world now returns centered coords

## 5. Map Loading & Editor Migration

- [x] 5.1 Remove `grid_half` offset from `MapLoader.load_map_into()` (line 58) — entity positioning
- [x] 5.2 Remove `grid_half` offset from `MapEditor._update_hovered_cell()` (line 275) — world_to_cell call
- [x] 5.3 Remove `grid_half` offset from `MapEditor._cell_world_pos()` (line 284)
- [x] 5.4 Remove `grid_half` offset from `MapEditor._cell_origin_world_pos()` (lines 294-295)
- [x] 5.5 Remove `grid_half` offset from `EditorGrid._update_cell_highlight()` (line 106)
- [x] 5.6 Remove `grid_half` offset from `EditorGrid._draw_grid()` (lines 185-186) — review if still needed

## 6. UI & Misc Migration

- [x] 6.1 Remove `grid_half` offset from `Minimap` (line 86)
- [x] 6.2 Remove `grid_half` offset from `EntityProperties` (lines 102-103)

## 7. Test Updates

- [x] 7.1 Update `test_pathfinder.gd` — adjust expected world positions to centered coords
- [x] 7.2 Update `test_cell_sub_positions.gd` if affected
- [x] 7.3 Update `test_spatial_hash.gd` if affected
- [x] 7.4 Run full test suite: `redot --headless -s test/run_tests.gd`
- [x] 7.5 Run linter: `gdlint scripts/**/*.gd`

## 8. Cleanup

- [x] 8.1 Grep for any remaining `grid_half` references — verify none are orphaned
- [x] 8.2 Grep for `get_grid_half_size` — verify all call sites removed
- [x] 8.3 Update openspec spec archive: merge delta specs into base `cell-util` and `pathfinder` specs
