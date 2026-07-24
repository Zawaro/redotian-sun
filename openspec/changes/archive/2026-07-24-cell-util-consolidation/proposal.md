## Why

Cell coordinate math (`world_to_cell`, `cell_to_world`, `_cell_key`, `CELL_SIZE`, spiral search) is duplicated across 5+ files with 2 different `_cell_key` signatures. Pathfinder doubles as a utility library — 60+ callers import it solely for `world_to_cell` and `cell_to_world`, masking its actual purpose as an A* pathfinder. This makes the codebase harder to navigate and increases the risk of inconsistencies between duplicate implementations.

## What Changes

- **New `CellUtil` static class** (`scripts/core/CellUtil.gd`) — canonical source for all pure cell coordinate math: `world_to_cell`, `cell_to_world`, `cell_key` (int), `cell_key_str` (string), `heuristic`, `spiral_first_free`
- **New `FoundationUtil` static class** (`scripts/core/FoundationUtil.gd`) — consolidates identical `_cell_origin_to_world` and `_get_max_height` methods duplicated between BuildingManager and DeployComponent
- **New `TerrainSystem.get_grid_half_size()`** — replaces 10+ inline copies of `float(TerrainSystem.grid_cells) * CELL_SIZE * 0.5`
- **Remove duplication**: `_cell_key` (5 copies → 0), `CELL_SIZE` (3 copies → 1), `_cell_origin_to_world` (2 copies → 1), `_get_max_height` (2 copies → 1), spiral search loops (7 copies → 0)
- **Slim down Pathfinder**: remove utility methods, keep only A* logic. Pathfinder delegates to CellUtil during migration, then methods are removed once all callers are migrated

## Capabilities

### New Capabilities
- `cell-util`: Static cell coordinate utility class — world/cell conversion, cell keys, heuristic, spiral search
- `foundation-util`: Static foundation utility — cell-origin-to-world conversion and max height across foundation footprints

### Modified Capabilities
- `entity-components`: MovementController, DeployComponent, FreeUnitComponent spiral search consolidated into CellUtil
- `factory-component`: ProductionManager exit cell search uses CellUtil spiral search

## Impact

- **Scripts affected** (~20 files): `Pathfinder.gd`, `SpatialHash.gd`, `TerrainSystem.gd`, `TerrainCollision.gd`, `TerrainRenderer.gd`, `SelectionManager.gd`, `BuildingManager.gd`, `DeployComponent.gd`, `FreeUnitComponent.gd`, `MovementController.gd`, `ProductionManager.gd`, `MapEditor.gd`, `EditorGrid.gd`, `Minimap.gd`, `MapLoader.gd`, `DebugVisualizer.gd`, `EntityProperties.gd`, `RallyPointComponent.gd`, `DockHostComponent.gd`, `DockClientComponent.gd`
- **New files**: `scripts/core/CellUtil.gd`, `scripts/core/FoundationUtil.gd`
- **Tests affected**: `test_pathfinder.gd`, `test_spatial_hash.gd`
- **No scene changes** — all changes are script-level
- **No API changes** — public interfaces remain the same, implementation moves
