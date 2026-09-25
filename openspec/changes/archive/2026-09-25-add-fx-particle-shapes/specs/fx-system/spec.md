## ADDED Requirements

### Requirement: Particle draw shape
A PARTICLES `FxData` SHALL expose `particle_shape: ParticleShape` with
`enum ParticleShape { QUAD, TRIANGLE }` (default `QUAD`). `FxSystem` SHALL build
the `GPUParticles3D` draw primitive accordingly: a `QuadMesh` for `QUAD`, or a
single-triangle `ArrayMesh` for `TRIANGLE`. Both shapes SHALL be sized by
`quad_size` and SHALL use the effect's `draw_material`. The default `QUAD` SHALL
leave existing particle effects unchanged.

#### Scenario: Quad shape builds a quad
- **WHEN** a PARTICLES effect leaves `particle_shape` at its default
- **THEN** its draw pass is a `QuadMesh` sized by `quad_size`

#### Scenario: Triangle shape builds a triangle
- **WHEN** a PARTICLES effect sets `particle_shape = TRIANGLE`
- **THEN** its draw pass is a single-surface `ArrayMesh` (one triangle) with the effect's draw material

## MODIFIED Requirements

### Requirement: FxData resource class
The system SHALL provide an `FxData` resource class (`scripts/data/FxData.gd`, `class_name FxData extends Resource`) describing a single one-shot visual effect. It SHALL expose `id: String`, `kind: Kind` with `enum Kind { SPRITE, PARTICLES }`, and `duration: float` (default `0`, meaning derive from the effect). Every field SHALL have a sensible default so unused properties can be ignored. SPRITE effects SHALL expose `sprite_frames: SpriteFrames`, `animation: StringName`, `pixel_size: float`, and `modulate: Color`. PARTICLES effects SHALL expose `process_material: ParticleProcessMaterial`, `draw_material: StandardMaterial3D`, `amount: int`, `lifetime: float`, `explosiveness: float`, and `local_coords: bool`. The effect SHALL carry no audio field; callers retain their existing sound fields (`WeaponData.sound_report`, `WarheadData.sound_impact`, `EntityData.sound_die`).

#### Scenario: Create a sprite effect
- **WHEN** an `FxData` is created with `id = "ExplosionSmall"`, `kind = Kind.SPRITE`, and a `SpriteFrames` value
- **THEN** the resource exposes those values with defaults for every particle field

#### Scenario: Create a particle effect
- **WHEN** an `FxData` is created with `id = "MuzzleFlashSmall"`, `kind = Kind.PARTICLES`, a `ParticleProcessMaterial`, and a `StandardMaterial3D`
- **THEN** the resource exposes those values with defaults for every sprite field
