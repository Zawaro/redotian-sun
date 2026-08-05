## ADDED Requirements

### Requirement: Debug facilities gated to debug builds
All debug facilities — the DebugMenu panel, DebugVisualizer overlays, and per-entity path visualization (`MovementController.debug_show_path`) — SHALL be inert in non-debug builds. Behavior in debug builds SHALL be unchanged.

#### Scenario: Debug menu absent in release
- **WHEN** the game runs from a non-debug build
- **THEN** the DebugMenu node removes itself from the scene and does not respond to the backtick key, lighting sliders, cheat toggles, or inspection

#### Scenario: Overlays inert in release
- **WHEN** the game runs from a non-debug build
- **THEN** DebugVisualizer performs no per-frame work and never creates overlay meshes or canvas items

#### Scenario: Path visualization inert in release
- **WHEN** the game runs from a non-debug build and a unit starts or finishes a move
- **THEN** no path line is drawn or cleared, regardless of any `debug_show_path` value in a scene file

#### Scenario: Debug builds unchanged
- **WHEN** the game runs from a debug build
- **THEN** the debug panel, overlays, and path visualization behave exactly as before this change
