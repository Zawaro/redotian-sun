## ADDED Requirements

### Requirement: Selection and health preview
The browser SHALL provide a Select overlay that mirrors the gameplay `SelectComponent` for entity assets, and SHALL hide it for terrain, overlay, and smudge assets and for audio/image previews. For eligible assets it SHALL draw a corner-bracket selection box sized from the entity's `foundation` cells (`foundation × CELL_SIZE`) for buildings, or the asset's mesh bounds otherwise, spanning from the ground plane to the box height. For buildings it SHALL additionally draw the structure health bar as a full-depth span along the footprint's local Z axis at the top-left edge of the select box, at full health, constructed as in `SelectComponent._build_segmented_bar` (`span_is_x = false`). The box and bar SHALL be children of the asset root so they rotate with the asset.

#### Scenario: Select preview appears for entity assets
- **WHEN** a building or unit asset is selected with the Select overlay enabled
- **THEN** the select box renders around the asset at the correct size

#### Scenario: Select box spans the foundation
- **WHEN** a building asset with a multi-cell `foundation` is selected
- **THEN** the select box spans `foundation × CELL_SIZE` in X and Z, not the model mesh bounds

#### Scenario: Health bar sits at the select box top
- **WHEN** a building asset is selected
- **THEN** the health bar's top aligns with the top of the select box and its long axis runs along local Z at the box's left edge

#### Scenario: Non-entity assets show no select preview
- **WHEN** a terrain, overlay, or smudge asset is selected
- **THEN** no select box or health bar is drawn

### Requirement: Theater selection
The browser SHALL provide a theater selector listing every theater from `TerrainCatalog.get_all_theaters()` by display name (falling back to id) and preselecting the active theater (`TerrainCatalog.get_active_theater_id()`). Selecting a theater SHALL call `TerrainCatalog.set_active_theater(id)` and refresh the preview so terrain art, the theater/context label, and the ground grid reflect the chosen theater. The selector SHALL be disabled when only one theater is available. Theater switching SHALL be in-memory only and MUST NOT persist the choice.

#### Scenario: Theaters are listed
- **WHEN** the browser starts
- **THEN** its theater selector lists every registered theater and preselects the active one

#### Scenario: Selecting a theater updates the preview
- **WHEN** the user selects a different theater
- **THEN** `TerrainCatalog.set_active_theater(id)` runs and the previewed terrain art and context label reflect the chosen theater

#### Scenario: Single theater is disabled
- **WHEN** only one theater is registered
- **THEN** the theater selector is present but disabled

#### Scenario: Theater choice is not persisted
- **WHEN** the user switches theater in the browser
- **THEN** no persisted setting is written

## MODIFIED Requirements

### Requirement: Asset rotation
All rotation SHALL turn the selected asset around its bounding-box center rather than moving the camera, so the directional light and world environment stay fixed. In Isometric mode rotation SHALL be yaw-only (Y axis), preserving the upright isometric view. In Perspective mode rotation SHALL be yaw plus pitch (no roll), with pitch clamped to avoid gimbal flip. The browser SHALL provide continuous rotation (drag and an auto-rotate toggle) and discrete 90-degree yaw steps (button and InputMap action). The browser SHALL provide a reset action (HUD button) that restores the asset to its authored base yaw and clears any pitch. On selection the asset SHALL be grounded so its lowest point sits at the world origin and the ground grid reads correctly. Any base art rotation SHALL fold into the asset's starting yaw.

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

#### Scenario: Reset restores authored facing
- **WHEN** the reset action is used after rotating and pitching the asset
- **THEN** the asset's yaw returns to its authored base yaw and its pitch is zero

#### Scenario: Asset is grounded
- **WHEN** an asset is displayed
- **THEN** its lowest point is at the world origin and it rotates about its bounds center

### Requirement: Stackable render overlays
The browser SHALL provide independent, stackable render-state toggles (HUD checkboxes and an InputMap cycle action) that apply to 3D assets only, defaulting to Mesh, Axis, and Select enabled and the rest disabled. Object-space overlays SHALL rotate with the asset; world-space overlays SHALL stay fixed. The states SHALL be: mesh (model visibility), footprint grid with per-cell corner-height markers (TerrainObject cells, or entity/art `foundation` cells), collision/bounds box (axis-aligned wireframe of the asset's bounds), theater/context label, ground grid (world-fixed), axis lines (X/Z, world-fixed), and select box with structure health bar (gameplay `SelectComponent` mirror).

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
