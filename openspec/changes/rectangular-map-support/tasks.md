## 1. Core Type Refactor — CellUtil

- [x] 1.1 Change `CellUtil.world_to_cell` signature from `grid_cells: int = 0` to `grid_cells: Vector2i = Vector2i.ZERO`, use `.x` and `.y` for separate axes
- [x] 1.2 Change `CellUtil.cell_to_world` signature from `grid_cells: int = 0` to `grid_cells: Vector2i = Vector2i.ZERO`, use `.x` and `.y` for separate axes
- [x] 1.3 Change `CellUtil.cell_origin_to_world` signature from `grid_cells: int = 0` to `grid_cells: Vector2i = Vector2i.ZERO`, use `.x` and `.y` for separate axes

## 2. Core Type Refactor — TerrainSystem

- [x] 2.1 Change `DEFAULT_GRID_CELLS` from `int = 64` to `Vector2i = Vector2i(64, 64)`
- [x] 2.2 Change `grid_cells` var from `int` to `Vector2i`, update setter to use `Vector2i(maxi(value.x, 1), maxi(value.y, 1))`
- [x] 2.3 Change `init_grid(cells: int)` to `init_grid(cells_x: int, cells_z: int)`, set `grid_cells = Vector2i(cells_x, cells_z)`
- [x] 2.4 Update `_init_vertex_grid()` to allocate `(grid_cells.x + 1) × (grid_cells.y + 1)` array
- [x] 2.5 Update `get_vertex` and `set_vertex` bounds checks: `vx > grid_cells.x or vz > grid_cells.y`
- [x] 2.6 Update `raise_cell` and `lower_cell` bounds checks: `cx >= grid_cells.x or cz >= grid_cells.y`
- [x] 2.7 Update `get_cell_type`, `get_cell_max_height`, `get_cell_corner_heights`: use `offset_x = grid_cells.x >> 1`, `offset_z = grid_cells.y >> 1`
- [x] 2.8 Update `get_height_at_world_smooth` and `get_normal_at_world`: separate `grid_half_x` and `grid_half_z`
- [x] 2.9 Update `_cascade_from_vertices` and `_add_cells_for_vertex` bounds checks to use separate axes
- [x] 2.10 Update `export_to_json` to write `"grid_cells": [grid_cells.x, grid_cells.y]`
- [x] 2.11 Update `import_from_json` to read array format and call `init_grid(x, z)`, update diamond check to use separate halves

## 3. Core Type Refactor — BoundsSystem

- [x] 3.1 Change `grid_cells` from `int = 64` to `Vector2i = Vector2i(64, 64)`
- [x] 3.2 Replace `get_map_half_diag()` with `get_map_half_extents() -> Vector2` returning `Vector2((grid_cells.x - 2) / 2.0, (grid_cells.y - 2) / 2.0)`
- [x] 3.3 Replace `get_play_area_half_diag()` with `get_play_area_extents() -> Vector2` using separate axes
- [x] 3.4 Update `is_in_map_bounds`, `is_in_play_area`, `is_in_play_area_with_margin` to use `abs(cx)/half_x + abs(cz)/half_z <= 1.0`
- [x] 3.5 Update `_draw_diamond_mesh` to accept `Vector2` for half_diag, draw 4 corners with separate x/z extents
- [x] 3.6 Update `create_bounds_edges` to compute `half_grid` and `half_visible` as Vector2
- [x] 3.7 Update `clamp_camera_position` to use separate bounds per axis
- [x] 3.8 Update `get_bounds_rect` to return Rect2 with separate x/z extents

## 4. Core Type Refactor — EditorGrid

- [x] 4.1 Change `cells` to separate `cells_x = TerrainSystem.grid_cells.x` and `cells_z = TerrainSystem.grid_cells.y`
- [x] 4.2 Update vertical line loop to use `range(cells_x + 1)` with `half_extent_x`
- [x] 4.3 Update horizontal line loop to use `range(cells_z + 1)` with `half_extent_z`
- [x] 4.4 Update diamond outline vertices to use separate half_extents

## 5. Core Type Refactor — Pathfinder

- [x] 5.1 Change default `grid_cells` in `find_path` from `int = 32` to `Vector2i = Vector2i(32, 32)`
- [x] 5.2 Update `cell_to_world_with_height` to accept `grid_cells: Vector2i`
- [x] 5.3 Update `_reconstruct_path` and `_path_or_fallback` to accept `grid_cells: Vector2i`

## 6. Caller Updates

- [x] 6.1 Update `TestMap02.gd`: change `floori(TerrainSystem.grid_cells * 0.5)` to use `.y` for z center
- [x] 6.2 Verify TerrainRenderer, TerrainCollision, MapLoader, Minimap, EntityProperties pass `TerrainSystem.grid_cells` correctly (no code changes needed, just verify type compatibility)

## 7. MapEditor Toolbar Redesign

- [x] 7.1 Remove standalone Save button, Load button, Grid checkbox, X Offset SpinBox, Z Offset SpinBox from toolbar
- [x] 7.2 Add "File" MenuButton with PopupMenu containing New, Load, Save items
- [x] 7.3 Add "Settings" MenuButton with PopupMenu containing Map Settings and Show Grid items
- [x] 7.4 Wire File menu items: New opens New Map dialog, Load calls `_save_load.on_load_pressed()`, Save calls `_save_load.on_save_pressed()`
- [x] 7.5 Wire Settings menu items: Map Settings opens Map Settings dialog, Show Grid toggles `_grid.set_grid_visible()` with checkbox state
- [x] 7.6 Set Show Grid default to off (unchecked, grid hidden on open)

## 8. New Map Dialog

- [x] 8.1 Create New Map dialog as PopupPanel with fields: Map Name (LineEdit), Width (SpinBox, min 50, max 512, step 2, default 64), Height (SpinBox, min 50, max 512, step 2, default 64), Starting Height (SpinBox, min 0, max 15, step 4), Player Count (SpinBox, min 2, max 8, default 2), Visible Bounds (read-only Label)
- [x] 8.2 Connect Width/Height SpinBox `value_changed` to update Visible Bounds label: `(width-10, height-8)`
- [x] 8.3 Add Confirm ("Create") and Cancel buttons at bottom of dialog
- [x] 8.4 Implement Confirm action: read fields, call `TerrainSystem.init_grid()`, set BoundsSystem offsets to (10, 8), clear and rebuild terrain, redraw grid, close dialog
- [x] 8.5 Implement Cancel action: close dialog without changes

## 9. Map Settings Dialog

- [x] 9.1 Create Map Settings dialog as PopupPanel with same fields as New Map dialog
- [x] 9.2 Pre-populate fields with current values from `TerrainSystem.grid_cells`, `BoundsSystem.visible_offset_*`
- [x] 9.3 Connect Width/Height SpinBox `value_changed` to update Visible Bounds label
- [x] 9.4 Add Confirm ("Apply") and Cancel buttons at bottom of dialog
- [x] 9.5 Implement Confirm action: read fields, call `TerrainSystem.init_grid()`, set BoundsSystem offsets, rebuild terrain, redraw grid, close dialog
- [x] 9.6 Implement Cancel action: close dialog without changes

## 10. Scene Cleanup

- [x] 10.1 Remove stale `visible_bounds_size` property from MapEditor.tscn
- [x] 10.2 Update MapEditor.tscn `map_size` default to `Vector2(64, 64)`

## 11. Lint and Verify

- [x] 11.1 Run `gdlint` on all modified scripts
- [x] 11.2 Run `gdformat --check` on all modified scripts
- [x] 11.3 Run `grep -P '\t'` to check for tab introduction in multi-line strings
- [x] 11.4 Verify no regressions: run test suite with `redot --headless -s test/run_tests.gd`
