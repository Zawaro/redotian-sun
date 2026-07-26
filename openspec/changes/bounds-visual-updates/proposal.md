## Why

The bounds system (`BoundsSystem.gd`) currently draws flat 4-vertex diamond meshes at Y=0.02, ignoring terrain heights. On uneven terrain the boundary lines float above or clip through the ground. The outer bounds use the full grid extent with no visual margin. `BuildingManager` and `ResourceGrowthSystem` hardcode their own bounds independently, creating duplication and risk of desync. There is no way to adjust visible bounds during map editing.

## What Changes

- **BoundsSystem → autoload singleton**: Single source of truth for all bounds. Gameplay systems (`BuildingManager`, `ResourceGrowthSystem`) call BoundsSystem API instead of hardcoding
- **Outer bounds (red) margin**: Move 1 cell inwards on both axes
- **Visible bounds (blue) with configurable offset**: Offset from outer bounds, default 10 cells (x) and 8 cells (z), editable via toolbar SpinBox fields. Diamond check uses the smaller offset.
- **Terrain-following bounds mesh**: Both bounds sample terrain height at cell centers along diamond edges, producing multi-vertex meshes that follow terrain contours
- **X-ray rendering**: Bounds lines render through terrain via `no_depth_test = true`
- **Bounds hidden by default**: Bounds invisible in gameplay, togglable via single DebugMenu "Map Bounds" checkbox
- **Camera clamping follows visible bounds**: Camera stays within the visible play area, not the outer bounds
- **Gameplay API**: `is_in_map_bounds()`, `is_in_play_area()`, `get_map_half_diag()`, etc.
- **Default map size**: 128×128 when MapEditor opens

## Capabilities

### New Capabilities

- `bounds-system`: Autoload singleton — visual bounds mesh, gameplay bounds API, terrain-following mesh, configurable offset
- `map-editor-bounds-ui`: Toolbar offset SpinBox fields for live editing of visible bounds during map editing

### Modified Capabilities

None. `BuildingManager` and `ResourceGrowthSystem` switch to BoundsSystem API but their behavior is unchanged.

## Impact

- `scripts/core/BoundsSystem.gd` — autoload conversion, gameplay API, outer bounds margin, terrain-following mesh, configurable offset, x-ray rendering, visibility toggle
- `scripts/editor/MapEditor.gd` — remove BoundsSystem instance creation, toolbar offset SpinBox fields, default 128×128 map, set `show_bounds = true`
- `scripts/buildings/BuildingManager.gd` — remove hardcoded bounds, use BoundsSystem API
- `scripts/core/ResourceGrowthSystem.gd` — remove hardcoded bounds, use BoundsSystem API
- `scripts/hud/CameraController.gd` — remove @export, use BoundsSystem autoload
- `scripts/hud/MouseHandler.gd` — access bounds via CameraController
- `scripts/ui/DebugMenu.gd` — add "Map Bounds" checkbox toggle
- `project.godot` — register BoundsSystem autoload
- `scenes/maps/TestMap01.tscn`, `TestMap02.tscn`, `MapBase01.tscn` — remove BoundsSystem nodes
