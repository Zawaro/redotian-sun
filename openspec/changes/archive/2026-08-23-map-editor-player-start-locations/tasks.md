## 1. BoundsSystem — default cluster + camera framing

- [x] 1.1 Add `default_start_cell(player_id: int) -> Vector2i` in `BoundsSystem`: computes cluster cell from `grid_cells` center + per-index offset `[(0,0),(1,0),(0,1),(1,1),(-1,0),(0,-1),(-1,-1),(1,-1)]`; asserts/guards in-diamond for even/odd/asymmetric grids
- [x] 1.2 Add `center_camera_on_cell(cell: Vector2i)` in `BoundsSystem`: sets `camera_pivot.global_position` x/z from `CellUtil.cell_to_world(cell)`, preserves pivot y
- [x] 1.3 Unit tests `test/unit/test_player_start_locations.gd`: default cell in-diamond for even, odd, and asymmetric grids; cluster offsets distinct per player; `default_start_cell` matches cluster math for reset case

## 2. PlayerStartTool editor tool

- [x] 2.1 Create `scripts/editor/PlayerStartTool.gd` following `HeightPainter`/`ResourcePainter` node pattern: holds `_overrides {player_id: cell}`, `assign(player, cell)`, `reset(player)`, `effective_cell(player)`, `save_data() -> Array[Dictionary]`, `load_data(arr)`
- [x] 2.2 Marker rendering: one world-space quad per player at `effective_cell` (immediate-mesh, `top_level`), colored by `PlayerData.color` with fixed-palette fallback; rebuild on assign/reset/grid-change
- [x] 2.3 Wire tool in `MapEditor._setup_ui()`: add `Tool.PLAYER_START` to enum, toolbar toggle button, player SpinBox (1..8)
- [x] 2.4 Wire input in `MapEditor._input`: active PLAYER_START → left-click assigns hovered cell (reject + `push_warning` if out of diamond), right-click resets if clicked cell equals the selected player's override cell

## 3. Persistence

- [x] 3.1 `EditorSaveLoad._on_save_file_selected`: pass `{"start_locations": player_start_tool.save_data()}` through `TerrainSystem.export_to_json` `extra_data`
- [x] 3.2 `EditorSaveLoad._on_load_file_selected`: read `start_locations` from loaded JSON and restore into `PlayerStartTool` via `load_data`
- [x] 3.3 Unit tests: save writes overrides only (no defaults), round-trip preserves override, absent key loads empty overrides

## 4. Gameplay camera framing

- [x] 4.1 `MapLoader.load_map_into`: read `start_locations`, and in gameplay (not editor) compute local player's effective start (`override ?? BoundsSystem.default_start_cell(get_local_player_id())`) then call `BoundsSystem.center_camera_on_cell`
- [x] 4.2 Ensure no-start maps (absent key) take the existing code path — camera stays centered; verify no regression through existing map-load tests
- [x] 4.3 Integration test in `test/integration/test_map_editor_e2e.gd` or map-loader test: after loading a map with an override for the local player, `camera_pivot.global_position` x/z match `CellUtil.cell_to_world(stored_cell)`; absent-key case keeps pivot unchanged
- [x] 4.4 BoundsSystem camera-pivot resolution: `_find_camera_pivot()` recursively locates `Camera3D` anywhere under a root child and returns its parent pivot; `_resolve_camera_pivot()` assigns it when still `null` (deferred from `_ready` and on `grid_initialized`), because the autoload runs before the gameplay scene exists
- [x] 4.5 Regression test `test_player_start_locations::test_camera_pivot_resolves_from_scene_hierarchy`: with a real pivot→`Camera3D` hierarchy and `camera_pivot` unset, `MapLoader.load_map_into` on a start-locations map resolves the pivot and frames it on the local player's cell

## 5. Editor integration polish

- [x] 5.1 On `_apply_new_map` and `_apply_map_settings`, clear `PlayerStartTool` overrides and redraw markers (grid can resize — cluster recomputes)
- [x] 5.2 Cleanup markers on editor `_exit_tree` alongside existing `_entity_placer.cleanup()`
- [x] 5.3 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check`; verify `grep -P '\t'` clean for touched files