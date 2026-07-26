## Context

The map system currently uses a single `int grid_cells` to define a square grid. This flows through TerrainSystem (vertex grid allocation, bounds checks, cell queries), CellUtil (world↔cell coordinate conversion), BoundsSystem (diamond mesh rendering, gameplay API), EditorGrid (grid drawing), and Pathfinder (path reconstruction). All assume square geometry.

The map editor toolbar has Save/Load buttons, Grid checkbox, and offset spinboxes as standalone controls. These need to move into dropdown menus to make room for New Map and Map Settings dialogs.

Tiberian Sun maps are rectangular (e.g., 50×80 cells). The camera is rotated 45°, so a rectangular map appears as a diamond (rhombus) in world space with different extents on the x and z axes.

## Goals / Non-Goals

**Goals:**
- Support rectangular maps (non-square diamonds) via `Vector2i` grid_cells
- Restructure MapEditor toolbar with File and Settings dropdown menus
- Add New Map dialog (name, size, starting height, player count)
- Add Map Settings dialog to modify map parameters on existing maps
- Auto-calculate visible bounds from map size with margin (10, 8)
- Grid checkbox off by default, moved to Settings menu

**Non-Goals:**
- Backward compatibility with old JSON format (alpha dev, no migration needed)
- Changing the diamond shape algorithm (still Manhattan-distance diamond)
- Modifying the BoundsSystem `-2` margin (preserves Tiberian Sun FinalSun behavior)
- Adding new terrain features or cell types

## Decisions

### 1. Vector2i for grid_cells instead of separate x/z variables

**Decision**: Change `grid_cells` from `int` to `Vector2i` throughout the stack.

**Rationale**: A single `Vector2i` is cleaner than two separate variables (`grid_cells_x`, `grid_cells_z`). It passes naturally through function signatures, matches the existing `map_size: Vector2` pattern in MapEditor, and makes the API self-documenting.

**Alternatives considered**:
- Two separate ints: More verbose, easy to swap axes accidentally
- Keep int, add max(x,y) for grid: Wastes memory for rectangular maps, doesn't solve the actual problem

### 2. Diamond check formula for rectangular maps

**Decision**: Use `abs(cx)/half_x + abs(cz)/half_z <= 1.0` for the diamond containment check.

**Rationale**: This is the standard parametric diamond (rhombus) equation. When half_x == half_z it reduces to the current square diamond formula. The formula is simple, fast, and mathematically correct.

**Alternatives considered**:
- Pre-compute a bitmask of valid cells: More memory, faster lookup, but overkill for this scale
- Use separate axis checks: Doesn't produce a diamond shape

### 3. Visible bounds auto-calculation

**Decision**: `visible_bounds = map_size - Vector2i(10, 8)`, with offset always (10, 8).

**Rationale**: The original Tiberian Sun used fixed margins. The 10/8 values come from the existing `visible_offset_x = 10`, `visible_offset_z = 8` defaults. Auto-calculating avoids manual coordination between map size and visible bounds.

**Alternatives considered**:
- User manually sets both: Error-prone, confusing UX
- Different margin values: Sticking with existing defaults for consistency

### 4. PopupPanel dialogs instead of embedded UI

**Decision**: Use `PopupPanel` for New Map and Map Settings dialogs.

**Rationale**: PopupPanel provides built-in modal behavior, title bar, and close button. It's the standard Redot pattern for dialogs. The dialogs are infrequent-use (create/edit map), so popup latency is acceptable.

**Alternatives considered**:
- Embedded panel in toolbar: Would clutter the toolbar, harder to manage state
- Custom Window node: More work, same result as PopupPanel

### 5. Grid checkbox off by default

**Decision**: Grid visibility defaults to off. Toggle lives in Settings menu.

**Rationale**: The grid is useful for editing but clutters the view during normal use. Moving it to the Settings menu keeps the toolbar clean while remaining accessible.

**Alternatives considered**:
- Keep in toolbar: Takes space, less important than tool buttons
- On by default: User preference, but off is cleaner for new maps

## Risks / Trade-offs

- **[Risk] Type signature changes propagate broadly** → Mitigated by the fact that CellUtil methods accept `Vector2i` with a default, and most callers just pass `TerrainSystem.grid_cells` which changes type automatically.
- **[Risk] JSON format break** → Acceptable in alpha. No migration needed.
- **[Risk] EditorGrid diamond drawing with asymmetric extents** → The diamond edges become non-45° lines. The line interpolation in `_draw_diamond_mesh` handles this by stepping along each edge independently.
- **[Trade-off] Visible bounds shown as read-only in New dialog** → Simpler than making them editable. User can adjust in Map Settings later.
