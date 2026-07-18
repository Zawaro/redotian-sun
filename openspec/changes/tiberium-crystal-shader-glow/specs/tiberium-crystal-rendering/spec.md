## ADDED Requirements

### Requirement: Tiberium crystal custom shader
Tiberium crystals SHALL use a custom unlit spatial shader with Y-gradient coloring, fresnel edge glow, noise-based surface variation, and animated emission pulse.

#### Scenario: Unlit rendering
- **WHEN** a tiberium crystal is rendered
- **THEN** the shader SHALL ignore all scene lighting (unshaded render mode)

#### Scenario: Y-gradient coloring
- **WHEN** the crystal is rendered
- **THEN** the bottom of the crystal SHALL be darker than the top, interpolated via color_bottom and color_top uniforms

#### Scenario: Fresnel edge glow
- **WHEN** the crystal is viewed from an angle
- **THEN** edges facing away from the camera SHALL appear brighter than faces facing the camera

#### Scenario: Noise variation
- **WHEN** the crystal is rendered
- **THEN** the surface color SHALL have subtle variation based on 3D value noise, not flat uniform color

#### Scenario: Emission pulse
- **WHEN** the crystal is rendered
- **THEN** the emission strength SHALL oscillate over time based on pulse_speed and pulse_amount uniforms

### Requirement: Tiberium sparkle particles
Tiberium crystals SHALL emit GPUParticles3D green sparkles that float upward from a box covering the cell area.

#### Scenario: Particle emission area
- **WHEN** sparkles are emitted
- **THEN** they SHALL spawn randomly within a box of extents (2.0, 0.1, 2.0) centered on the crystal

#### Scenario: Upward float without gravity
- **WHEN** sparkles are emitted
- **THEN** they SHALL move upward with zero gravity and fade out over their lifetime

#### Scenario: Particle appearance
- **WHEN** sparkles are visible
- **THEN** they SHALL be small green spheres (0.01–0.03 scale) with alpha fading from green to transparent

### Requirement: Tiberium glow aura sprite
Tiberium crystals SHALL have a billboard Sprite3D with a procedural radial gradient texture for soft glow halo.

#### Scenario: Billboard rendering
- **WHEN** the glow sprite is rendered
- **THEN** it SHALL always face the camera (billboard mode enabled)

#### Scenario: Glow texture
- **WHEN** the glow sprite is rendered
- **THEN** it SHALL display a soft radial gradient from opaque center to transparent edges

#### Scenario: Glow positioning
- **WHEN** the glow sprite is created
- **THEN** it SHALL be positioned at Y=2.0 above the crystal to avoid terrain occlusion

### Requirement: Tiberium point light
Tiberium crystals with point_light_enabled SHALL spawn an OmniLight3D that illuminates terrain but not the crystal mesh.

#### Scenario: Light culling
- **WHEN** the OmniLight3D is created
- **THEN** its light_cull_mask SHALL be 1 (excluding layer 2 where crystals render)

#### Scenario: Crystal layer assignment
- **WHEN** crystal meshes are created
- **THEN** they SHALL be on rendering layer 2
