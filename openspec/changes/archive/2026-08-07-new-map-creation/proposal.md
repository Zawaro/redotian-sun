## Why

Newly created maps let the user pick custom dimensions and visible-bounds insets, but those bounds are never written to the saved `.json`. On reload the visible (blue) play-area bounds fall back to whatever `BoundsSystem` happens to hold (its script defaults or the previously loaded map), so a saved map does not reliably round-trip its own bounds. Persisting the dimensions with the map data closes the last gap in the new-map-creation flow.

## What Changes

- **Four-edge visible bounds model**: replace the symmetric `visible_offset_x/z` (one inset per half-axis) with four independent edge insets — `left_inset`, `right_inset`, `top_inset`, `bottom_inset` (defaults 5/5/4/4). Asymmetric pairs shift the visible diamond off the map center; each edge is independent, so no coupling rules are needed.
- The New Map and Map Settings dialogs expose **Left / Right / Top / Bottom** inset SpinBoxes instead of a single size, each with a dynamic max (`top_max = 2h - bottom - 1`, etc.) so the visible diamond never exceeds the map or becomes empty.
- Bump the map JSON to **format version 4**, adding `map_size` (full grid extent in cells) and `visible_bounds` (`[left, right, top, bottom]` in cells) alongside the existing `grid_cells`.
- `TerrainSystem.export_to_json` writes the two new fields; `map_size` from `grid_cells`, `visible_bounds` from the live `BoundsSystem` insets.
- `MapLoader.load_map_into` restores the visible bounds onto `BoundsSystem` after terrain import. Files without `visible_bounds` (v3 and earlier) fall back to the default insets `(5, 5, 4, 4)`.
- The editor's Save always writes the terrain/dimension data, instead of only writing when at least one entity is placed — a terrain-only map with custom bounds is now saveable.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `map-loader`: JSON format advances to v4 and now persists/restores map dimensions and the four visible-bounds insets, with a v3 fallback for older files.
- `map-editor-dialogs`: New Map / Map Settings dialogs use four per-edge inset SpinBoxes with dynamic maxes and a read-only visible-bounds label.
- `rectangular-grid`: the blue visible-bounds diamond is defined by four per-edge insets in the sum/diff frame.

## Impact

- `scripts/core/TerrainSystem.gd` — `export_to_json` writes v4 dimension fields.
- `scripts/core/BoundsSystem.gd` — four inset exports drive the play mask, blue outline mesh, and camera clamp; adds `apply_saved_bounds()` to restore them from map data (with v3 fallback).
- `scripts/maps/MapLoader.gd` — applies saved bounds to `BoundsSystem` after import.
- `scripts/editor/MapEditor.gd` — both dialogs expose four inset SpinBoxes and apply them.
- `scripts/editor/EditorSaveLoad.gd` — Save no longer gated on the presence of entities.
- Existing v3 `.json` maps (e.g. `assets/test_terrain.json`) continue to load unchanged via the fallback path.
