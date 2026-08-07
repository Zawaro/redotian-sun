## 1. Four-inset visible bounds model

- [x] 1.1 Replace `BoundsSystem.visible_offset_x/z` and `visible_bounds_size` with `left_inset` / `right_inset` / `top_inset` / `bottom_inset` exports (defaults 5/5/4/4), each with a clamping setter that redraws edges
- [x] 1.2 Update `_in_play_diamond`, `create_bounds_edges` (via `_compute_visible_diamond_vertices`), and `clamp_to_visible_diamond` to honor the four per-edge insets
- [x] 1.3 Update `MapEditor` New Map and Map Settings dialogs: four inset SpinBoxes with dynamic maxes (`top_max = 2h - bottom - 1`, etc.), read-only visible-bounds label, and pass the insets through `_apply_new_map` / `_apply_map_settings`

## 2. Serialize dimensions (export)

- [x] 2.1 In `TerrainSystem.export_to_json`, add `map_size` from `grid_cells` to the v4 data dictionary
- [x] 2.2 In `TerrainSystem.export_to_json`, write `visible_bounds` as `[left_inset, right_inset, top_inset, bottom_inset]` by reading `BoundsSystem` via `get_node_or_null("/root/BoundsSystem")`; omit the field if the autoload is absent

## 3. Restore dimensions (load)

- [x] 3.1 Add `BoundsSystem.apply_saved_bounds(data: Dictionary)` that sets the four insets from `visible_bounds` (clamped `>= 0`), falling back to defaults `(5, 5, 4, 4)` when the field is missing
- [x] 3.2 In `MapLoader.load_map_into`, after `TerrainSystem.import_from_json`, call `apply_saved_bounds` on the `BoundsSystem` autoload with the parsed JSON

## 4. Always save

- [x] 4.1 In `EditorSaveLoad._on_save_file_selected`, remove the empty-entities guard so `export_to_json` always runs

## 5. Tests

- [x] 5.1 Update `test/unit/test_map_bounds_persistence.gd`: v4 export writes `map_size`/`visible_bounds`; `apply_saved_bounds` restores the four insets; v3 fallback to `(5, 5, 4, 4)`; negative-inset clamp
- [x] 5.2 Update `test/unit/test_centered_bounds.gd` for the 4-inset play mask / outline / clamp, plus an asymmetric-inset shift test
- [x] 5.3 Update `test/integration/test_map_editor_e2e.gd` to pass insets through `_apply_new_map` and assert them
- [x] 5.4 Run the headless test suite and confirm all tests pass
