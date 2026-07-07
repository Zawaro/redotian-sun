## Why

Base building is a core RTS mechanic that doesn't exist yet. Players need to place structures on the terrain, and those structures must block unit pathfinding. Without this, the game has no economy, no production, and no strategic depth. This is the foundation for all Phase 1 systems (economy, production, power).

## What Changes

- **New**: BuildingManager autoload singleton — manages build mode, placement validation, building registration
- **New**: BuildingType resource class — defines footprint, cameo, scene path per building type
- **New**: PlacementPreview — translucent ghost mesh that follows cursor, snaps to grid, shows valid/invalid placement
- **New**: BuildMenu UI — right-side panel with building buttons to enter/exit build mode
- **Modified**: SpatialHash gains `_building_cells` layer — permanent cell occupancy for buildings, merged into `get_blocked_cells()`
- **Modified**: MouseHandler gains build mode guard — routes input to BuildingManager when in build mode
- **New**: 6 BuildingType resources (GDI faction) — ConYard, Power Plant, Barracks, Refinery, War Factory, Guard Tower
- **New**: 5 placeholder building scenes (cube meshes) — Power Plant, Barracks, Refinery, War Factory, Guard Tower

## Capabilities

### New Capabilities
- `building-placement`: Core placement system — build mode state, ghost preview, grid snapping, placement validation, building instantiation
- `building-cell-blocking`: Permanent cell occupancy for buildings — SpatialHash integration, pathfinding automatically avoids placed buildings
- `build-menu-ui`: Right-side build panel — building buttons with cameos, enter/exit build mode

### Modified Capabilities
<!-- None — this is all new functionality -->

## Impact

- **SpatialHash.gd**: Add `_building_cells` dictionary, `register_building_cells()`, `unregister_building_cells()`, modify `get_blocked_cells()` to merge layers
- **MouseHandler.gd**: Add guard at top of `_process()` for build mode
- **MainScene.tscn**: Add BuildMenu and PlacementPreview nodes
- **project.godot**: Register BuildingManager as autoload
- **Scenes**: New `scenes/ui/BuildMenu.tscn`, new placeholder building scenes under `scenes/entities/structures/gdi/`
- **Resources**: New `resources/buildings/*.tres` for each building type
- **Pathfinder.gd / MovementController.gd**: Zero changes — buildings block via existing `get_blocked_cells()` API
