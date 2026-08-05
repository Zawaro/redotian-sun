## ADDED Requirements

### Requirement: SSAO disabled in default environment
The default world environment SHALL have SSAO disabled (`ssao_enabled = false`). Directional shadow size SHALL remain 4096, glow SHALL remain enabled, and fog SHALL remain enabled.

#### Scenario: Environment configuration
- **WHEN** the default world environment is loaded in MainScene, MapEditor, or AssetPreview
- **THEN** `ssao_enabled` is false on the environment resource

#### Scenario: Shadow resolution preserved
- **WHEN** the game renders with the default environment
- **THEN** `project.godot` `lights_and_shadows/directional_shadow/size` remains 4096

### Requirement: Shared building select-box material
Building select boxes SHALL use a single cached material shared across all buildings instead of allocating a fresh material per building. Box geometry SHALL remain generated per building from its foundation size.

#### Scenario: Material sharing
- **WHEN** two buildings with different foundation sizes each display their select box
- **THEN** both select boxes share the same `ORMMaterial3D` instance while rendering geometry sized to each foundation

#### Scenario: Geometry per foundation
- **WHEN** a building select box is drawn
- **THEN** its line geometry matches the building's `SelectComponent.outline_size` foundation dimensions

### Requirement: Release builds ship no debug geometry
Debug overlay meshes and debug-only scene nodes SHALL not exist or render in a non-debug build. The shipped HUD SHALL not contain an active DebugMenu in a non-debug build.

#### Scenario: No debug geometry in release
- **WHEN** the game runs from a non-debug build
- **THEN** no path lines, bounds meshes, or debug grid overlays are created or rendered

#### Scenario: No debug menu in release
- **WHEN** the game runs from a non-debug build
- **THEN** the DebugMenu node does not process input or render
