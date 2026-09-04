## 1. Data: land types and houses

- [x] 1.1 Add `group: String` to `LandType.gd`; set `group` on the six existing `resources/land_types/*.tres` (clear, rough, road, water, cliff, resource)
- [x] 1.2 Author `sand.tres`, `pavement.tres`, `green.tres`, `crystal.tres`, `mold.tres` mirroring `rough.tres` with ids, display names, editor colors, and groups; register them wherever GlobalRules scans land-type `.tres`; add clear-equivalent terrain-speed entries for all five to every locomotor `.tres` whose `terrain_speeds` lists `clear`
- [x] 1.3 Add `Houses` enum (GDI/NOD/NEUTRAL/SPECIAL) to a shared location; extend `EditorSaveLoad` to write `house_id` alongside the legacy `player_id` and `MapLoader`/`EntityPlacer` to accept `house_id` (fallback to `player_id`)
- [x] 1.4 Unit tests: new land types registered and resolvable; `group` defaults empty; two fixture LandTypes sharing a group browse together; locomotors pass on all five new types at clear's multiplier; house round-trip and legacy `player_id`-only entries load
- [x] 1.5 Update GLOSSARY.md: `LAT`, `tileset`, `house`, `waypoint`, `framework mode`, `overlay`/`smudge` (with fog-overlay disambiguation); note `template` stays reserved for TS `.tem`

## 2. Terrain primitives: pins and locked cells

- [x] 2.1 Add `_cell_pins` to `TerrainSystem` with `pin_cell(cell, object_id)`, `unpin_cell(cell)`, `get_pin(cell)`, `is_cell_pinned(cell)`; include pins in `export_to_json` / `import_from_json` as `"cell_pins"`
- [x] 2.2 Make height mutations pin-aware: `raise_cell`, `lower_cell`, `flatten_footprint` (and vertex writes used by brushes) skip pinned cells and their shared vertices; cascade still re-slopes unpinned neighbors
- [x] 2.3 Teach `TerrainCatalog.resolve_cell_art` to check the pin first, falling back to derived resolution with a warning on unknown pin ids
- [x] 2.4 Unit tests: pin round-trip; raise/lower/flatten skip pinned cells but re-slope neighbors (property test, odd/even grids); unknown pin falls back with warning; old maps without `cell_pins` load clean

## 3. Undo stack

- [ ] 3.1 Create `scripts/editor/EditorUndoStack.gd`: push/undo/redo with redo-truncation, optional depth cap, and `can_undo`/`can_redo` signals
- [ ] 3.2 Implement `TerrainEditCommand` region snapshots: `{vertices, land, pins}` before/after capture, restore with snapshot invalidation and `cell_changed` re-emits
- [ ] 3.3 Implement entity command (capture `_painted_entities` entry; restore = re-place via EntityPlacer / remove node) and waypoint command
- [ ] 3.4 Wire Ctrl+Z / Ctrl+Y and Edit-menu Undo/Redo items with disabled states from `can_undo`/`can_redo`
- [ ] 3.5 Unit tests: stack semantics (undo, redo, truncation), region-snapshot restore emitting `cell_changed`, stroke coalescing (one command per mouse release), cliff-Accept atomicity, cancel pushes nothing

## 4. Tool protocol and dispatch

- [ ] 4.1 Create the `EditorTool` protocol (activate/deactivate/on_input→consumed/active query) and a registry on `MapEditor`; replace the `_input` elif chain with the single dispatch loop keeping the GUI-hover guard and right-click-as-cancel rule
- [ ] 4.2 Wrap existing tools onto the protocol: EntitySelector, EntityPlacer (entity/tree), ResourcePainter, PlayerStartTool, HeightPainter; remove the `editor._active_tool != 1` magic literal
- [ ] 4.3 Extend the `Tool` enum with named members for all new tools (LAT_PAINT, WAYPOINT, DELETE, FLATTEN, RAISE, LOWER, RAISE_LOWER, CLIFF, FRAMEWORK); update e2e references
- [ ] 4.4 Integration test: no-tool selection still works; each migrated tool activates, consumes input, and deactivates cleanly

## 5. UI regions

- [ ] 5.1 Build the four-region shell: full-rect `UIRoot` in `EditorUI` with left sidebar (~340px), top bar, bottom bar, top-right VBox column; keep world input flowing where no Control is hovered
- [ ] 5.2 Create `EditorMenuBar.gd` (File with New/Load/Save/Map Settings; Edit with Undo/Redo; View with Show Grid/Framework/Preview Pane; Tools listing all tools; Scripting with disabled "Script Console") and remove the Settings menu
- [ ] 5.3 Create `EditorTopBar.gd`: brush size (1×1–5×5), LAT dropdown, tool toggle group, Auto-LAT and Only-paint-on-clear checkboxes, CliffSubBar (Ramp/Cancel/Accept) shown only while the Cliff tool is active
- [ ] 5.4 Create `EditorInfoBox.gd` in the top-right column under the Minimap: hovered cell coords, height, land type, object id; placeholder when outside the diamond
- [ ] 5.5 Re-dock EntityProperties into the top-right column below the info box
- [ ] 5.6 Create `LatBar.gd`: "Search tileset…" filter, LandType-group list with member swatch previews, selection synced with the top-bar LAT dropdown
- [ ] 5.7 Create `EditorPreviewPane.gd` (~80-line SubViewportContainer previewer: camera + pivot, `show_entity`/`show_terrain` via `TerrainCatalog.resolve_art`, AABB framing); wire tree selection to it; View-menu toggle, open by default
- [ ] 5.8 Integration test: layout regions present on open; GUI hover blocks world input; preview pane toggles and reclaims space

## 6. Object browser rework

- [ ] 6.1 Rework `EntityBrowser.gd`: category OptionButton (Aircraft, Buildings, Vehicles, Infantry, TerrainObjects, Overlay, Smudges) sourcing entities by type, catalog terrain objects, and overlay/smudge directories
- [ ] 6.2 Build the faction-collapsible Tree grouping by ownership (`EntityData.owner`; Neutral catch-all), with collapse/expand
- [ ] 6.3 Wire the Owner (house) dropdown (GDI/Nod/Neutral/Special) so newly placed entities record the selected `house_id`; add Ctrl+F search focusing and case-insensitive id/display-name filtering
- [ ] 6.4 Unit tests: category sourcing, faction grouping incl. Neutral catch-all and multi-faction entries appearing under every owned faction, search filtering, owner applied to placements

## 7. Terrain painting tools

- [ ] 7.1 Extend HeightPainter with brush size (square region clipped to the diamond) for height and LAT operations, reusing raise/lower semantics per cell
- [ ] 7.2 Add combined Raise/Lower (left-drag raises, Ctrl+left-drag lowers) and separate Raise/Lower tools; strokes coalesce into one `TerrainEditCommand` on mouse release
- [ ] 7.3 Add the Flatten tool with PICK→PAINT sub-state: first click records the hovered cell's height, drag levels brushed cells to it (all four corners), skipping pinned cells
- [ ] 7.4 Add the LAT brush painting the selected land type via `set_land_type`, honoring Only-paint-on-clear (skip cells with entities/resources/pins) and Auto-LAT v1 plumbing
- [ ] 7.5 Integration tests: brush regions incl. edge clipping; combined tool direction switching; flatten leveling property test; LAT mask rejection (same setup paints with the checkbox off, rejected with it on)

## 8. Cliff tool

- [ ] 8.1 Implement `CliffTool.gd` with IDLE→DRAWING sub-state: drag builds a cell polyline with live preview line; Cancel (button or right-click) discards without pushing a command
- [ ] 8.2 Implement Accept: stamp cliff-family pieces along the path — write baked corner heights, set per-cell land types, pin each cell; skip-and-warn on already-pinned cells; push one atomic `TerrainEditCommand`
- [ ] 8.3 Implement the Ramp toggle: the path's end cell stamps the ramp piece for the end direction using edge connection roles
- [ ] 8.4 Teach Delete mode to unpin brushed cells (restoring derived resolution) alongside its normal deletions
- [ ] 8.5 Integration tests: stamped geometry matches piece corners; pins resolve via catalog; undo reverts the whole path; ramp cap direction; unpin round-trip

## 9. Waypoints

- [ ] 9.1 Implement `WaypointTool.gd`: place on click with first-free-index ≥ 8, reject duplicates with a warning, render markers
- [ ] 9.2 Teach Delete mode to remove waypoints and free their indexes; extend `EditorSaveLoad`/`TerrainSystem.export_to_json` and `MapLoader` for the `"waypoints"` dict
- [ ] 9.3 Unit tests: index assignment skipping 0–7, delete/reuse, JSON round-trip, old maps without `waypoints` load clean

## 10. Framework mode

- [ ] 10.1 Add `framework_mode` to `TerrainRenderer`: flat per-LAT placeholder colors (distinct table incl. cliff/resource) replacing resolved art; re-render on `cell_changed` while active
- [ ] 10.2 Wire the top-bar toggle and View-menu check item; ensure no data mutation and instant repaint of edits while framework view is on
- [ ] 10.3 Integration tests: toggle renders placeholders and restores art; painted LAT changes placeholder color immediately; distinct colors for clear/water/cliff

## 11. Final wiring and gates

- [ ] 11.1 Retire the floating ToolBar and its remnants from `MapEditor._setup_ui`; verify every new control is functional (no dead buttons)
- [ ] 11.2 Update `test_map_editor_e2e.gd` for the new UI tree; run full suite: `redot --headless -s test/run_tests.gd`
- [ ] 11.3 Run `gdlint`, `gdformat --check`, and the post-format tab check (`grep -P '\t' scripts/**/*.gd`); fix findings
- [ ] 11.4 Verify backward compatibility: load a pre-change map JSON in the new editor (no waypoints/pins/house_id) and re-save it
