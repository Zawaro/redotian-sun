## Context

`scenes/AssetPreview.tscn` + `scripts/editor/AssetPreviewController.gd` (#213) render one terrain tile for inspection. Two problems:

1. It reuses the gameplay `Camera01`/`CameraController`. That controller's `_process` runs WASD + edge-scroll panning and `BoundsSystem.clamp_to_visible_diamond()` against a phantom 50×50 grid, so it drifts/clamps the camera off the asset at the origin — the black/empty 3D view (#409). Headless runs mask it because the viewport rect is degenerate and border-panning bails.
2. It hardcodes the TS `temperate` theater and lists only `TerrainObject`s.

The browser must become game-aware and cover all visual + audio asset categories, while staying a standalone scene launched with Redot's Run Scene (F6 / `--scene`). `GameContext` already resolves/discover games and emits `game_changed`; `TerrainCatalog`, `EntityFactory`, `AudioManager`, and `FactionCatalog` reload on that signal. Non-visual data categories are deferred to #410.

## Goals / Non-Goals

**Goals:**
- One standalone scene that browses every visual + audio asset category for the selected game.
- A preview-owned camera (fixed isometric vantage, isometric/perspective projection, zoom) with no gameplay panning/clamping; the camera auto-frames the asset and stays fixed while the asset rotates and is stable when idle.
- Game selector that swaps the whole content set live via `GameContext.select_game`, without persisting the choice.
- Data-driven category registry + free-text filter + lazy load-on-select.
- Stackable render overlays (mesh, footprint grid + heights, collision box, theater label, ground grid, axis) over the asset, with per-cell click-to-highlight.
- Explicit empty/error states instead of a silent blank view.

**Non-Goals:**
- Non-visual data categories (weapons/warheads/projectiles/types/factions/theaters/rules) — #410.
- Editing asset values (read-only dev tool).
- Game-neutral terrain placeholder path — #398 (still TS-hardcoded in `TerrainCatalog`).
- In-game/debug-menu entry point; only the standalone scene.

## Decisions

### Preview-owned camera over gameplay camera
Add a `Camera3D` owned by the browser scene; delete the `Camera01` instance and `OrbitCameraController` from it. The camera is a fixed projector at the gameplay isometric vantage (45° yaw, 30° pitch down) and never orbits. It offers two projections: Isometric (orthographic, matching gameplay; zoom scales the ortho `size`) and Perspective (zoom scales the view distance). Auto-frame the asset using its AABB on selection.

- *Alternatives*: keep `Camera01` and `set_process(false)` (still inherits `BoundsSystem` camera-pivot/clamp; keeps a gameplay dependency); keep the orbit rig only (no zoom/step modes). Rejected — the whole bug is gameplay coupling.

### Asset rotates, camera and environment stay fixed
Rotation turns the asset (`ObjectRoot`) around its bounds center, not the camera, so the directional light and world environment are constant — what the old preview's turntable did, applied to all rotation. Isometric mode allows yaw only (upright); perspective allows yaw + clamped pitch (no roll). 90° steps and auto-rotate act on the asset's yaw. The asset is grounded so its lowest point sits at the world origin (ground grid stays meaningful) and its base art rotation folds into the starting yaw.

- *Alternative*: orbit the camera (old "free orbit" mode). Rejected — swinging the camera changes the environment backdrop and shading direction; the user explicitly wants the asset to turn under fixed lighting.

### Stackable render overlays, split by frame of reference
Bring back the old preview's inspection overlays as independent checkboxes (Mesh, Footprint grid + corner-height markers, Collision box, Theater label) plus a world-fixed Ground grid and Axis lines, toggled by HUD and a cycle action, 3D modes only. Object-space overlays are children of `ObjectRoot` (rotate with the asset); ground/axis live under a `WorldOverlays` node (fixed). Footprint uses `TerrainObject.cells` with `TerrainSystem.HEIGHT_STEP`, falling back to `EntityData.foundation`/`ArtData.foundation` cells; collision uses the instantiated mesh AABB so it works for every 3D asset.

- *Alternative*: terrain-only overlays on a separate pane (the old behavior). Rejected — the browser covers entities/art too, and one basis/AABB path covers all of them.

### Standalone scene turns off gameplay overlays
The browser is a standalone dev scene, but autoloads still run: `FogRenderer` drapes its world-space fog/shroud plane over the origin (the grey/black sheet that buried the asset). Give `FogRenderer` a public `set_overlay_enabled(false)` (the same suppression the map editor gets) that returns the previous flag, call it on browser entry, and restore that prior flag on `_exit_tree` so the autoload is left as found. The browser's own preview overlays are unaffected.

- *Alternative*: hide the fog plane nodes directly from the browser. Rejected — reaching into another system's private children is fragile and re-shows on the next shroud signal.

### Data-driven category registry
A single const registry (array of dictionaries or a tiny Resource) of rows: `label`, `dir`, optional `entity_type` filter, `mode` (`MODEL`/`TERRAIN`/`AUDIO`/`IMAGE`). The UI builds its category selector and routes preview modes from the registry; adding a category is one row.

- *Alternatives*: hand-coded per-category panels (duplicated UI logic); a generic "scan every `.tres` by class" (cannot distinguish entity sub-types or choose preview modes). Rejected.

### Directory scan with lazy load-on-select
On game/category change, list asset *paths* by scanning each `GameContext.current.data_sets` root's category directory (recursively where needed, e.g. `entities/structures/<faction>/`), with later roots overriding same-id entries. Show id/filename immediately; `load()` only the selected path.

- *Alternatives*: reuse autoload getters (many expose no "get all"; `EntityFactory` would eagerly load 408 entities); eager-load everything (slow, wasteful for a browser). Rejected.
- Entity categories scan their type subdirectory recursively (faction dirs nest under `entities/structures/`) **and** enforce the registry's `etype` from the resource header, so a mis-filed entity cannot leak into the wrong category. Directory scan alone would be fragile; `etype` alone would force loading every entity.

### Direct 3D instantiation, not `ArtComponent`
For a 3D asset, resolve the model path, `load()` the PackedScene, and instantiate it under the preview root. Ladder: `EntityData.art_data.model_path` → `ArtData.model_path` → `TerrainCatalog.resolve_art()` (terrain) → procedural box from `placeholder_size` → empty state with a warning.

- *Alternative*: reuse `ArtComponent` (brings `UnitMeshRenderer` MultiMesh registration, fog `GhostDepot` reparenting, power/exit wiring, animation players). Rejected as gameplay machinery; a raw GLB instance is what a dev wants to see. Remappable player-color tinting is not applied (see Open Questions).

### Rename to asset-browser and supersede the old capability
Rename `scenes/AssetPreview.tscn` → `scenes/AssetBrowser.tscn`, `AssetPreviewController.gd` → `AssetBrowserController.gd`, and InputMap actions `asset_preview_*` → `asset_browser_*`. No external references (not in `MainScene`), so this is safe. The `asset-preview-scene` spec is superseded by `asset-browser`.

- *Alternative*: keep old names to reduce churn. Rejected — the tool's behavior and name no longer match.

### Use `GameContext.select_game`, ephemeral
Game switching mutates autoload content (intended). Never call `save_game_choice()`. Because the scene is standalone (no gameplay to preserve), no restore-on-exit is needed; reopening the browser re-resolves the persisted/default game.

## Risks / Trade-offs

- **Game switch reloads all content autoloads** → acceptable for a dev tool; the browser re-scans after `game_changed` (autoloads connect first, so their reload runs before the browser reacts).
- **`BoundsSystem` grabs the first `Camera3D` it finds as `camera_pivot`** → with no map loaded it is inert; verify the preview camera is not recentered/clamped on grid init, and guard if it is.
- **Direct GLB instance differs from gameplay rendering** (no MultiMesh batching, no remap tint) → acceptable for inspection; document it. If accurate gameplay look is needed, revisit with an opt-in "gameplay render" mode.
- **Lazy scan may mis-dedupe ids** if filenames and resource ids diverge → dedupe on filename for the list, resolve id on load; later roots win by path order.
- **Removing `asset-preview-scene` leaves an empty capability** → delete `openspec/specs/asset-preview-scene/` as part of the change and note it in the delta.
- **Only one game (`ts`) exists today** → the multi-game path is lightly exercised; rely on `GameContext` test seams / fixture trees from `test_game_content`.
- **Test churn** → old `test_asset_preview_scene.gd` / `test_asset_preview_data.gd` are rewritten; keep the terrain-art GLB contract coverage where it lives.

## Migration Plan

1. Rename scene/script and InputMap actions; update `project.godot`; skeleton `AssetBrowserController` with the preview-owned camera. This alone resolves #409.
2. Add the game selector + `game_changed` rebuild.
3. Add the category registry, lazy scan, filter, and asset selector.
4. Add preview modes (MODEL/TERRAIN/AUDIO/IMAGE) and empty states.
5. Rewrite tests; add registry/layering/zoom-rotate/camera-stability coverage; update specs and delete the superseded spec dir.
6. Rollback: revert the branch; the old preview is recoverable from git history.

## Open Questions

- **Texture category sources** — resolved: scanned as raw image files under `<data_set root>/assets/cameos/` and `assets/ui/`.
- **Player-color remap** — resolved: models preview with raw materials (no tint).
- **Terrain direction cycling** — resolved: dropped; each directional variant is a distinct asset id (e.g. `cliff01_n`).
