## Why

There is no place to inspect the authored assets the game already ships. The #201 terrain-object catalog adds 140 directional `TerrainObject` variants and a theater/art bundle, but they render nowhere outside the cell-grid — developers can't see a tile, verify its art mapping, or validate its baked geometry without editing a map. An asset preview scene gives a single, headless-loadable place to review every asset as it exists in data.

## What Changes

- Add a standalone `scenes/AssetPreview.tscn` scene (run via F6 / `--scene`) that previews terrain elements — the 140 directional `TerrainObject` variants and their art.
- Reuse the existing environment and camera scenes (`DefaultSunLight01`, `DefaultWorldEnvironment01`, `Camera01`/`CameraController`) so preview lighting matches gameplay and the map editor.
- Browse assets from the theater registry (`temperate.tres`), grouped by base family, with a 4-way N/E/S/W direction cycler.
- Add a free-orbit camera mode (drag to orbit the object pivot, wheel to zoom) and an independent auto-turntable toggle, driven by new InputMap actions and on-screen HUD buttons.
- Add stackable render-state toggles per object: vector (footprint wireframe + corner-height markers), collision box (footprint AABB), mesh (GLB submesh via `TerrainArtData`), and theater context overlay.
- Add an info box showing the object's data (id, cell_type, dims, per-cell land/corners/crease/slope/connections, theater/art context) with click-to-highlight cell linkage to the 3D view.
- Add data-layer unit tests (art seam resolves to existing GLB submeshes, rotation table, footprint AABB math) and a scene-load smoke test that cycles all 140 variants headless.

No existing behavior changes. Entity previews, MainMenu entry point, theater switching, and editing/placement are explicitly out of scope this iteration.

## Capabilities

### New Capabilities
- `asset-preview-scene`: a standalone developer-facing scene for browsing and inspecting authored terrain assets (browsing, camera modes, render-state toggles, info box) and the tests that pin its data contracts.

### Modified Capabilities
<!-- None — this change only consumes TerrainObject/TheaterData/TerrainArtData; no existing requirement changes. -->

## Impact

- New scene: `scenes/AssetPreview.tscn` plus its script(s) and HUD controls.
- New scripts: preview controller(s), orbit/turntable camera controller, debug-mesh overlay helpers (reusing `DebugVisualizer`-style primitives).
- Reuses (no change): `scenes/environment/*`, `scenes/hud/Camera01.tscn`, `CameraController.gd`, `TerrainArtData.gd`, `TheaterData.gd`, `TerrainObject.gd`, `resources/theaters/temperate.tres`, `resources/terrain_objects/*.tres`, `assets/models/terrain/placeholder_terrain01.glb`.
- `project.godot`: new InputMap actions (`asset_preview_next/prev/dir_cycle/cam_toggle/spin/state_cycle`).
- New tests: `test/unit/` data-layer coverage + a `test/integration/` scene-load smoke test.
- No changes to the cell-grid `TerrainRenderer`/`TerrainCollision` (the preview instantiates GLB submeshes directly).
