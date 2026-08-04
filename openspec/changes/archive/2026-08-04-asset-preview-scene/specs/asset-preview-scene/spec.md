# asset-preview-scene Specification

## ADDED Requirements

### Requirement: Standalone asset preview scene
The system SHALL provide a standalone scene `scenes/AssetPreview.tscn` that runs directly (F6 / `--scene`) without a main-menu entry point. It SHALL reuse `scenes/environment/DefaultSunLight01.tscn` and `scenes/environment/DefaultWorldEnvironment01.tscn` for its light and environment, and `scenes/hud/Camera01.tscn` (with `CameraController`) as its default isometric camera, so preview lighting and camera match gameplay and the map editor. The scene SHALL render one selected terrain asset at a time.

#### Scenario: Scene boots headless
- **WHEN** `AssetPreview.tscn` is loaded in a headless run
- **THEN** it instantiates without script errors and displays the first catalog asset

#### Scenario: Environment matches gameplay
- **WHEN** the preview scene runs
- **THEN** it uses the same world environment and directional light scenes as gameplay and the map editor

### Requirement: Asset browsing from theater registry
The asset list SHALL be sourced from the theater registry (`resources/theaters/temperate.tres`), exposing all registered `TerrainObject` variants grouped by base family. The preview SHALL auto-load the first family's `_n` variant on start. The user SHALL be able to step to the previous/next family, pick a family from a dropdown, and cycle the four directional variants (`_n`/`_e`/`_s`/`_w`) of the selected family.

#### Scenario: First family auto-loaded
- **WHEN** the scene starts
- **THEN** the first theater family's `_n` variant is displayed

#### Scenario: Direction cycle wraps
- **WHEN** the user cycles direction past the last of N/E/S/W
- **THEN** the direction wraps to the first of N/E/S/W and the object updates

#### Scenario: All theater variants reachable
- **WHEN** every family in the theater registry is selected
- **THEN** each of its four directional variants can be displayed without error

### Requirement: Camera modes
The default camera SHALL be isometric with the same controls as gameplay/editor. The system SHALL provide a free-orbit mode toggled by an InputMap action and a HUD button, in which dragging orbits around the object pivot, the wheel zooms, and middle/right mouse pans. The system SHALL provide an independent auto-turntable toggle that spins the object around its Y axis while any camera mode is active.

#### Scenario: Toggle to free orbit
- **WHEN** the user presses the camera-mode toggle (key or HUD button)
- **THEN** the camera switches between isometric and free-orbit around the object pivot

#### Scenario: Turntable spins object
- **WHEN** the turntable toggle is on
- **THEN** the object continuously rotates around its Y axis; toggling it off stops the rotation

### Requirement: Stackable render-state toggles
The system SHALL provide per-object render-state toggles as independent, stackable checkboxes (keyboard and HUD). The states SHALL be: vector (footprint wireframe with per-cell corner-height markers), collision box (wireframe AABB of the whole footprint derived from cell corners, not physics bodies), mesh (GLB submesh resolved via `TerrainArtData.mesh_name(id)` and `mesh_rotation(id)`, instantiated at the object origin), and theater context overlay (registering theater(s), `art_data.id` + `is_placeholder`, `default_land_type`). The mesh state SHALL be enabled by default.

#### Scenario: Mesh shows resolved submesh
- **WHEN** the mesh state is enabled for a variant
- **THEN** a `MeshInstance3D` exists whose mesh name equals `TerrainArtData.mesh_name(id)` and whose Y rotation equals `mesh_rotation(id)`

#### Scenario: States compose
- **WHEN** multiple states are enabled at once
- **THEN** all enabled representations are visible simultaneously

#### Scenario: Collision box from footprint
- **WHEN** the collision-box state is enabled
- **THEN** a wireframe box encloses the footprint's AABB computed from the min/max of its cell corner heights

#### Scenario: Theater overlay reports context
- **WHEN** the theater state is enabled
- **THEN** the overlay shows the theater(s) registering the object, the art data id and placeholder flag, and the theater default land type

### Requirement: Info box with cell linkage
The system SHALL display an info box for the selected object containing: header (id, display_name, cell_type, base family and current direction), stats (grid dimensions, occupied cell count, min/max corner heights, land types present), a per-cell table (`"x,z"` key, land, corners `[nw, ne, se, sw]`, crease, slope, connections), and context (theater id, art data id + placeholder flag, resolved mesh name and fallback source, mesh rotation). Clicking a cell row SHALL highlight that cell in the 3D view.

#### Scenario: Cell click highlights cell
- **WHEN** the user clicks a per-cell table row
- **THEN** the corresponding cell is visually highlighted in the 3D view

#### Scenario: Info matches object data
- **WHEN** an object is selected
- **THEN** the info box header and stats reflect that object's `TerrainObject` fields and grid

### Requirement: Placement and orientation
The selected object SHALL be placed with its lowest cell corner height at y=0 and its origin-normalized footprint min cell at the world origin. The `_n` variant SHALL be the default facing. When the direction is cycled, the mesh SHALL re-rotate in place while the footprint wireframe stays fixed in world space.

#### Scenario: Object grounded at origin
- **WHEN** an object is displayed
- **THEN** its lowest corner height is at y=0 and the footprint min cell is at the origin

#### Scenario: Footprint stays fixed on rotation
- **WHEN** the direction changes
- **THEN** the mesh rotates to the new facing while the footprint wireframe remains fixed in world space

### Requirement: Preview input actions
The system SHALL register InputMap actions `asset_preview_next`, `asset_preview_prev`, `asset_preview_dir_cycle`, `asset_preview_cam_toggle`, `asset_preview_spin`, and `asset_preview_state_cycle` in `project.godot`, following existing `InputSettings` remap conventions. HUD buttons SHALL invoke the same actions as the keyboard bindings.

#### Scenario: HUD button equals key
- **WHEN** a HUD button is pressed
- **THEN** the same action handler runs as when its bound key is pressed

### Requirement: Preview data contracts are tested
The system SHALL provide data-layer unit tests asserting: every theater-registered variant's `TerrainArtData.mesh_name()` resolves to an existing GLB submesh node name in `placeholder_terrain01.glb`; `mesh_rotation()` matches the `DIRECTION_ROTATIONS` table; and footprint AABB min/max corner math is correct for known tiles. The system SHALL provide a scene-layer integration test that loads `AssetPreview.tscn` headless, verifies the mesh state yields a `MeshInstance3D` matching `mesh_name(id)`, and cycles all 140 variants plus camera/spin/state toggles without script errors.

#### Scenario: Art seam resolves to existing submeshes
- **WHEN** every theater variant's resolved mesh name is checked against the GLB
- **THEN** each resolves to a submesh node that exists in `placeholder_terrain01.glb`

#### Scenario: Full catalog cycles cleanly
- **WHEN** the integration test cycles all registered variants and toggles camera/spin/states
- **THEN** no script errors occur and each variant displays
