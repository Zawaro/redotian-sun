## 1. BoundsSystem — Autoload Conversion

- [x] 1.1 Register BoundsSystem as autoload singleton in `project.godot` (class_name unchanged)
- [x] 1.2 Remove BoundsSystem nodes from `scenes/maps/TestMap01.tscn`, `TestMap02.tscn`, `MapBase01.tscn`
- [x] 1.3 Add `var grid_cells: int` to BoundsSystem, synced from TerrainSystem on `grid_initialized`
- [x] 1.4 Guard TerrainSystem access with `Engine.is_editor_hint()` checks (Redot IDE, not in-game map editor)

## 2. BoundsSystem — Gameplay API (cell units)

- [x] 2.1 Add `get_map_half_diag() -> float` — returns `(grid_cells - 2) / 2.0` (cell units)
- [x] 2.2 Add `get_play_area_half_diag() -> float` — returns `(grid_cells - 2 - min(visible_offset_x, visible_offset_z)) / 2.0` (cell units)
- [x] 2.3 Add `is_in_map_bounds(cell: Vector2i) -> bool` — diamond check: `absf(cell.x + 0.5) + absf(cell.y + 0.5) <= get_map_half_diag()`. Note: Vector2i.y maps to z-axis.
- [x] 2.4 Add `is_in_play_area(cell: Vector2i) -> bool` — diamond check: `absf(cell.x + 0.5) + absf(cell.y + 0.5) <= get_play_area_half_diag()`

## 3. BoundsSystem — Visual Changes

- [x] 3.1 Change `half_grid` to `(grid_cells - 2) * CellUtil.CELL_SIZE / 2.0` (world units for mesh)
- [x] 3.2 Add `@export var visible_offset_x: int = 10` and `@export var visible_offset_z: int = 8`
- [x] 3.3 Replace outer bounds 4-vertex flat diamond with `PRIMITIVE_LINE_STRIP` mesh — inline edge sampling loop at `CELL_SIZE` intervals using `get_height_at_world_smooth()`
- [x] 3.4 Replace visible bounds 4-vertex flat diamond with `PRIMITIVE_LINE_STRIP` mesh — same inline sampling (identical loop body, intentional duplication)
- [x] 3.5 Handle Redot IDE mode: when TerrainSystem unavailable, mesh is flat at Y=0.02
- [x] 3.6 Set `no_depth_test = true` on bounds materials for x-ray rendering (visible through terrain)

## 3b. BoundsSystem — Visibility Toggle

- [x] 3b.1 Add `var show_bounds: bool = false` flag to BoundsSystem
- [x] 3b.2 Bounds mesh instances start with `visible = false` at runtime
- [x] 3b.3 Add setter for `show_bounds` that updates both mesh instances' visibility
- [x] 3b.4 MapEditor sets `BoundsSystem.show_bounds = true` on load

## 4. Camera — Visible Bounds Clamping

- [x] 4.1 Update `clamp_camera_position()` to use visible bounds: `half = (grid_cells - 2 - min(offset_x, offset_z)) * CELL_SIZE / 2.0`
- [x] 4.2 Update `get_bounds_rect()` to return visible bounds rect: symmetric `size = Vector2(half * 2, half * 2)` where `half = (grid_cells - 2 - min(offset_x, offset_z)) * CELL_SIZE / 2.0`

## 5. Consumer Migration

- [x] 5.1 Update `CameraController.gd` — remove `@export var bounds_system`, access `BoundsSystem` autoload directly
- [x] 5.2 Update `MouseHandler.gd` — access bounds via `CameraController` which now uses autoload
- [x] 5.3 Update `BuildingManager.gd` — remove hardcoded bounds (`_find_bounds_system()`, `_map_half_diag`, `_play_area_half_diag`); use `BoundsSystem.is_in_map_bounds()` and `BoundsSystem.is_in_play_area()`. Update all callers: `can_place()` (L98-138), `_is_in_bounds()` (L359, L368, L454), `_is_in_play_area()` (L115, L377, L471)
- [x] 5.4 Update `ResourceGrowthSystem.gd` — remove hardcoded bounds (`_find_bounds_system()`, `_map_half_diag`, `_play_area_half_diag`); use `BoundsSystem.is_in_play_area()`. Update all callers: `_try_spread_from()` (L212), `_is_in_bounds()` (L178, L211, L308)
- [x] 5.5 Update `MapEditor.gd` — remove `BoundsSystem.new()` instance creation, remove `camera_instance.bounds_system = bounds` assignment, update singleton exports directly, set `BoundsSystem.show_bounds = true`

## 5b. DebugMenu — Bounds Toggle

- [x] 5b.1 Add `cb_map_bounds` checkbox to DebugMenu overlays section in scene
- [x] 5b.2 Add `_on_map_bounds_toggled(pressed: bool)` handler that sets `BoundsSystem.show_bounds = pressed`
- [x] 5b.3 Connect `cb_map_bounds.toggled` to `_on_map_bounds_toggled` in `_ready()`

## 6. MapEditor — Toolbar UI

- [x] 6.1 Set default `map_size = Vector2(128, 128)` in MapEditor `_setup_ui()`
- [x] 6.2 Add "X Offset" SpinBox (cell units, default 10, min 0, max grid_cells - 4, step 1) with VSeparator
- [x] 6.3 Add "Z Offset" SpinBox (cell units, default 8, min 0, max grid_cells - 4, step 1)
- [x] 6.4 Connect offset SpinBox `value_changed` to `BoundsSystem.visible_offset_x/z` setters
- [x] 6.5 Initialize SpinBox values from BoundsSystem exports on `_ready()`
- [x] 6.6 Connect `TerrainSystem.grid_initialized` to update SpinBox max_value dynamically

## 7. Tests

- [ ] 7.1 Write `test/test_unit/test_bounds_system_api.gd` — test `is_in_map_bounds()`, `is_in_play_area()`, `get_map_half_diag()`, `get_play_area_half_diag()` with various grid sizes and offsets

## 8. Verification

- [x] 8.1 Run `gdlint scripts/core/BoundsSystem.gd scripts/editor/MapEditor.gd scripts/buildings/BuildingManager.gd scripts/core/ResourceGrowthSystem.gd`
- [x] 8.2 Run `gdformat --check scripts/core/BoundsSystem.gd scripts/editor/MapEditor.gd scripts/buildings/BuildingManager.gd scripts/core/ResourceGrowthSystem.gd`
- [ ] 8.3 Run `redot --headless -s test/run_tests.gd`
- [ ] 8.4 Manual test: open MapEditor, verify bounds lines follow terrain, offset SpinBox fields work
- [ ] 8.5 Manual test: place building near bounds edges, verify gameplay bounds match visual bounds
