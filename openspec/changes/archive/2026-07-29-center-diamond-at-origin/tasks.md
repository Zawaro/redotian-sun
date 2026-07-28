## 1. Core CellUtil Changes

- [x] 1.1 Add `grid_cells: Vector2i = Vector2i.ZERO` parameter to `CellUtil.cell_to_world()` with default from `TerrainSystem.grid_cells`; apply centering offset `(W+H)/2` internally
- [x] 1.2 Add `grid_cells: Vector2i = Vector2i.ZERO` parameter to `CellUtil.world_to_cell()` with default from `TerrainSystem.grid_cells`; add centering offset internally
- [x] 1.3 Update `CellUtil.cell_origin_to_world()` to accept optional `grid_cells` parameter and center output
- [x] 1.4 Update `Pathfinder.cell_to_world_with_height()` to use centered coords (remove `+1.5` offset)

## 2. TerrainSystem Migration

- [x] 2.1 Remove `-1.0` offset from `get_height_at_world_smooth()` (lines 182-183) — use `world_pos.x / CS` directly
- [x] 2.2 Remove `-1.0` offset from `get_normal_at_world()` (lines 200-201) — use `world_pos.x / CS` directly

## 3. BoundsSystem Migration

- [x] 3.1 Remove `MAP_OFFSET` constant — center computed dynamically
- [x] 3.2 Update `_compute_diamond_vertices()` to align the outline to the half-open raster midpoint at `Vector3(-CS/2, 0, 0)`
- [x] 3.3 Update `create_bounds_edges()` — red bounds use `(W-0.5, H-0.5)` and blue bounds subtract the configured inset
- [x] 3.4 Simplify `_clamp_to_diamond()` — remove translate param, use centered constraints `a ∈ [-H, H]`, `b ∈ [-W, W]`
- [x] 3.5 Update `clamp_to_map_diamond()` and `clamp_to_visible_diamond()` — remove translate args
- [x] 3.6 Update `_center_camera_on_diamond()` — position pivot at `Vector3(0, y, 0)`
- [x] 3.7 Update `_get_map_center_coordinate()` — return `0.0`
- [x] 3.8 Update `_position_cloud_overlay()` — center at origin
- [x] 3.9 Update `_get_visible_draw_offset()` — compute centered offset from reduced cells
- [x] 3.10 Update `get_bounds_rect()` — center at origin
- [x] 3.11 Update `_in_play_diamond()` — remove `+1.0` offset, use centered constraints

## 4. Minimap Migration

- [x] 4.1 Update `_setup_camera()` — position at `Vector3(0, 100, 0)` instead of `(total*0.5, 100, total*0.5)`

## 5. Component Caller Migrations

- [x] 5.1 Update `TerrainRenderer.render_cell()` — uses `cell_to_world` (transparent, verify)
- [x] 5.2 Update `TerrainCollision.create_collision()` — uses `cell_to_world` (transparent, verify)
- [x] 5.3 Update `MapLoader.load_map_into()` — entity positioning via `cell_to_world` (transparent, verify)
- [x] 5.4 Update `MapEditor` — `_cell_world_pos()`, `_cell_origin_world_pos()`, `_update_hovered_cell()` (transparent, verify)
- [x] 5.5 Update `EditorGrid` — `_update_cell_highlight()`, `_draw_grid()` (transparent, verify)
- [x] 5.6 Update `BuildingManager` — `_update_preview_mesh()`, `_add_grid_and_indicators()` (transparent, verify)
- [x] 5.7 Update `SelectionManager` — `request_move()`, `_fallback_target()` (transparent, verify)
- [x] 5.8 Update `MovementController` — 5 call sites (transparent, verify)
- [x] 5.9 Update `DockClientComponent` — 4 call sites (transparent, verify)
- [x] 5.10 Update remaining components — `DockHostComponent`, `FactoryComponent`, `HarvestComponent`, `DeployComponent`, `ExitComponent`, `FreeUnitComponent`, `RallyPointComponent`, `ResourceComponent` (transparent, verify)
- [x] 5.11 Update `ProductionManager` — `_spawn_unit()` (transparent, verify)
- [x] 5.12 Update `EntityPlacer` — `place_entity()` (transparent, verify)
- [x] 5.13 Update `ResourceGrowthSystem` — `_spawn_at_cell()` (transparent, verify)
- [x] 5.14 Update `SpatialHash.rebuild()` — uses `world_to_cell` (transparent, verify)

## 6. Test Updates

- [x] 6.1 Update `test_pathfinder.gd` — adjust expected world positions to centered coords
- [x] 6.2 Update `test_cell_sub_positions.gd` if affected
- [x] 6.3 Update `test_spatial_hash.gd` if affected
- [x] 6.4 Update any other tests with hardcoded world positions

## 7. Verification

- [x] 7.1 Run full test suite: `redot --headless -s test/run_tests.gd`
- [x] 7.2 Run linter: `gdlint scripts/**/*.gd`
- [x] 7.3 Run formatter check: `gdformat --check scripts/**/*.gd`
- [x] 7.4 Grep for remaining `+ 1.5` and `- 1.0` offset patterns — verify none are orphaned
- [x] 7.5 Manual verification: launch game, confirm diamond centered, camera clamps correctly, minimap works

## 8. Correctness Hardening

- [x] 8.1 Mirror opposite bounds vertices around the half-open raster midpoint and test 45° edges and 90° corners
- [x] 8.2 Restore the half-open raster mask so every W×H map contains exactly `2*W*H` cells
- [x] 8.3 Correct foundation-center math and add the inverse `world_to_cell_origin()` conversion
- [x] 8.4 Migrate missed building-preview and docking world/cell conversions
- [x] 8.5 Replace formula-copying tests with parity, terrain, editor mesh, placement, pathfinding, and docking behavior tests
- [x] 8.6 Run the full test, lint, format, tab, and stale-offset verification suite
