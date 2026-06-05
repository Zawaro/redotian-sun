## Why

The game currently uses a flat ground plane with no terrain variation. To create authentic Tiberian Sun gameplay, we need a tile-based terrain system with elevation changes (slopes and clear cells) that affect unit movement and visuals. This is foundational for all subsequent terrain features (cliffs, water, roads) and enables the map editor for level design.

## What Changes

- **New TerrainSystem autoload singleton** managing tile-based terrain data, rendering, and collision
- **TerrainData module** storing per-cell height, type, and variant with JSON import/export
- **TerrainRenderer module** instancing meshes from the existing `placeholder_terrain01.glb` (79 terrain tiles including clear, slope, cliff variants)
- **TerrainCollision module** creating physics bodies using mesh faces as collision shapes
- **MapEditor scene** with isometric camera view, SubViewport minimap, grid overlay, and height painting via drag interaction
- **Pathfinder integration** querying terrain height for movement cost calculations
- **MovementController integration** interpolating unit Y-position along slope cells
- **TestMap02 scene** loading terrain from JSON files

## Capabilities

### New Capabilities

- `terrain-data`: Core terrain data model - cell storage, height calculations, JSON serialization, query API
- `terrain-rendering`: Visual terrain system - mesh instancing from GLB, material application, dynamic updates
- `terrain-collision`: Physics integration - StaticBody3D per cell, mesh-based collision shapes
- `map-editor`: Level design tool - isometric viewport, grid overlay, height painting, minimap, save/load
- `terrain-movement`: Unit-terrain interaction - Y-interpolation on slopes, height-based movement costs

### Modified Capabilities

- `unit-movement`: MovementController gains Y-position interpolation and terrain height queries

## Impact

- **New files**: `scripts/core/TerrainSystem.gd`, `scripts/core/TerrainData.gd`, `scripts/core/TerrainRenderer.gd`, `scripts/core/TerrainCollision.gd`, `scripts/editor/MapEditor.gd`, `scripts/editor/GridOverlay.gd`, `scripts/editor/HeightPainter.gd`, `scripts/editor/Minimap.gd`, `scenes/editor/MapEditor.tscn`, `scenes/maps/TestMap02.tscn`
- **Modified files**: `scripts/core/Pathfinder.gd` (height query integration), `scripts/components/MovementController.gd` (Y-interpolation), `project.godot` (TerrainSystem autoload registration)
- **New assets**: Terrain textures copied from Blender source, terrain model copied from Godot source (renamed)
- **Dependencies**: Existing `placeholder_terrain01.glb` mesh library (79 tiles), existing A* pathfinding system
