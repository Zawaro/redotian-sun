# map-editor-entity-placement

Add entity placement with player assignment to the MapEditor. Enables placing buildings, infantry, and vehicles on the map with owner assignment, needed to set up starting conditions for matches.

## Key Decisions

- **Always-visible EntityBrowser** — left sidebar panel, always shown when MapEditor loads (no toggle button), follows WAE/OpenRA pattern
- **Click-to-toggle placement** — clicking an entity in the browser toggles placement mode for that entity; right-click cancels
- **Category tabs** — Buildings, Infantry, Vehicles, Aircraft, Naval; all tabs active, populated from EntityFactory.get_all_by_type()
- **Owner dropdown at top of entity browser** — matches WAE pattern, prominent placement, default Player 0
- **Searchable entity list** — real-time filtering by name or ID
- **Preview ghost** — 50% opacity entity follows cursor before placement, positioned with foundation-aware offset
- **Foundation-aware positioning** — buildings use `_cell_origin_world_pos()` to account for multi-cell footprints
- **Reuse `_painted_entities` dict** — extend with `player_id` field, same save/load pattern as resources/trees
- **Save/load includes `player_id`** — backward compatible, defaults to 0 if missing
- **Sub-script architecture** — MapEditor split into EditorGrid, EntityPlacer, ResourcePainter, EditorSaveLoad for maintainability
- **ResourceGrowthSystem guard** — growth/spread system disabled in MapEditor scene to prevent resource spread during editing
