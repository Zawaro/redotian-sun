## REMOVED Requirements

### Requirement: Standalone asset preview scene
**Reason**: Superseded by the `asset-browser` capability. The standalone scene is reworked as `scenes/AssetBrowser.tscn` and no longer reuses `Camera01`/`CameraController` (the cause of the broken black/empty view, #409).
**Migration**: Use `scenes/AssetBrowser.tscn`; lighting/environment still come from `DefaultSunLight01.tscn` and `DefaultWorldEnvironment01.tscn`, but the camera is preview-owned.

### Requirement: Asset browsing from theater registry
**Reason**: Superseded by `asset-browser`. Browsing is generalized from terrain-only theater-registered `TerrainObject`s to all visual and audio categories of the active game.
**Migration**: The `TerrainObject` category in the asset browser lists the same tiles, now keyed off `GameContext`/`TerrainCatalog` rather than a hardcoded `temperate` theater.

### Requirement: Camera modes
**Reason**: Superseded by `asset-browser`. The gameplay camera and free-orbit rig are replaced by a preview-owned camera with zoom, free rotate, auto rotate, and 90-degree steps; gameplay panning and map-bounds clamping are removed.
**Migration**: Use the asset browser's camera controls; there is no isometric-gameplay camera mode.

### Requirement: Stackable render-state toggles
**Reason**: Superseded by `asset-browser`. Generalized stackable overlays (mesh, footprint, collision, theater, ground, axis) replace the terrain-only render-state toggles.
**Migration**: Use the asset browser's overlay checkboxes and `asset_browser_cycle_overlay`.

### Requirement: Info box with cell linkage
**Reason**: Superseded by `asset-browser`. Asset-level info plus a per-cell list (terrain assets) with click-to-highlight replaces the old terrain-only info box.
**Migration**: Use the asset browser info panel and cell list.

### Requirement: Placement and orientation
**Reason**: Superseded by `asset-browser`. Grounding (lowest point at world origin), bounds-center rotation, and base art yaw fold replace the old placement/direction-cycle contract; directional variants are distinct asset ids.
**Migration**: Select each directional variant as its own asset; grounding and rotation follow the `asset-browser` requirements.

### Requirement: Preview input actions
**Reason**: Superseded by `asset-browser`. The `asset_preview_*` InputMap actions are replaced by `asset_browser_*` actions matching the new controls.
**Migration**: Update bindings and HUD buttons to the `asset_browser_*` actions.

### Requirement: Preview data contracts are tested
**Reason**: Superseded by `asset-browser`. The data-layer and scene-layer test contracts are restated for the browser (category registry, layering, preview modes, camera controls).
**Migration**: Use the `asset-browser` tests; the terrain art/GLB submesh contracts remain covered by their own capability tests.
