## 1. Create CellUtil

- [x] 1.1 Create `scripts/core/CellUtil.gd` with all methods: constants (CELL_SIZE, SQRT2, CELL_KEY_OFFSET), world_to_cell, cell_to_world, cell_key, cell_key_str, heuristic, cell_origin_to_world, get_max_height, spiral_first_free

## 2. Migrate SpatialHash

- [x] 2.1 Remove `_cell_key` method and `_KEY_OFFSET` constant, replace calls with `CellUtil.cell_key()`

## 3. Migrate SelectionManager

- [x] 3.1 Remove `const CELL_SIZE`, replace with `CellUtil.CELL_SIZE`
- [x] 3.2 Replace `_fallback_target()` spiral loop with `CellUtil.spiral_first_free()`

## 4. Migrate TerrainSystem

- [x] 4.1 Remove `const CELL_SIZE` and `_cell_key()`, replace with `CellUtil.CELL_SIZE` and `CellUtil.cell_key_str()`
- [x] 4.2 Add `static func get_grid_half_size() -> float`, replace inline grid_half calculations

## 5. Migrate Terrain Subsystems

- [x] 5.1 Remove `_cell_key()` from TerrainCollision and TerrainRenderer, replace with `CellUtil.cell_key_str()`

## 6. Migrate Pathfinder

- [x] 6.1 Remove `CELL_SIZE`, `SQRT2`, and utility methods (world_to_cell, cell_to_world, _cell_key, _heuristic), replace all internal references with `CellUtil`

## 7. Migrate Components

- [x] 7.1 Replace `_cell_origin_to_world()` and `_get_max_height()` in BuildingManager and DeployComponent with `CellUtil`
- [x] 7.2 Replace spiral loops in FreeUnitComponent, MovementController, ProductionManager, DockHostComponent with `CellUtil.spiral_first_free()`

## 8. Bulk Migrate Pathfinder Callers

- [x] 8.1 Replace `Pathfinder.world_to_cell` → `CellUtil.world_to_cell` across all caller files
- [x] 8.2 Replace `Pathfinder.cell_to_world` → `CellUtil.cell_to_world` across all caller files
- [x] 8.3 Replace `Pathfinder.CELL_SIZE` → `CellUtil.CELL_SIZE` across all caller files

## 9. Migrate Editor and Misc

- [x] 9.1 Replace inline `grid_half` in MapEditor, EditorGrid, Minimap, MapLoader, DebugVisualizer with `TerrainSystem.get_grid_half_size()`
- [x] 9.2 Replace `_cell_origin_world_pos()` in MapEditor with `CellUtil.cell_origin_to_world()`
- [x] 9.3 Replace `Pathfinder.CELL_SIZE` in RallyPointComponent, DockHostComponent, DockClientComponent with `CellUtil.CELL_SIZE`

## 10. Update Tests

- [x] 10.1 Update test_pathfinder.gd and test_spatial_hash.gd references to use CellUtil
- [x] 10.2 Run full test suite: `redot --headless -s test/run_tests.gd`
- [x] 10.3 Run linter: `gdlint scripts/**/*.gd` and `gdformat --check scripts/**/*.gd`
