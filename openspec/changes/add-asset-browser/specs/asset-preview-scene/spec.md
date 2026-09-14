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
**Reason**: Terrain-specific inspection (vector footprint, collision AABB, theater context overlay, resolved-submesh state) is out of scope for the generalized visual/audio asset browser.
**Migration**: Not carried over. Re-introduce under a future terrain-inspection change if the detail is still needed.

### Requirement: Info box with cell linkage
**Reason**: Terrain-cell-specific inspection is out of scope for the generalized asset browser.
**Migration**: Not carried over; the browser shows asset-level information instead.

### Requirement: Placement and orientation
**Reason**: Terrain-specific footprint grounding and direction cycling are out of scope for the generalized asset browser.
**Migration**: Not carried over.

### Requirement: Preview input actions
**Reason**: Superseded by `asset-browser`. The `asset_preview_*` InputMap actions are replaced by `asset_browser_*` actions matching the new controls.
**Migration**: Update bindings and HUD buttons to the `asset_browser_*` actions.

### Requirement: Preview data contracts are tested
**Reason**: Superseded by `asset-browser`. The data-layer and scene-layer test contracts are restated for the browser (category registry, layering, preview modes, camera controls).
**Migration**: Use the `asset-browser` tests; the terrain art/GLB submesh contracts remain covered by their own capability tests.
