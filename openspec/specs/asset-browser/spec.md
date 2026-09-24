# asset-browser Specification

## Purpose

Standalone game-aware asset browser for inspecting a game's visual and audio assets: a data-driven category registry over `data_set` roots with lazy load-on-select, mode-adaptive 3D/audio/image preview, a preview-owned isometric/perspective camera with asset rotation and stackable render overlays, and ephemeral game switching via `GameContext`. Supersedes the terrain-only `asset-preview-scene`.

## Requirements
### Requirement: Standalone game-aware asset browser scene
The system SHALL provide a standalone scene `scenes/AssetBrowser.tscn` that runs directly (F6 / `--scene`) with no main-menu entry point, and SHALL render one selected asset at a time. The scene SHALL reuse `scenes/environment/DefaultSunLight01.tscn` and `scenes/environment/DefaultWorldEnvironment01.tscn` for lighting and environment, and SHALL use a preview-owned camera rather than any gameplay camera or `CameraController`. It SHALL suppress gameplay world overlays (the fog-of-war/shroud plane) so they do not drape over the inspected asset, restoring them when the scene exits.

#### Scenario: Scene boots standalone
- **WHEN** `AssetBrowser.tscn` is loaded (headless or Run Scene)
- **THEN** it instantiates without script errors and displays the first asset of the first category for the active game

#### Scenario: No gameplay camera is present
- **WHEN** the browser scene is loaded
- **THEN** the scene contains no `CameraController` node and no gameplay camera input handling

#### Scenario: Gameplay fog does not cover the asset
- **WHEN** the browser scene is loaded
- **THEN** the fog-of-war/shroud world plane is hidden for the lifetime of the scene

### Requirement: Game selection
The browser SHALL list every game from `GameContext.list_games()` and SHALL switch to the selected game through `GameContext.select_game(id)`. Switching SHALL be ephemeral: the browser MUST NOT call `save_game_choice()` or otherwise persist the selection. The browser SHALL rebuild its categories, asset list, and preview when the active game changes.

#### Scenario: Games are listed
- **WHEN** the browser starts
- **THEN** its game selector lists every discovered `GameDefinition` by display name (falling back to id) and preselects the active game

#### Scenario: Selecting a game rebuilds the browser
- **WHEN** the user selects a different game
- **THEN** `GameContext.select_game(id)` runs, the content autoloads reload, and the browser re-scans categories and assets for the new game without a restart

#### Scenario: Selection is not persisted
- **WHEN** the user switches games in the browser
- **THEN** the persisted `[game] id` setting is unchanged

#### Scenario: No active game
- **WHEN** no game is selected
- **THEN** the browser shows an explicit empty state and does not error

### Requirement: Data-driven category registry
The browser SHALL define asset categories as data (a registry), where each entry declares a label, a source subdirectory name, an optional resource filter, and a preview mode. The set of in-scope categories SHALL cover visual and audio assets: terrain objects, buildings, infantry, vehicles, aircraft, terrain props, overlays, smudges, art entries (`ArtData`), terrain art (`TerrainArtData`), sound effects (`AudioData`), voices (`VoiceData`), and cameo/UI textures. Adding or removing a category SHALL require editing only the registry.

#### Scenario: Category selector lists in-scope categories
- **WHEN** the browser starts for a game
- **THEN** the category selector offers each in-scope category that resolves at least one source directory

#### Scenario: Missing category directory is tolerated
- **WHEN** a game has no directory for a registered category
- **THEN** that category is skipped (or shown empty) with a warning and the rest of the browser still works

#### Scenario: Entity categories filter by type
- **WHEN** the buildings/infantry/vehicles/aircraft/terrain-props/overlays/smudges categories are selected
- **THEN** each lists only `EntityData` whose `entity_type` matches that category

### Requirement: Asset listing, filtering, and lazy loading
For the selected game and category, the browser SHALL list assets sourced from each `data_set` root in order, with later roots overriding same-id assets (mirroring the `game-content` layering). The browser SHALL provide a free-text filter over the asset list and MUST load a resource only when it is selected (lazy load-on-select), not when the list is built.

#### Scenario: Layer roots override
- **WHEN** two `data_set` roots define the same asset id in a category
- **THEN** the entry from the later root is the one listed and previewed

#### Scenario: Filter narrows the list
- **WHEN** the user types into the filter input
- **THEN** the asset list shows only entries whose id or filename contains the filter text

#### Scenario: Only the selected asset is loaded
- **WHEN** a category or game is selected
- **THEN** the browser enumerates asset paths without loading every resource, and loads a resource only when the user selects it

### Requirement: Mode-adaptive asset preview
The browser SHALL preview the selected asset using the mode declared by its category: a 3D view for model/terrain categories, an audio transport for sound/voice categories, and an image view for texture categories. For 3D assets the browser SHALL resolve a model through the ladder: `EntityData.art_data.model_path` -> `ArtData.model_path` -> terrain art resolution (`TerrainCatalog.resolve_art`) -> procedural box from `ArtData.placeholder_size` -> explicit empty state. A failed resolution SHALL show an explicit empty state and emit a warning rather than silently rendering nothing.

#### Scenario: 3D asset renders a model
- **WHEN** a model-backed asset is selected
- **THEN** the 3D view instantiates the model and frames the camera on it

#### Scenario: Placeholder renders when no model exists
- **WHEN** a 3D asset has no model path but declares a `placeholder_size`
- **THEN** the 3D view shows a procedural box of that size

#### Scenario: Failed resolution is visible
- **WHEN** a 3D asset resolves to no model and no placeholder
- **THEN** the browser shows an explicit empty state and logs a warning

#### Scenario: Audio asset plays
- **WHEN** an audio asset is selected
- **THEN** the audio view exposes play/stop controls that play the asset's stream

#### Scenario: Texture asset displays
- **WHEN** a texture asset is selected
- **THEN** the image view displays the texture

### Requirement: Static framing camera with projection modes
The browser SHALL use a preview-owned `Camera3D` that never orbits, and SHALL NOT use any gameplay camera, `CameraController`, gameplay panning, or map-bounds clamping. The camera SHALL sit at the gameplay isometric vantage (45-degree yaw, 30-degree pitch down) in both projection modes. The browser SHALL provide an Isometric mode (orthographic projection matching the gameplay camera) and a Perspective mode (perspective projection at the same vantage), toggled by an InputMap action and a HUD button. Zoom SHALL change the orthographic `size` in Isometric mode and the view distance in Perspective mode, clamped in both. The camera SHALL auto-frame the selected asset on selection and SHALL remain stationary whenever no zoom input is applied.

#### Scenario: Isometric matches the gameplay angle
- **WHEN** the browser starts
- **THEN** the camera uses orthographic projection at the gameplay isometric vantage with a framed ortho size

#### Scenario: Projection toggles
- **WHEN** the camera-mode toggle (key or HUD button) is activated
- **THEN** the camera switches between isometric and perspective projection and re-frames the asset

#### Scenario: Zoom is clamped in both modes
- **WHEN** the user zooms in or out past the configured limits
- **THEN** the orthographic size (isometric) or view distance (perspective) stops at the limit

#### Scenario: Camera is stable when idle
- **WHEN** no zoom input is applied across frames
- **THEN** the camera transform does not change

### Requirement: Asset rotation
All rotation SHALL turn the selected asset around its bounding-box center rather than moving the camera, so the directional light and world environment stay fixed. In Isometric mode rotation SHALL be yaw-only (Y axis), preserving the upright isometric view. In Perspective mode rotation SHALL be yaw plus pitch (no roll), with pitch clamped to avoid gimbal flip. The browser SHALL provide continuous rotation (drag and an auto-rotate toggle) and discrete 90-degree yaw steps (button and InputMap action). On selection the asset SHALL be grounded so its lowest point sits at the world origin and the ground grid reads correctly. Any base art rotation SHALL fold into the asset's starting yaw.

#### Scenario: Isometric rotation is yaw-only
- **WHEN** pitch/drag input is applied in Isometric mode
- **THEN** only the asset's yaw changes and it stays upright

#### Scenario: Perspective rotation is free
- **WHEN** drag input is applied in Perspective mode
- **THEN** the asset yaws and pitches within the clamped pitch range

#### Scenario: Automatic rotation turns the asset
- **WHEN** the auto-rotate toggle is enabled
- **THEN** the asset continuously yaws until toggled off while the camera stays fixed

#### Scenario: 90-degree steps
- **WHEN** a 90-degree rotate button is pressed
- **THEN** the asset yaws by exactly 90 degrees

#### Scenario: Asset is grounded
- **WHEN** an asset is displayed
- **THEN** its lowest point is at the world origin and it rotates about its bounds center

### Requirement: Stackable render overlays
The browser SHALL provide independent, stackable render-state toggles (HUD checkboxes and an InputMap cycle action) that apply to 3D assets only, defaulting to Mesh and Axis enabled and the rest disabled. Object-space overlays SHALL rotate with the asset; world-space overlays SHALL stay fixed. The states SHALL be: mesh (model visibility), footprint grid with per-cell corner-height markers (TerrainObject cells, or entity/art `foundation` cells), collision/bounds box (axis-aligned wireframe of the asset's bounds), theater/context label, ground grid (world-fixed), and axis lines (X/Z, world-fixed).

#### Scenario: Overlays toggle independently
- **WHEN** a render-state checkbox is toggled
- **THEN** only that overlay's node visibility changes, and multiple overlays can be shown at once

#### Scenario: Overlays are 3D-only
- **WHEN** an audio or image asset is selected
- **THEN** the 3D overlays are hidden

#### Scenario: World overlays stay fixed
- **WHEN** the asset rotates
- **THEN** the ground grid and axis lines do not rotate with it

#### Scenario: Footprint markers reflect cell heights
- **WHEN** the footprint overlay is enabled for a terrain asset
- **THEN** each occupied cell shows its outline plus vertical markers to its corner heights

### Requirement: Per-cell inspection
The browser SHALL list a terrain asset's footprint cells in the info panel and SHALL highlight the matching cell in the 3D view when a row is clicked. The highlight SHALL be attached to the asset so it rotates with it.

#### Scenario: Cell click highlights cell
- **WHEN** the user clicks a per-cell table row
- **THEN** the corresponding cell is highlighted in the 3D view and rotates with the asset

### Requirement: Asset browser data contracts are tested
The system SHALL provide unit tests asserting the category registry resolves at least one asset per in-scope category for the default game, that asset listing honors `data_set` layering, and that terrain footprint bounds and cell-corner geometry are correct. The system SHALL provide an integration test that loads `scenes/AssetBrowser.tscn` headless, exercises game/category/asset selection (including the filter), previews the first asset of every category without script errors, verifies the camera projection modes, asset rotation (yaw-only in isometric, pitch in perspective, camera fixed while the asset rotates), zoom clamping in both modes, the stackable overlays (including world-fixed ground/axis), the cell highlight, and a simulated `game_changed` rebuilds the browser.

#### Scenario: Registry covers every in-scope category
- **WHEN** the category registry is checked against the default game
- **THEN** every in-scope category that has source directories resolves at least one asset

#### Scenario: Selection cycle is clean
- **WHEN** the integration test selects every category and loads its first asset, then switches game and back
- **THEN** no script errors occur and the browser reflects the active game

#### Scenario: Rotation and overlays behave per spec
- **WHEN** the integration test toggles projection, rotates the asset, and toggles every overlay
- **THEN** the camera stays fixed, the asset rotates about its center, and each overlay's visibility matches its state
