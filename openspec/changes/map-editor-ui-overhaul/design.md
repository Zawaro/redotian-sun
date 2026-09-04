## Context

The map editor (`scripts/editor/MapEditor.gd`, 765 lines) builds its UI inline: a floating `ToolBar` HBox, an `EntityBrowser` PanelContainer, a fixed-position Minimap, and a floating `EntityProperties`. Tool dispatch is an elif chain on `_active_tool` (`MapEditor._input`), and HeightPainter self-gates on the magic literal `editor._active_tool != 1`.

Terrain truth is a vertex heightfield (`TerrainSystem._vertex_grid`, `HEIGHT_STEP = 0.815`, `MAX_HEIGHT = 10`) plus a sparse `_land_types` overlay. Slope tiles are *derived* from corner heights (`slope_object_id` lookup); there is no placed-tile storage. `TerrainObject` resources are multi-cell authored tiles (per-cell land, baked corners, crease, cliff/ramp connection roles) used for catalog lookup and previews. The editor's mutating state: vertices, land types, `_painted_entities` (plain data dicts + nodes), player starts.

Stakeholders: map authoring for the playable milestone (#363), `TerrainRenderer`/`TerrainCollision` (mesh resolution), `MapLoader`/`EditorSaveLoad` (persistence), `AssetPreviewController` (left untouched), `test_map_editor_e2e` (constructs the UI).

Full exploration record lives in issue #363 (design notes section).

## Goals / Non-Goals

**Goals:**
- Four-region FinalSun-style editor layout with every control functional (no dead buttons).
- All terrain mutations captured by one undo mechanism.
- Cliffs placeable, height-locked, deletable, persisted — via one primitive.
- Uniform tool protocol replacing the elif dispatch.
- Backward-compatible map JSON (new keys optional, `player_id` alias kept).

**Non-Goals:**
- Real TS ground-tile art and `TerrainObject.tileset_id` grouping (deferred until theater overrides ship).
- Transition LAT pieces (Auto-LAT v1 is plumbing only — documented ceiling).
- Scripting console (stub menu item).
- Refactoring `AssetPreviewController` onto a shared preview base.
- Gameplay consumers of waypoints beyond loader exposure (AI/triggers come later).

## Decisions

### D1. Region-snapshot undo, not inverse commands
Height edits cascade across shared vertices (`raise_cell` → `_cascade_from_vertices`), so an inverse command would have to recompute everything the cascade touched. Instead every cell-space mutation is captured as a `TerrainEditCommand`: `{vertices: {vkey: [before, after]}, land: {ckey: [before, after]}, pins: {ckey: [before, after]}}`; restore writes "before" back, invalidates height snapshots, re-emits `cell_changed`. Brush strokes coalesce — accumulate per-frame diffs, push on mouse release. Entity place/delete and waypoint place/delete get their own small command classes.
- **Alternatives**: inverse-operation commands (fragile under cascade); full-map snapshots per command (memory-heavy, 512×512 grids).
- **Why**: cost proportional to touched region; cascade side effects are captured, not recomputed.

### D2. `_cell_pins` — one primitive for cliff stamp/lock/delete
`TerrainSystem` gains `_cell_pins: {cell_key -> object_id}`, written by the Cliff tool's Accept, persisted as `"cell_pins"` in map JSON. `resolve_cell_art` checks pins before height-derived resolution. Height tools skip pinned cells and their shared vertices (cascade still re-slopes unpinned neighbors). Delete mode unpins — the cell returns to derived resolution.
- **Alternatives**: storing placed TerrainObject instances per cell (new storage layer, duplicates the heightfield); deriving cliffs purely from heights (loses connection roles, can't lock editing).
- **Why**: stamp, lock, delete, and persistence all hang off one dict; no new storage layer.

### D3. Bottom bar v1 = LandType groups, not tile objects
Our ground variation *is* the per-cell `LandType`; the catalog holds no ground tiles (only cliff/slope/ramp/clear families). The bar lists LandType `group` values with member swatches; selecting a member drives the LAT brush. `TerrainObject.tileset_id` is deferred until real ground art arrives.
- **Alternatives**: `tileset_id` on TerrainObject now (wrong seam for v1 — requires authoring 144-file migrations for zero visual gain).
- **Why**: deletes a data migration and a stamping backend from scope; the bar still matches the FinalSun workflow (search → pick → paint).

### D4. Tool protocol — informal interface, single dispatch
`EditorTool`: `activate()`, `deactivate()`, `on_input(event) -> bool`, active-state query. `MapEditor._input` loops over registered tools and stops at the first consumer; GUI-hover guard stays. Sub-states (Cliff `IDLE→DRAWING`, Flatten `PICK→PAINT`) live inside tools. Existing tools (Placer, Selector, ResourcePainter, PlayerStartTool, HeightPainter) get wrapped mechanically.
- **Alternatives**: GDScript "interface" base class with virtuals (fine too — the protocol can be a base class); keeping the elif chain and adding 5 more branches.
- **Why**: kills the double-gating (dispatch elif + per-tool `_input` guard) and the magic `!= 1` literal before tool count doubles.

### D5. Standalone `EditorPreviewPane`, AssetPreviewController untouched
New ~80-line SubViewportContainer previewer: camera + pivot, `show_entity(data)` / `show_terrain(obj)` via `TerrainCatalog.resolve_art`, framed to AABB. BatchLoader prewarm already caches all entity models.
- **Alternatives**: re-hosting AssetPreviewController (858 lines: own cameras/HUD/inputs/theater path) into the sidebar.
- **Why**: duplication of 80 lines is cheaper than refactoring a working, tested dev tool; revisit if previews need vector/collision states.

### D6. Four-region Control layout, script-built
All UI stays script-built under the existing `EditorUI` CanvasLayer (repo convention — no new .tscn UI scenes). `MapEditor._setup_ui()` decomposes into `EditorMenuBar`, `EditorTopBar`, `LatBar`, `EditorInfoBox`, `EditorPreviewPane`, plus the reworked `EntityBrowser`. Regions: left sidebar (full height), top bar, bottom bar, top-right VBox column (minimap, info box, EntityProperties).
- **Alternatives**: building `EditorUI.tscn` in the editor (breaks the script-built convention shared by all 24 autoloads + editor panels).
- **Why**: matches existing patterns; keeps scene diffs to zero; test_map_editor_e2e keeps constructing the editor programmatically.

### D7. Houses as a fixed enum, `house_id` with `player_id` alias
Owner dropdown = house (GDI/Nod/Neutral/Special), stored on placed entities as `house_id` in save JSON. `player_id` stays written for backward compatibility (legacy alias, synced on save). No PlayerManager changes — `MapConfig.PlayerConfig.faction_id` already models faction assignment at load.
- **Alternatives**: free-form house list per map (TS singleplayer allows custom houses — not needed for MP-style maps we author); player-slot dropdown (conflates slots with factions).
- **Why**: ModEnc semantics — houses are factions, player slots are waypoints 0–7 assigned at game setup.

### D8. Waypoints ≥ 8 in map JSON, 0–7 stay start_locations
`"waypoints": {"8": [x, z]}`; the Waypoint tool auto-assigns the first free index ≥ 8; Delete removes and frees the index. `start_locations` remains the 0–7 path — no migration.
- **Alternatives**: unify starts and waypoints into one dict (breaking change to existing maps + PlayerStartTool for no authoring benefit).
- **Why**: additive, matches TS semantics (0–7 = starting points), keeps PlayerStartTool intact.

### D9. Framework mode as a TerrainRenderer render state
A `framework_mode` flag on `TerrainRenderer`: when on, cells render flat placeholder quads colored by land type (per-LAT color table, distinct incl. cliff/resource); when off, `resolve_cell_art` output renders as today. No data mutation; edits repaint immediately via existing `cell_changed`.
- **Alternatives**: swapping to a placeholder theater in `TerrainCatalog` (conflates look-tag theater with an editor view mode).
- **Why**: render-only concern belongs in the renderer; theater stays a data concept.

## Risks / Trade-offs

- [Cascade + pin interaction: re-sloping around cliffs could fight the lock] → Pin skip is vertex-granular (pinned cells' shared vertices never move); property tests cover raise-around-cliff invariants.
- [Undo memory on long sessions of big strokes] → Region snapshots are proportional to touched cells; a 5×5 brush stroke over 100 steps is bounded by the union region, not the step count. Cap stack depth (e.g. 100 commands) if profiling ever flags it.
- [GUI-guard regressions: new panels swallowing world input or leaking through] → Single dispatch loop keeps one hover guard; e2e test asserts world picking works with cursor over sidebar.
- [Preview pane per-frame cost] → SubViewport renders only when visible and selection changes; BatchLoader cache makes model loads free.
- [Magic-number tool ids linger in tests] → Tool enum gets named members; e2e updated in the same change.
- [LandType `group` authors drift (missing groups)] → Bar hides empty groups; new `.tres` set in the same commit includes groups.

## Migration Plan

1. Ship data first (LandType `group` + 5 new `.tres`) — additive, no behavior change.
2. Introduce `_cell_pins` + `resolve_cell_art` pin check — inert until the Cliff tool writes pins.
3. Add undo stack + tool protocol, migrating existing tools one by one (each step keeps e2e green).
4. Swap UI regions over (sidebar/top/bottom/right), retire the floating toolbar.
5. Waypoint tool + JSON keys last — purely additive.
Rollback: revert the branch; map JSON stays loadable by older builds (new keys ignored).

## Open Questions

- Exact per-LAT framework color palette (picked during implementation; must be visually distinct per spec).
- Undo stack depth cap value (default unlimited; revisit after profiling).
