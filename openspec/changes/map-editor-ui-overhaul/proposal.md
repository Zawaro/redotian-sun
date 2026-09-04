## Why

The map editor's UI is an ad-hoc floating toolbar built inline in `MapEditor._setup_ui()`: no faction browsing, no terrain-surface painting, no waypoints, no cliff placement, no undo. Every new editor feature piles onto the elif dispatch chain. The game needs authored maps (Tiberium fields, cliffs, waypoints, houses) to reach the playable milestone, and FinalSun-style tooling is the fastest authoring surface for them.

## What Changes

- **BREAKING (editor-internal)**: the floating ToolBar/Settings menu is replaced by a four-region layout — left sidebar (menu bar, category selector, owner dropdown, searchable faction-grouped object tree, toggleable preview pane), top tool bar (brush size, LAT type, tool toggles, Auto-LAT / Only-paint-on-clear), bottom LAT-group bar (search + swatch previews), top-right column (minimap, info box, EntityProperties).
- Menu bar becomes File / Edit / View / Tools / Scripting; Edit gains undo/redo (new command stack); Scripting is a stub.
- New tools: Waypoint (numbered ≥ 8; 0–7 stay player starts), Delete (supersedes Erase), Framework mode (placeholder flat-color terrain view), combined Raise/Lower plus separate Raise, Lower, Flatten, and a vector Cliff tool with Ramp/Cancel/Accept sub-UI.
- Terrain gains a `_cell_pins` primitive: cliff stamps pin cells (pin = stamp + height-lock + delete), persisted in map JSON.
- Map JSON gains `"waypoints"` and `"cell_pins"`; placed entities gain `house_id` (GDI/Nod/Neutral/Special) with `player_id` kept as alias.
- LandType gains a `group` field; five new land types (sand, pavement, green, crystal, mold) registered with clear-equivalent per-locomotor terrain speeds so painted ground stays traversable (LAT `crystal` is a ground surface, distinct from tiberium resource entities).
- Tool input dispatch moves to a uniform activate/deactivate/on_input protocol; sub-states live inside tools.
- GLOSSARY.md gains LAT, tileset, house, waypoint, framework mode, overlay/smudge entries.

## Capabilities

### New Capabilities

- `map-editor-ui-layout`: four-region editor layout shell — sidebar, top bar, bottom bar, top-right column — and the preview pane toggle.
- `map-editor-object-browser`: category selector, owner (house) dropdown, Ctrl+F search, collapsible faction tree over entities/terrain-objects/overlays/smudges, preview pane binding.
- `map-editor-tool-protocol`: EditorTool interface (activate/deactivate/on_input→consumed), single dispatch loop, tool sub-states (cliff drawing, flatten pick).
- `map-editor-undo`: region-snapshot command stack (TerrainEditCommand, entity, waypoint commands), stroke coalescing, Ctrl+Z/Ctrl+Y.
- `map-editor-terrain-painting`: brush-size height tools (raise/lower/combined/flatten), LAT brush with Auto-LAT and Only-paint-on-clear constraints, LandType-group bottom bar.
- `map-editor-cliff-tool`: vector polyline cliff stamping, ramp caps, Cancel/Accept, cell pinning and height-lock, unpin on delete.
- `map-editor-waypoints`: place/delete numbered waypoints ≥ 8, markers, save/load round-trip.
- `map-editor-framework-mode`: per-LAT flat placeholder terrain rendering toggle (marble-madness view).

### Modified Capabilities

- `map-editor-menus`: menu set changes from File/Settings to File/Edit/View/Tools/Scripting; Show Grid moves under View; Map Settings stays under File.
- `land-types`: LandType resources gain a `group` field used by the editor bottom bar; five new land types registered.
- `terrain-catalog`: `resolve_cell_art` checks cell pins before height-derived resolution.
- `map-loader`: map JSON ingestion of `waypoints` and `cell_pins` (optional keys, backward compatible).

## Impact

- **Scripts**: modified `scripts/editor/MapEditor.gd` (decomposed `_setup_ui`, dispatch loop), `HeightPainter.gd`, `EntityBrowser.gd`, `EditorSaveLoad.gd`; new `scripts/editor/{EditorMenuBar,EditorTopBar,LatBar,EditorInfoBox,EditorPreviewPane,WaypointTool,CliffTool,EditorUndoStack}.gd`; modified `scripts/core/{TerrainSystem,TerrainRenderer,TerrainCatalog}.gd`, `scripts/data/LandType.gd`, `scripts/maps/MapLoader.gd`.
- **Scenes**: no `.tscn` structural changes — editor UI stays script-built under `scenes/editor/MapEditor.tscn`; `AssetPreviewController` untouched (sidebar preview is standalone).
- **Data**: 5 new `resources/land_types/*.tres` + `group` set on existing ones; GLOSSARY.md.
- **Tests**: `test/integration/test_map_editor_e2e.gd` extended; new unit suites (undo, pins, LAT groups, waypoints, house grouping) and integration suites (cliff stamping, framework toggle).
- **Backward compatibility**: existing maps load unchanged — new JSON keys are optional, `player_id` remains a valid alias.
