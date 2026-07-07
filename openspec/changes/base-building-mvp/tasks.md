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
- [x] 3.4 Implement placement validation: bounds, building overlap, unit overlap, terrain type, height variance
- [x] 3.5 Implement `place_building()`: instantiate scene, position at footprint center with max terrain height, register cells in SpatialHash
- [x] 3.6 Register BuildingManager in `project.godot` autoload section

## 4. PlacementPreview

- [x] 4.1 Create `scripts/buildings/PlacementPreview.gd` attached to a Node3D
- [x] 4.2 Implement per-cell BoxMesh foundation tiles at each cell's terrain height
- [x] 4.3 Implement semi-transparent building preview preserving original materials (33% alpha)
- [x] 4.4 Implement grid-snapped position following mouse cursor
- [x] 4.5 Implement per-cell valid/invalid color feedback (green/red per cell)
- [x] 4.6 Implement max terrain height sampling for building preview Y position
- [x] 4.7 Wire PlacementPreview as child of BuildingManager

## 5. Build Menu UI

- [x] 5.1 Create `scripts/ui/BuildMenu.gd` for right-side panel logic
- [x] 5.2 Create `scenes/ui/BuildMenu.tscn` with PanelContainer + VBoxContainer
- [x] 5.3 Implement building buttons from BuildingType resources (cameo + name)
- [x] 5.4 Implement click-to-enter/exit build mode per button
- [x] 5.5 Add BuildMenu to MainScene.tscn (anchored right edge)

## 6. Input Integration

- [x] 6.1 Add build mode guard to MouseHandler._process(): skip selection/movement when BuildingManager.is_build_mode
- [x] 6.2 Add right-click cancellation: exit build mode on deselect_entity input
- [x] 6.3 Add Escape key cancellation: exit build mode on UI cancel input
- [x] 6.4 Wire left-click placement: call BuildingManager.place_building() when valid

## 7. Scene Wiring

- [x] 7.1 Add Buildings parent node (Node3D) to MapBase01.tscn for instantiated buildings
- [x] 7.2 Add PlacementPreview node to MainScene.tscn
- [x] 7.3 Verify MouseHandler still works correctly with build mode guard

## 8. Testing

- [x] 8.1 Unit test: SpatialHash building cell registration and merge
- [x] 8.2 Unit test: Placement validation (bounds, overlap, terrain)
- [x] 8.3 Integration test: Building placement registers cells, pathfinder avoids them
- [x] 8.4 Manual test: Place each building type, verify preview, verify pathfinding block
