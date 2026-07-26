## Why

The map editor currently only supports square maps because `TerrainSystem.grid_cells` is a single `int`. Tiberian Sun maps are rectangular (e.g., 50×80), and the editor needs to support this. Additionally, the toolbar layout needs restructuring — Save/Load buttons and offset spinboxes should move into dropdown menus to make room for new map creation and settings dialogs.

## What Changes

- **BREAKING**: `TerrainSystem.grid_cells` changes from `int` to `Vector2i` (x, z dimensions). All callers must be updated.
- **BREAKING**: `CellUtil.world_to_cell`, `cell_to_world`, `cell_origin_to_world` signatures change from `grid_cells: int` to `grid_cells: Vector2i`.
- **BREAKING**: `BoundsSystem` diamond mesh and gameplay API now use separate x/z extents instead of a single half-diagonal.
- **BREAKING**: `EditorGrid` draws a rectangular diamond (rhombus) instead of a square diamond.
- **BREAKING**: `Pathfinder` grid_cells parameter changes to `Vector2i`.
- **BREAKING**: `TerrainSystem.export_to_json` / `import_from_json` format changes — `grid_cells` becomes a two-element array `[x, z]`.
- **BREAKING**: MapEditor toolbar layout changes — Save/Load move to File dropdown, Grid checkbox and offset spinboxes move to Settings dropdown.
- **BREAKING**: `map_editor_tiberium` toolbar spec requirement changes (toolbar layout).
- New: "File" dropdown menu with New, Load, Save items.
- New: "Settings" dropdown menu with Map Settings dialog and Show Grid toggle.
- New: "New Map" dialog with map name, size, starting height, player count, and auto-calculated visible bounds.
- New: "Map Settings" dialog to change map parameters on an existing map.
- Visible bounds auto-calculate from map size: `visible_bounds = map_size - Vector2i(10, 8)`.

## Capabilities

### New Capabilities
- `rectangular-grid`: Vector2i refactor of TerrainSystem, CellUtil, BoundsSystem, EditorGrid, Pathfinder to support non-square maps.
- `map-editor-menus`: File and Settings dropdown menus in the map editor toolbar.
- `map-editor-dialogs`: New Map and Map Settings dialogs with confirm/cancel flow.

### Modified Capabilities
- `map-editor-tiberium`: Toolbar layout changes — Save/Load move to File menu, Grid/offset controls move to Settings menu.

## Impact

- **Core systems**: `TerrainSystem`, `CellUtil`, `BoundsSystem`, `EditorGrid`, `Pathfinder` — type signature changes propagate to all callers.
- **Map editor**: `MapEditor.gd` — toolbar rebuild, new dialogs, init_grid call changes.
- **Scene files**: `MapEditor.tscn` — remove stale properties, update defaults.
- **Callers**: `TerrainRenderer`, `TerrainCollision`, `MapLoader`, `Minimap`, `EntityProperties`, `TestMap02` — pass Vector2i to CellUtil.
- **JSON format**: `export_to_json` / `import_from_json` — grid_cells becomes array.
