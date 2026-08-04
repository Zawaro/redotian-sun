## Why

The terrain theater/art seam is data-only and fat: `TheaterData` embeds 144 `TerrainObject`s plus one per-theater `TerrainArtData` with a global fallback table, while the renderer/collision still hardcode `_get_mesh_name` — nothing consumes the seam at runtime. Theater swap (#206), theater-aware art (#210), and dynamic loading can't build on it. Ownership must invert to mirror the entity data/art system: one art `.tres` per element, a light theater tag, and a global catalog registry.

## What Changes

- **BREAKING** `TheaterData` slims to `id`, `display_name` (no land-type field; the game-wide default stays in `TerrainSystem.DEFAULT_LAND_TYPE`). Removes `terrain_objects`, `art_data`, `default_land_type`, and `get_terrain_object()`.
- **BREAKING** `TerrainArtData` becomes one-per-element: `id`, `model_path`, `submesh_id`, `theater_overrides: {theater_id -> glb_path}`. Owns `resolve(object_id, theater_id)` returning glb/submesh/rotation. Removes `mesh_name()`, `base_mesh_id()`, and the global `FALLBACK_MESHES` table.
- `TerrainObject` gains an `art_data` reference (shared across objects, mirrors `EntityData.art_data`).
- New `TerrainCatalog` autoload scans `resources/terrain_objects/`, `resources/art/terrain/`, and `resources/theaters/`; caches by id; owns the active theater; exposes `resolve_art(object_id, theater_id)`. Missing art renders a pink placeholder mesh with a warning.
- **Map JSON `theater_id` becomes the authority**: `MapLoader` ingests it and calls `TerrainCatalog.set_active_theater(id)`. `GlobalRules` gains no theater machinery.
- `TerrainRenderer`/`TerrainCollision` resolve meshes through `TerrainCatalog` instead of hardcoded type/variant mapping.
- `AssetPreviewController` re-points to the new seam.
- isotem CI verifier removed; `tools/isotem/` stays as documented manual tooling (soft reference, never a verifier).
- Data migration: 144 `TerrainObject` `.tres` get `art_data` refs; ~16 per-element art `.tres` authored; `temperate.tres` slimmed; `placeholder_terrain_art.tres` deleted.

## Capabilities

### New Capabilities
- `terrain-catalog`: global `TerrainCatalog` autoload — directory-scan registries for TerrainObjects, per-element TerrainArtData, and light TheaterData; active-theater selection driven by the map JSON; `resolve_art` mesh resolution with pink fallback for missing art.

### Modified Capabilities
- `terrain-object-catalog`: `TerrainObject` gains an `art_data` reference; the suffix-aware art seam requirement is replaced by per-element `TerrainArtData.resolve()`; the theater-registration requirement changes so the theater is a light tag and the catalog is a global scanned registry.

## Impact

- **Scripts**: `scripts/data/TerrainArtData.gd`, `TheaterData.gd`, `TerrainObject.gd`; new `scripts/core/TerrainCatalog.gd` + autoload registration in `project.godot`; `scripts/core/TerrainRenderer.gd`, `TerrainCollision.gd`; `scripts/maps/MapLoader.gd`; `scripts/editor/AssetPreviewController.gd`.
- **Resources**: 144 `resources/terrain_objects/*.tres` (migration), ~16 new `resources/art/terrain/*.tres`, `resources/theaters/temperate.tres`, delete `resources/art/terrain/placeholder_terrain_art.tres`.
- **Tests**: rewrite `test_terrain_art_data.gd`, `test_theater_data.gd`; update `test_terrain_object_catalog.gd`, `test_asset_preview_scene.gd`, `test_asset_preview_data.gd`; new `test_terrain_catalog.gd`, `test_integration/test_theater_selection.gd`.
- **CI**: remove isotem variant-count check from `.github/workflows/test.yml`.
- **Specs**: `openspec/specs/terrain-object-catalog/spec.md`.
