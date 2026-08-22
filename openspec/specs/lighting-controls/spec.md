### Requirement: Debug panel resolves lighting controls by group
The Debug panel SHALL locate the `LightingControls` node through the scene-tree group it registers in, not through a direct parent-child path, so the panel and the controls remain findable regardless of where each sits in the scene hierarchy.

Because `LightingControls` registers its group during its own `_ready()`, which may run after the Debug panel's `_ready()`, the panel SHALL resolve the group lazily — re-checking on use — so the reference is valid once the scene has fully readied.

#### Scenario: Debug panel finds lighting controls
- **WHEN** the Debug panel initializes and a `LightingControls` node is present in the current scene (registered in the `lighting_controls` group)
- **THEN** the panel holds a valid reference to that `LightingControls` node

#### Scenario: Lighting section opened after full scene ready
- **WHEN** the player opens the Lighting section and the scene's `LightingControls` has registered its group
- **THEN** the panel lazily resolves the `LightingControls` node and wiring the sliders

#### Scenario: Debug panel without lighting controls
- **WHEN** the Debug panel initializes and no `LightingControls` node exists in the group
- **THEN** the panel holds a null reference and does not error

### Requirement: Lighting controls register in a scene group
The `LightingControls` node SHALL add itself to the `lighting_controls` scene group during initialization so the Debug panel and other systems can find it without hardcoded paths.

#### Scenario: Lighting controls present in scene
- **WHEN** a `LightingControls` node finishes initialization
- **THEN** it is present in the `lighting_controls` scene group

### Requirement: Lighting slider changes apply to the scene
Adjusting any lighting slider or the sun-color picker in the Debug panel SHALL propagate through the `LightingControls` node's setters to the live scene light and environment nodes, producing a visible change.

#### Scenario: Sun intensity slider change
- **WHEN** the player adjusts the sun-intensity slider while the panel has a valid lighting controls reference
- **THEN** the scene's `DirectionalLight3D.light_energy` equals the slider's value

#### Scenario: Ambient light slider change
- **WHEN** the player adjusts the ambient-light slider while the panel has a valid lighting controls reference
- **THEN** the scene's `WorldEnvironment` ambient light energy equals the slider's value

#### Scenario: Fog density slider change
- **WHEN** the player adjusts the fog-density slider while the panel has a valid lighting controls reference
- **THEN** the scene's `WorldEnvironment` fog density equals the slider's value