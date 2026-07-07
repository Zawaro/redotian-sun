## 1. SpatialHash Building Layer

- [x] 1.1 Add `_building_cells: Dictionary = {}` to SpatialHash.gd
- [x] 1.2 Add `register_building_cells(cells: Array[Vector2i])` method to SpatialHash.gd
- [x] 1.3 Add `unregister_building_cells(cells: Array[Vector2i])` method to SpatialHash.gd
- [x] 1.4 Modify `get_blocked_cells()` to merge `_blocked_cells` + `_building_cells`
- [ ] 1.5 Add unit tests for register/unregister/merge in test_spatial_hash.gd

## 2. BuildingType Resource

- [x] 2.1 Create `scripts/buildings/BuildingType.gd` with `class_name BuildingType extends Resource`
- [x] 2.2 Define `@export` fields: id, display_name, footprint, scene, cameo, cost, build_time
- [x] 2.3 Create placeholder building scenes: PowerPlant, Barracks, Refinery, WarFactory, GuardTower (BoxMesh + HealthComponent + HitboxComponent + SelectComponent)
- [x] 2.4 Create 6 `.tres` resources in `resources/buildings/` for each GDI building

## 3. BuildingManager Core

- [x] 3.1 Create `scripts/buildings/BuildingManager.gd` as autoload singleton
- [x] 3.2 Implement build mode state: `is_build_mode`, `current_building_type`
- [x] 3.3 Implement `enter_build_mode(building_type)` and `exit_build_mode()`
- [x] 3.4 Implement placement validation: diamond-shaped bounds, building overlap, unit overlap, terrain type, height variance
- [x] 3.5 Implement `place_building() -> bool`: instantiate scene, position at footprint center with max terrain height, register cells in SpatialHash
- [x] 3.6 Register BuildingManager in `project.godot` autoload section

## 4. PlacementPreview

- [x] 4.1 Create preview Node3D as child of BuildingManager
- [x] 4.2 Implement per-cell procedural ImmediateMesh foundation tiles from `get_cell_corner_heights()` vertex grid
- [x] 4.3 Implement semi-transparent building preview preserving original materials (33% alpha)
- [x] 4.4 Implement grid-snapped position following mouse cursor
- [x] 4.5 Implement per-cell valid/invalid color feedback (green/red at 75% alpha per cell)
- [x] 4.6 Implement max terrain height sampling for building preview Y position
- [x] 4.7 Foundation mesh instance at Y=0 (vertex heights carry absolute Y, no double-counting)
- [x] 4.8 Hide building scene preview at map bounds (not play area bounds)
- [x] 4.9 Foundation cells outside map bounds not rendered; margin zone cells all red

## 5. Grid Wireframe

- [x] 5.1 Implement circular grid wireframe extending 3 cells beyond foundation
- [x] 5.2 Use thick ImmediateMesh quads (0.05 width) with CULL_DISABLED at 10% white opacity
- [x] 5.3 Grid lines follow terrain slopes via vertex grid heights
- [x] 5.4 Grid Y+0.001 offset to avoid z-fighting with foundation cells
- [x] 5.5 Occupied/slope cells in grid area outside foundation show red
- [x] 5.6 Grid loop expanded +1 for full diamond coverage

## 6. Diamond-Shaped Bounds

- [x] 6.1 Implement `_is_in_bounds()` using cell centers: `absf(float(cell.x) + 0.5) + absf(float(cell.y) + 0.5) <= half_diagonal`
- [x] 6.2 Implement `_is_in_play_area()` with smaller half_diagonal
- [x] 6.3 Cache `_map_half_diag` and `_play_area_half_diag` from BoundsSystem in `_ready()`
- [x] 6.4 `can_place()` rejects out-of-bounds and out-of-play-area cells

## 7. Build Menu UI

- [x] 7.1 Create `scripts/ui/BuildMenu.gd` for right-side panel logic
- [x] 7.2 Create `scenes/ui/BuildMenu.tscn` with PanelContainer + GridContainer (3-column layout)
- [x] 7.3 Implement building buttons with 128×96 cameo textures and labels inside cameos
- [x] 7.4 Implement click-to-enter/exit build mode per button
- [x] 7.5 Add BuildMenu to MapBase01.tscn (accessible from all maps)

## 8. Input Integration

- [x] 8.1 Add build mode guard to MouseHandler._process(): skip selection/movement when BuildingManager.is_build_mode
- [x] 8.2 Add `_is_inside_build_menu()` check to prevent clicks on menu triggering placement
- [x] 8.3 Add right-click cancellation: exit build mode on deselect_entity input
- [x] 8.4 Add Escape key cancellation: exit build mode on UI cancel input
- [x] 8.5 Wire left-click placement: call BuildingManager.place_building() when valid
- [x] 8.6 Invalid placement keeps build mode active (only successful placement exits)

## 9. Terrain System Extensions

- [x] 9.1 Add `get_cell_corner_heights(cell) -> Array[float]` with offset to TerrainSystem
- [x] 9.2 Add `get_cell_max_height(cell) -> float` with offset to TerrainSystem
- [x] 9.3 Add `get_cell_type(cell) -> String` with offset to TerrainSystem

## 10. Scene Wiring

- [x] 10.1 Add Buildings parent node (Node3D) to MapBase01.tscn for instantiated buildings
- [x] 10.2 Add BuildMenu instance to MapBase01.tscn
- [x] 10.3 Verify MouseHandler still works correctly with build mode guard

## 11. Testing

- [x] 11.1 Unit test: SpatialHash building cell registration and merge
- [x] 11.2 Unit test: Placement validation (bounds, overlap, terrain)
- [x] 11.3 Integration test: Building placement registers cells, pathfinder avoids them
- [x] 11.4 Manual test: Place each building type, verify preview, verify pathfinding block
- [x] 11.5 Manual test: Diamond-shaped bounds edge cases, play area margin
