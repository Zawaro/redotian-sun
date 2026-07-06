## ADDED Requirements

### Requirement: Camera movement speed is frame-rate independent
Camera panning speed SHALL produce consistent world-space movement regardless of framerate. No hardcoded FPS multipliers are permitted.

#### Scenario: Camera movement at 60 FPS
- **WHEN** the user holds a movement key for 1 second at 60 FPS
- **THEN** the camera moves approximately `navigation_speed * 1.0` world units

#### Scenario: Camera movement at 30 FPS
- **WHEN** the user holds a movement key for 1 second at 30 FPS
- **THEN** the camera moves approximately `navigation_speed * 1.0` world units (same distance as 60 FPS)

#### Scenario: Border panning consistency
- **WHEN** the user triggers border panning at any framerate
- **THEN** the camera moves at the same world-space speed as keyboard panning
