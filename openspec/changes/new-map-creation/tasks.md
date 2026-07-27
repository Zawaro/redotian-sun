## 1. Serialize dimensions (export)

- [x] 1.1 In `TerrainSystem.export_to_json`, add `map_size` from `grid_cells` to the v4 data dictionary
- [x] 1.2 In `TerrainSystem.export_to_json`, add `visible_bounds_size` computed as `[grid_cells.x - 2*offset_x, grid_cells.y - 2*offset_z]` by reading `BoundsSystem` via `get_node_or_null("/root/BoundsSystem")`; omit the field if the autoload is absent

## 2. Restore dimensions (load)

- [x] 2.1 Add `BoundsSystem.apply_saved_bounds(data: Dictionary)` that sets `visible_offset_x/z` from `visible_bounds_size` (converted back to insets, clamped `>= 0`), falling back to defaults `(10, 8)` when the field is missing
- [x] 2.2 In `MapLoader.load_map_into`, after `TerrainSystem.import_from_json`, call `apply_saved_bounds` on the `BoundsSystem` autoload with the parsed JSON

## 3. Always save

- [x] 3.1 In `EditorSaveLoad._on_save_file_selected`, remove the empty-entities guard so `export_to_json` always runs

## 4. Tests

- [x] 4.1 Add `test/unit/test_map_bounds_persistence.gd` covering: v4 export writes correct `map_size`/`visible_bounds_size`; `apply_saved_bounds` restores insets from v4 data; `apply_saved_bounds` falls back to `(10, 8)` for v3 data
- [x] 4.2 Run the headless test suite and confirm all tests pass
