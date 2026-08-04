## 1. Input setup

- [x] 1.1 Register InputMap actions `asset_preview_next`, `asset_preview_prev`, `asset_preview_dir_cycle`, `asset_preview_cam_toggle`, `asset_preview_spin`, `asset_preview_state_cycle` in `project.godot`
- [x] 1.2 Confirm the actions are remappable under existing `InputSettings` conventions

## 2. Data helpers

- [x] 2.1 Add a small helper to resolve a variant's mesh: `TerrainArtData.mesh_name(id)` + `mesh_rotation(id)` (already present — verify no gaps for all 140 ids)
- [x] 2.2 Add a GLB submesh-name loader (test-side) that lists node names in `placeholder_terrain01.glb`
- [x] 2.3 Implement footprint AABB computation (min/max corner heights over all cells) as a pure function

## 3. Preview scene

- [x] 3.1 Create `scenes/AssetPreview.tscn` instancing `DefaultSunLight01`, `DefaultWorldEnvironment01`, `Camera01`, a `CanvasLayer` HUD, and the preview controller node
- [x] 3.2 Implement `AssetPreviewController` script: load theater registry, group families, auto-load first family `_n`
- [x] 3.3 Implement family prev/next + dropdown navigation and N/E/S/W direction cycling
- [x] 3.4 Implement placement: ground lowest corner at y=0, min cell at origin, per design D2

## 4. Render states

- [x] 4.1 Implement mesh state: instantiate the resolved GLB submesh at origin, rotated by `mesh_rotation`
- [x] 4.2 Implement vector state: per-cell footprint outline + corner-height markers (DebugVisualizer-style primitives)
- [x] 4.3 Implement collision-box state: wireframe AABB from the footprint bounds
- [x] 4.4 Implement theater context overlay: registering theater(s), art_data id + `is_placeholder`, `default_land_type`
- [x] 4.5 Wire the four states as independent, stackable toggles (HUD checkboxes + `asset_preview_state_cycle` action)

## 5. Camera modes

- [x] 5.1 Implement `OrbitCameraController` (orbit pivot, wheel zoom, MMB/right pan), toggled by `asset_preview_cam_toggle` + HUD button
- [x] 5.2 Implement auto-turntable as object Y-rotation driven by `asset_preview_spin` + HUD button
- [x] 5.3 Make the turntable footprint-aware: spin the mesh (only) around the footprint center via a `_mesh_pivot` at the center, keeping vector/collision/axis references fixed

## 6. Info box

- [x] 6.1 Build info box UI: header, stats (dims, occupied count, min/max corner heights, land types)
- [x] 6.2 Build per-cell table (land, corners, crease, slope, connections) reflecting `TerrainObject` data
- [x] 6.3 Add art/theater context section: theater id, art_data, resolved mesh name + fallback source, mesh rotation
- [x] 6.4 Wire cell-row click to highlight the cell in the 3D view

## 7. Tests

- [x] 7.1 Unit: every theater-registered variant's `mesh_name()` resolves to an existing GLB submesh node name
- [x] 7.2 Unit: `mesh_rotation()` matches `DIRECTION_ROTATIONS` for all suffixes and 0 for non-directional ids
- [x] 7.3 Unit: footprint AABB min/max corner math for known tiles (e.g. `cliff01_n`, `ramp01_n`)
- [x] 7.4 Integration: `AssetPreview.tscn` loads headless, mesh state yields `MeshInstance3D` matching `mesh_name(id)`, cycling all 140 variants + camera/spin/state toggles run without script errors

## 8. Verification

- [x] 8.1 Run full suite: `redot --headless -s test/run_tests.gd`
- [x] 8.2 Run `gdlint` + `gdformat --check` on new/modified scripts; fix tabs introduced by formatting
- [x] 8.3 Launch the scene in the Redot editor and verify isometric default, orbit, turntable, all four states, and cell highlighting visually
