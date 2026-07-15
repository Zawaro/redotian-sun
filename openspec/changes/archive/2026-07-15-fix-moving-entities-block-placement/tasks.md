## 1. SpatialHash Helper

- [x] 1.1 Add `is_any_entity_on_cell(cell: Vector2i) -> bool` method to `SpatialHash.gd` — checks `_grid` for any non-resource entity on the cell
- [x] 1.2 Add unit test `test_is_any_entity_on_cell` to `test/unit/test_spatial_hash.gd` covering: moving entity, idle entity, resource-only cell, empty cell

## 2. BuildingManager Fix

- [x] 2.1 Add occupancy check in `BuildingManager._is_cell_free()` — call `SpatialHash.instance.is_any_entity_on_cell(cell)` after existing checks, before terrain check
- [x] 2.2 Add unit test `test_can_place_rejects_moving_unit` to `test/unit/test_building_manager.gd` — place a moving unit, assert `can_place()` returns `false`

## 3. Verification

- [x] 3.1 Run `redot --headless -s test/run_tests.gd` — all tests pass
- [x] 3.2 Run `gdlint scripts/buildings/BuildingManager.gd scripts/core/SpatialHash.gd` — no lint errors
