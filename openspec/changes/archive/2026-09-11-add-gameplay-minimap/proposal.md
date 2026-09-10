## Why

The gameplay HUD has no minimap, so players have no situational awareness beyond the camera viewport and must scroll the map to find units, resources, or threats. The MapEditor already ships a minimap and the fog-of-war data layer (#197/#198) is merged, so the missing piece is a gameplay minimap that consumes the authoritative shroud grid and reuses the existing order system.

## What Changes

- Add a `Minimap` HUD Control to normal gameplay that renders a top-down view of the diamond terrain grid: terrain colors, resource/overlay objects, entities, and the player's fog state.
- Bake terrain colors once at grid initialization from the data-driven terrain color resolvers (`TerrainCatalog.get_cell_art` + `TerrainArtData.minimap_color` + `shade_map_color`); bake entities/overlays and fog at a low fixed frequency.
- Render the camera view rectangle on the minimap.
- Left-click on the minimap issues the same commands as a click in the gameplay area when units are selected; with no valid order (e.g. empty selection) it snap-pans the camera to the clicked cell. Right-click behavior is unchanged. Entities cannot be selected from the minimap, and build/placing modes do not apply to minimap clicks.
- Introduce input ownership for the minimap so world handlers (`MouseHandler`, `BuildingManager`, `EntityPlacer`) do not also process minimap clicks.
- **BREAKING** (HUD layout): move the credit counter out of `Sidebar.tscn` and pin it at the top of the right-hand column; place the 200×200 minimap below it and shift the Sidebar down. The credit label no longer lives inside `Sidebar.tscn`.

## Capabilities

### New Capabilities
- `gameplay-minimap`: the in-game minimap surface — terrain/overlay/fog baking, view-rectangle indicator, click-to-command and click-to-pan navigation, and minimap input ownership.

### Modified Capabilities
- `credit-ui`: the credit display label is relocated from `Sidebar.tscn` to the top of the right-hand HUD column, above the minimap. Animation, tick sounds, and insufficient-funds feedback are unchanged.

## Impact

- **New**: `scripts/ui/Minimap.gd`, `scenes/ui/Minimap.tscn`, `test/unit/test_minimap.gd`.
- **Scenes**: `scenes/maps/MapBase01.tscn` (add minimap + credits), `scenes/ui/Sidebar.tscn` (remove credits, shift down).
- **Scripts**: `scripts/core/UIUtil.gd` (mouse-over-minimap query), `scripts/hud/MouseHandler.gd`, `scripts/buildings/BuildingManager.gd`, `scripts/entities/EntityPlacer.gd` (input guards).
- **Consumed, not modified**: `ShroudSystem` (fog state), `TerrainCatalog`/`TerrainArtData` (cell colors), `TerrainSystem` (cell data), `BoundsSystem` (snap-pan), `OrderSystem`/`SelectionManager` (orders), `ArtData` (entity colors).
- **Data**: no new resources; reuses the terrain/entity color resolvers introduced by #178.
