## Context

`BoundsSystem.gd` is a `@tool` scene node that draws diamond-shaped bounds meshes (red outer, blue visible) using `ImmediateMesh`. Currently both meshes are flat 4-vertex diamonds at Y=0.02, ignoring terrain heights. The outer bounds use `grid_cells * CELL_SIZE / 2.0` with no margin. `BuildingManager` and `ResourceGrowthSystem` hardcode their own bounds independently, creating duplication and unit inconsistencies. The MapEditor toolbar has no way to adjust bounds during editing. Camera clamping uses full grid extent.

## Goals / Non-Goals

**Goals:**
- Convert BoundsSystem from scene node to autoload singleton — single source of truth for all bounds
- Expose gameplay API in cell units: `is_in_map_bounds()`, `is_in_play_area()`, `get_map_half_diag()`, etc.
- Outer bounds (red) moves 1 cell inwards on both axes
- Visible bounds (blue) uses configurable offset from outer bounds, default (10, 8) cells (x, z)
- Both bounds meshes sample terrain height at cell centers along diamond edges, producing multi-vertex meshes that follow terrain contours
- Bounds render in x-ray mode (`no_depth_test = true`) — visible through terrain
- Bounds hidden by default in gameplay, togglable via single DebugMenu checkbox
- Camera clamping follows visible bounds (not outer bounds)
- MapEditor toolbar gains offset SpinBox fields for live editing of visible bounds
- Default map size 128×128 when MapEditor opens

**Non-Goals:**
- Changing JSON save/load format (covered by issue #145 separate scope)
- Changing the "New Map" dialog (covered by issue #145 separate scope)
- Terrain mesh generation beyond bounds lines (e.g., filling the diamond interior)

## Decisions

### 1. BoundsSystem becomes autoload singleton

Convert from scene node to autoload singleton in `project.godot`. Remove nodes from map scenes. All systems access `BoundsSystem` directly.

### 2. API returns cell units; visual mesh converts to world units

**Choice**: Gameplay API (`get_map_half_diag()`, `is_in_map_bounds()`, etc.) returns/values in **cell units**. Visual mesh multiplies by `CELL_SIZE` for world-space rendering. This keeps the diamond check formula identical to current consumer code — no conversion needed at call sites.

Cell units:
- `get_map_half_diag() = (grid_cells - 2) / 2.0`
- `get_play_area_half_diag() = (grid_cells - 2 - offset) / 2.0`

World units (mesh only):
- `half_grid = (grid_cells - 2) * CELL_SIZE / 2.0`
- `half_visible = (grid_cells - 2 - offset) * CELL_SIZE / 2.0`

### 3. Visible bounds with configurable offset

Offset exports `visible_offset_x` (default 10) and `visible_offset_z` (default 8) in cell units. Visible bounds diamond uses the **smaller** offset for the diamond check: `half_diag = (grid_cells - 2 - min(offset_x, offset_z)) / 2.0`. The visual mesh uses per-axis values for the diamond corners. Always centered within outer bounds.

### 4. Terrain-following mesh via edge sampling

Walk each diamond edge at `CELL_SIZE` intervals, sample `get_height_at_world_smooth()`, create `ImmediateMesh` with `PRIMITIVE_LINE_STRIP`. Loop is inlined in `create_bounds_edges()`. Outer and visible bounds share identical loop body — intentional duplication, same corner positions differ.

### 5. Camera clamping follows visible bounds

`get_bounds_rect()` returns visible bounds rect (asymmetric width/height from per-axis offsets). `clamp_camera_position()` clamps to visible bounds, not full grid extent. Camera stays within the play area.

### 6. Default map size 128×128

MapEditor initializes with `map_size = Vector2(128, 128)`.

### 7. Toolbar offset SpinBox fields

"X Offset" and "Z Offset" in cell units (step=1), default 10/8, clamped to `[0, grid_cells - 4]`. Max value updates dynamically when `grid_cells` changes via `grid_initialized` signal.

### 8. Bounds render in x-ray mode

**Choice**: Set `no_depth_test = true` on bounds materials so lines render through terrain. Already use `SHADING_MODE_UNSHADED` and `render_priority = 2`. Adding `no_depth_test` makes bounds visible at all times when enabled.

### 9. Bounds hidden by default in gameplay

**Choice**: Bounds mesh instances (`map_bounds_mesh_instance`, `visible_bounds_mesh_instance`) start with `visible = false` in gameplay. MapEditor overrides to `visible = true`. Single DebugMenu checkbox toggles both.

### 10. DebugMenu toggle for bounds

**Choice**: Add "Map Bounds" checkbox to DebugMenu overlays section. Toggles `BoundsSystem.show_bounds` flag which controls visibility of both mesh instances. Follows existing pattern (e.g., `_on_entity_bounds_toggled`).

## Risks / Trade-offs

- **[Performance]** → ~360 vertices per bounds line on 128×128 grid. ImmediateMesh handles this easily.
- **[Terrain height not yet set]** → Flat mesh at Y=0.02. Updates when terrain changes.
- **[@tool + autoload]** → `Engine.is_editor_hint()` guards for Redot IDE (not in-game map editor). Mesh creation guarded with `is_inside_tree()`.
- **[Minimum visible bounds]** → At max offset (`grid_cells - 4`), visible bounds is 2 cells half-diagonal (4 cells total). Intentional for small maps.
