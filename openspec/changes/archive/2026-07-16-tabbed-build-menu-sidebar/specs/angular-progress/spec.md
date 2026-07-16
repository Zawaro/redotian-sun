## ADDED Requirements

### Requirement: Radial wipe shader
The system SHALL provide a canvas_item shader that renders a hard-edge radial wipe from 12 o'clock position going clockwise.

#### Scenario: Progress at 0%
- **WHEN** progress = 0.0
- **THEN** entire cameo is fully transparent (no overlay)

#### Scenario: Progress at 50%
- **WHEN** progress = 0.5
- **THEN** right half of cameo has black semi-transparent overlay
- **AND** left half is transparent

#### Scenario: Progress at 100%
- **WHEN** progress = 1.0
- **THEN** entire cameo has black semi-transparent overlay

### Requirement: Overlay colors
The shader SHALL use black (vec4(0,0,0,0.5)) for the covered area and fully transparent (vec4(0)) for the uncovered area, with a hard edge (no gradient blending).

#### Scenario: Hard edge
- **WHEN** progress = 0.3
- **THEN** the boundary between overlay and transparent is a sharp line
- **AND** no smooth gradient at the boundary

### Requirement: Progress parameter update
The shader SHALL accept a `progress` uniform (0.0-1.0) that can be updated per frame from ProductionManager.

#### Scenario: Progress update
- **WHEN** ProductionManager sets progress to 0.7
- **THEN** the shader overlay covers 70% of the cameo starting from 12 o'clock clockwise
