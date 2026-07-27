## Why

Newly created maps let the user pick custom dimensions and visible-bounds insets, but those bounds are never written to the saved `.json`. On reload the visible (blue) play-area bounds fall back to whatever `BoundsSystem` happens to hold (its script defaults or the previously loaded map), so a saved map does not reliably round-trip its own bounds. Persisting the dimensions with the map data closes the last gap in the new-map-creation flow.

## What Changes

- Bump the map JSON to **format version 4**, adding `map_size` (full grid extent in cells) and `visible_bounds_size` (full visible play-area extent in cells) alongside the existing `grid_cells`.
- `TerrainSystem.export_to_json` writes the two new fields; `map_size` from `grid_cells`, `visible_bounds_size` derived from the live `BoundsSystem` visible-bounds insets.
- `MapLoader.load_map_into` restores the visible bounds onto `BoundsSystem` after terrain import, converting `visible_bounds_size` back into insets. Files without the field (v3 and earlier) fall back to the standard default insets.
- The editor's Save always writes the terrain/dimension data, instead of only writing when at least one entity is placed — a terrain-only map with custom bounds is now saveable.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `map-loader`: JSON format advances to v4 and now persists/restores map dimensions and visible bounds, with a v3 fallback for older files.

## Impact

- `scripts/core/TerrainSystem.gd` — `export_to_json` writes v4 dimension fields.
- `scripts/core/BoundsSystem.gd` — adds `apply_saved_bounds()` to restore visible-bounds insets from map data (with v3 fallback).
- `scripts/maps/MapLoader.gd` — applies saved bounds to `BoundsSystem` after import.
- `scripts/editor/EditorSaveLoad.gd` — Save no longer gated on the presence of entities.
- Existing v3 `.json` maps (e.g. `assets/test_terrain.json`) continue to load unchanged via the fallback path.
