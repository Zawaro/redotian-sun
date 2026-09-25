## ADDED Requirements

### Requirement: Particle quad size
A PARTICLES `FxData` SHALL expose `quad_size: float` (default `0.1`) giving the world-space edge length of the effect's particle quad. `FxSystem` SHALL size the `GPUParticles3D` draw quad from `quad_size` so particle effects are authored in world units instead of the `QuadMesh` default of one metre. The process material's `scale_min` / `scale_max` SHALL remain a per-particle variation on top of that base size.

#### Scenario: Quad sized from the effect
- **WHEN** a PARTICLES effect with `quad_size = 0.15` is played
- **THEN** its draw-pass `QuadMesh` is sized `0.15` on its width and height

#### Scenario: Default quad is small
- **WHEN** a PARTICLES effect leaves `quad_size` at its default
- **THEN** the built quad is `0.1` on its width and height

### Requirement: Effect point light
An `FxData` MAY carry a light: `light_energy: float` (default `0.0`, meaning no light), `light_color: Color`, and `light_range: float`. When `light_energy > 0.0`, `FxSystem` SHALL add an `OmniLight3D` to the effect node with those values, shadows disabled, on the effect's visual layer. The light SHALL be a child of the effect node so it is freed with the effect and disabled by the fog-freeze visibility toggle. When `light_energy <= 0.0` no light node SHALL be created.

#### Scenario: Light added when enabled
- **WHEN** a PARTICLES effect with `light_energy = 3.0`, a colour, and a range is played
- **THEN** an `OmniLight3D` child exists with that colour, energy, and range and with shadows disabled

#### Scenario: No light by default
- **WHEN** an effect leaves `light_energy` at its default
- **THEN** no `OmniLight3D` is created

#### Scenario: Light dies with the effect
- **WHEN** an effect carrying a light is freed at the end of its lifetime
- **THEN** the light is freed with it and leaves no orphan node
