## 1. Rename and scaffold

- [x] 1.1 `git mv scenes/AssetPreview.tscn scenes/AssetBrowser.tscn`
- [x] 1.2 `git mv scripts/editor/AssetPreviewController.gd scripts/editor/AssetBrowserController.gd` (and its `.uid`)
- [x] 1.3 Update the scene's script reference and root node name to `AssetBrowser`
- [x] 1.4 Rename InputMap actions in `project.godot`: `asset_preview_next/prev/dir_cycle/cam_toggle/spin/state_cycle` -> `asset_browser_*` (drop unused ones)
- [x] 1.5 Remove the `Camera01` instance and `OrbitRig` from `AssetBrowser.tscn`

## 2. Preview-owned camera (fixes #409)

- [x] 2.1 Add a preview-owned `Camera3D` to `AssetBrowser.tscn` at a fixed 3/4 framing
- [x] 2.2 Implement wheel zoom with clamped min/max
- [x] 2.3 Implement free rotation (left-drag turns the asset; yaw-only in isometric, yaw+pitch in perspective)
- [x] 2.4 Implement auto-rotate toggle (continuous asset yaw)
- [x] 2.5 Implement 90-degree yaw step buttons
- [x] 2.6 Implement auto-frame on asset selection from the instantiated mesh AABB
- [x] 2.7 Verify the camera transform is unchanged across idle frames and that `BoundsSystem` does not recenter/clamp it

## 3. Game selection

- [x] 3.1 Add a Game `OptionButton` populated from `GameContext.list_games()`, preselecting the active game
- [x] 3.2 On selection call `GameContext.select_game(id)` (no `save_game_choice`)
- [x] 3.3 Connect `GameContext.game_changed` and rebuild categories/assets/preview
- [x] 3.4 Show an explicit empty state when no game is active

## 4. Category registry and asset scanning

- [x] 4.1 Define the category registry (label, dir, optional `entity_type` filter, preview mode) for terrain objects, buildings, infantry, vehicles, aircraft, terrain props, overlays, smudges, `ArtData`, `TerrainArtData`, SFX, voices, cameo/UI textures
- [x] 4.2 Add a Category `OptionButton` built from the registry, skipping categories with no source directory
- [x] 4.3 Implement a directory scanner over `GameContext.current.data_sets` in order with later-root override
- [x] 4.4 Implement the asset `OptionButton`/list from scanned basenames (load-on-select only)
- [x] 4.5 Add a free-text filter input that narrows the asset list
- [x] 4.6 Filter entity categories by `EntityData.entity_type`

## 5. Mode-adaptive preview

- [x] 5.1 3D mode: resolve via `EntityData.art_data.model_path` -> `ArtData.model_path` -> `TerrainCatalog.resolve_art()` -> procedural `placeholder_size` box -> empty state
- [x] 5.2 Instantiate resolved GLBs directly (no `ArtComponent`/`UnitMeshRenderer`)
- [x] 5.3 Audio mode: play/stop the selected `AudioData`/`VoiceData` stream
- [x] 5.4 Image mode: display cameo/UI textures
- [x] 5.5 Emit a warning and show an explicit message when a 3D asset resolves to nothing

## 6. UI polish

- [x] 6.1 Lay out the selector row (Game | Category | Filter | Asset) and the mode-adaptive preview pane
- [x] 6.2 Keep/adjust the info panel to show asset-level fields for the selected resource
- [x] 6.3 Ensure HUD buttons and keyboard actions stay in sync

## 7. Tests

- [x] 7.1 Unit: category registry resolves >=1 asset per in-scope category for `ts`
- [x] 7.2 Unit: scanner honors `data_set` root ordering (later overrides earlier)
- [x] 7.3 Rewrite `test/integration/test_asset_preview_scene.gd` -> browser integration (selectors populate, every category's first asset loads, filter works, `game_changed` rebuild)
- [x] 7.4 Rewrite/replace `test/unit/test_asset_preview_data.gd` for the registry/modes
- [x] 7.5 Regression: camera transform is stable across idle frames; zoom clamps; 90-degree step is exact
- [x] 7.6 `gdlint` + `gdformat --check` + `redot --headless -s test/run_tests.gd` green

## 8. Specs and docs

- [x] 8.1 Confirm `asset-browser` spec delta validates (`openspec validate add-asset-browser --strict`)
- [ ] 8.2 Delete the superseded `openspec/specs/asset-preview-scene/` directory at archive time
- [x] 8.3 Propose a GLOSSARY entry for "asset browser" if it proves durable

## 9. Camera modes, asset rotation, and render overlays

- [x] 9.1 Replace the orbiting camera with a static framing camera at the gameplay isometric vantage (45 deg yaw, 30 deg pitch)
- [x] 9.2 Add Isometric (orthographic) / Perspective projection toggle via `asset_browser_camera_mode` (C) and a HUD button
- [x] 9.3 Rotate the asset about its bounds center instead of the camera; ground its lowest point at the world origin
- [x] 9.4 Isometric rotation is yaw-only; perspective adds clamped pitch (no roll)
- [x] 9.5 Add stackable overlays: mesh, footprint grid + corner-height markers, collision AABB, theater label, ground grid, axis lines, via HUD checkboxes and `asset_browser_cycle_overlay` (F)
- [x] 9.6 Split overlays by frame: object overlays under `ObjectRoot`, ground/axis under a world-fixed `WorldOverlays` node
- [x] 9.7 Add the per-cell terrain list with click-to-highlight (highlight attached to the asset)
- [x] 9.8 Tests: projection modes, asset-rotation/camera-fixed, per-mode pitch, zoom clamps in both modes, overlay visibility, world-fixed ground/axis, cell highlight, footprint/corner geometry
- [x] 9.9 Sync spec/design/proposal; re-run `gdlint` + `gdformat --check` + full headless suite
- [x] 9.10 Suppress the gameplay fog/shroud plane in the standalone browser (`FogRenderer.set_overlay_enabled`), restoring it on exit
