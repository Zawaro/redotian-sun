## 1. Asset Setup

- [x] 1.1 Copy terrain model (with embedded textures) from `/mnt/work2/Godot/Tiberian Sun Remake/resources/models/terrain` to `assets/models/terrain/`
- [x] 1.2 Rename copied model files (replace spaces with "_")
- [x] 1.3 Move textures to `assets/textures/terrain/` and update .import files
- [x] 1.4 Verify GLB loads correctly in Redot editor

## 2. Core Terrain System

- [x] 2.1 Create `scripts/core/TerrainSystem.gd` autoload singleton
- [x] 2.2 Register TerrainSystem in `project.godot` autoloads
- [x] 2.3 Create `scripts/core/TerrainData.gd` with cell dictionary storage
- [x] 2.4 Implement `get_cell()`, `set_cell()`, `get_height_at_world()` methods
- [x] 2.5 Implement `export_to_json()` method
- [x] 2.6 Implement `import_from_json()` method
- [x] 2.7 Add `cell_changed` signal emission on cell modification

## 3. Terrain Rendering

- [x] 3.1 Create `scripts/core/TerrainRenderer.gd`
- [x] 3.2 Load terrain GLB as PackedScene
- [x] 3.3 Implement mesh extraction by node name (clear01-08, slope01-06)
- [x] 3.4 Implement mesh instancing at cell world coordinates
- [x] 3.5 Apply triplanar mapping materials from GLB
- [x] 3.6 Organize mesh instances under "Terrain" parent node
- [x] 3.7 Implement dynamic update on cell changes

## 4. Terrain Collision

- [x] 4.1 Create `scripts/core/TerrainCollision.gd`
- [x] 4.2 Implement StaticBody3D creation per cell
- [x] 4.3 Create MeshShape3D using terrain mesh as collision shape
- [x] 4.4 Set collision_layer = 1, collision_mask = 0
- [x] 4.5 Organize collision bodies under "TerrainCollision" parent node
- [x] 4.6 Implement collision update on terrain changes

## 5. Map Editor - Core

- [x] 5.1 Create `scenes/editor/MapEditor.tscn` with isometric camera
- [x] 5.2 Create `scripts/editor/MapEditor.gd` main script
- [x] 5.3 Reuse CameraController for camera movement
- [x] 5.4 Create `scripts/editor/GridOverlay.gd` with ImmediateMesh grid
- [x] 5.5 Implement 2m x 2m grid line rendering
- [x] 5.6 Implement hovered cell highlighting

## 6. Map Editor - Height Painting

- [x] 6.1 Create `scripts/editor/HeightPainter.gd`
- [x] 6.2 Implement left-click detection on cells
- [x] 6.3 Implement drag up/down height adjustment
- [x] 6.4 Implement height clamping (0 to max_height)
- [x] 6.5 Implement auto slope variant selection based on neighbors

## 7. Map Editor - UI

- [x] 7.1 Create VBoxContainer with Save/Load buttons
- [x] 7.2 Implement Save button with file dialog
- [x] 7.3 Implement Load button with file dialog
- [x] 7.4 Add current height label display

## 8. Map Editor - Minimap

- [x] 8.1 Create `scripts/editor/Minimap.gd`
- [x] 8.2 Set up SubViewport with top-down camera
- [x] 8.3 Implement color-coded terrain rendering
- [x] 8.4 Implement click-to-move functionality

## 9. Pathfinder Integration

- [x] 9.1 Modify `scripts/core/Pathfinder.gd` to query TerrainSystem
- [x] 9.2 Add height query in neighbor expansion
- [x] 9.3 Implement default height (0) when no terrain data

## 10. Movement Integration

- [x] 10.1 Modify `scripts/components/MovementController.gd`
- [x] 10.2 Implement Y-interpolation based on cell progress
- [x] 10.3 Implement slope normal alignment for unit rotation
- [x] 10.4 Query terrain height at waypoint positions

## 11. Test Map

- [x] 11.1 Create `scenes/maps/TestMap02.tscn`
- [x] 11.2 Load terrain from JSON file
- [x] 11.3 Place test units (Nod Buggy)
- [x] 11.4 Verify Y-snap works on slopes
- [x] 11.5 Test pathfinding across terrain height changes

## 12. Integration Testing

- [x] 12.1 Test terrain save/load cycle
- [x] 12.2 Test unit movement on flat terrain (regression)
- [x] 12.3 Test unit movement on slopes
- [x] 12.4 Test collision with terrain
- [x] 12.5 Test map editor height painting

## 13. Audit Fixes

### 13.1 Slope Rotation

- [x] 13.1.1 Add `rotation.y = deg_to_rad(rotation)` to `TerrainRenderer.render_cell()`

### 13.2 Terrain Collision Integration

- [x] 13.2.1 Load TerrainCollision.gd in MapEditor.tscn and TerrainRenderer
- [x] 13.2.2 Add cell center offset (`CELL_SIZE * 0.5`) to collision positioning
- [x] 13.2.3 Verify collision shapes match visual meshes

### 13.3 Scene-Exit Cleanup

- [x] 13.3.1 Add `_exit_tree()` to MapEditor.gd calling `TerrainRenderer.clear_all()`
- [x] 13.3.2 Add `_exit_tree()` to TerrainSystem.gd calling `_cells.clear()`

### 13.4 Waypoint Height Query

- [x] 13.4.1 Adjust waypoint Y values in `MovementController.set_target_position()` using `TerrainSystem.get_height_at_world()`

### 13.5 Slope Normal Alignment

- [ ] 13.5.1 Query `TerrainSystem.get_normal_at_world()` in `MovementController._interpolate_height()` and apply rotation to `_rotation_target`

### 13.6 Grid Hover Highlight

- [x] 13.6.1 Draw highlighted cell rectangle on grid overlay in `MapEditor._update_hovered_cell()`

### 13.7 Minimap Integration

- [x] 13.7.1 Instance Minimap.gd in MapEditor.tscn and add to scene tree

### 13.8 JSON Import Visual Cleanup

- [x] 13.8.1 Call `TerrainRenderer.clear_all()` in `TerrainSystem.import_from_json()` before loading new data
