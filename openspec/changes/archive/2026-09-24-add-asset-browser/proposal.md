## Why

The standalone terrain preview (`scenes/AssetPreview.tscn`, #213) is both broken and too narrow. It reuses the gameplay `Camera01`/`CameraController`, whose `_process` pans (WASD + edge-scroll) and clamps to a phantom map diamond, dragging the camera off the asset at the origin — the "black/empty 3D view" (#409). It also hardcodes the TS `temperate` theater and only lists `TerrainObject`s. As the project moves to multiple games and content packs, developers need one game-aware browser for every visual and audio asset, launched the same way (Redot Run Scene / F6 / `--scene`).

## What Changes

- **Rework the standalone scene into a game-aware asset browser** — replaces the terrain-only `AssetPreview` with `scenes/AssetBrowser.tscn` + `AssetBrowserController.gd` (and `asset_preview_*` input actions become `asset_browser_*`). **BREAKING**: old scene/script/action names and the `get_mesh_node`/`select_family` terrain-only API are removed or renamed.
- **Preview-owned camera** — a `Camera3D` owned by the browser, fixed at the gameplay isometric vantage (45° yaw, 30° pitch down), with Isometric (orthographic) and Perspective projection modes and clamped zoom. It never orbits and never pans; it auto-frames the asset on selection. Fixes the black/empty view.
- **Asset rotation** — drag, auto-rotate, and 90° steps turn the asset about its bounds center instead of the camera, so the light and environment stay fixed. Isometric is yaw-only; perspective adds clamped pitch. The asset is grounded at the world origin.
- **Render overlays** — stackable toggles (mesh, footprint grid + corner-height markers, collision box, theater label, ground grid, axis lines) plus a per-cell list with click-to-highlight for terrain assets. Gameplay world overlays (the fog-of-war/shroud plane) are suppressed while the browser is open.
- **Game selector** — from `GameContext.list_games()`; picking calls `GameContext.select_game(id)` ephemerally (never persists the choice). The browser rebuilds on `GameContext.game_changed`, after the content autoloads reload.
- **Data-driven category registry** — every category is one registry row (label, source dir under each `data_set` root, optional filter, preview mode). In scope: terrain objects, buildings, infantry, vehicles, aircraft, terrain props, overlays, smudges, `ArtData`, `TerrainArtData`, SFX, voices, and cameo/UI textures.
- **Filter input + lazy load-on-select** — list asset filenames on game/category change; `load()` only the selected resource; free-text filter over the list; later `data_set` roots win (mirrors the `game-content` layering).
- **Mode-adaptive preview pane** — 3D view (GLB or procedural placeholder box), audio transport, or image view, chosen by the category.
- **Visible diagnostics** — a failed art/model resolution shows an explicit empty state and warning instead of silently rendering nothing.

Out of scope (follow-up #410): non-visual data categories (weapons, warheads, projectiles, armor/land/locomotor/resource types, factions, theaters, global rules) as a read-only property inspector. Game-neutral terrain placeholder path stays with #398.

## Capabilities

### New Capabilities
- `asset-browser`: standalone, game-aware browser for a game's visual and audio assets — game/category/asset selection with filtering, lazy asset loading, mode-adaptive preview, a preview-owned camera with isometric/perspective projections and clamped zoom, asset rotation (yaw-only in isometric, yaw+pitch in perspective), and stackable render overlays.

### Modified Capabilities
- `asset-preview-scene`: superseded by `asset-browser` — all requirements removed and migrated (terrain-only registry browsing, `Camera01`/`CameraController` reuse, camera modes).

## Impact

- **Scenes**: `scenes/AssetPreview.tscn` → `scenes/AssetBrowser.tscn` (reworked; not referenced by `MainScene`, so no gameplay impact).
- **Scripts**: `scripts/editor/AssetPreviewController.gd` → `AssetBrowserController.gd`; new category-registry and preview-pane code (3D/audio/image modes); `scripts/editor/OrbitCameraController.gd` folded into or retired by the new camera.
- **Project settings**: `asset_preview_*` InputMap actions → `asset_browser_*` in `project.godot`.
- **Autoloads consumed (unchanged)**: `GameContext` (game list/selection), `TerrainCatalog` (terrain objects/art, theaters), `EntityFactory` (entities), `AudioManager`/data dirs (audio).
- **Tests**: rewrite `test/integration/test_asset_preview_scene.gd` and `test/unit/test_asset_preview_data.gd` for the browser; add registry/layering/zoom-rotate/camera-stability tests.
- **Spec**: new `openspec/specs/asset-browser/`; remove `openspec/specs/asset-preview-scene/`.

## Related

- GH #409 (asset browser), GH #410 (data-inspector categories follow-up), GH #213 (original asset preview), GH #398 (game-neutral placeholder path).
