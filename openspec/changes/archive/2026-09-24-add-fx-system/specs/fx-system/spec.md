## ADDED Requirements

### Requirement: FxData resource class
The system SHALL provide an `FxData` resource class (`scripts/data/FxData.gd`, `class_name FxData extends Resource`) describing a single one-shot visual effect. It SHALL expose `id: String`, `kind: Kind` with `enum Kind { SPRITE, PARTICLES }`, and `duration: float` (default `0`, meaning derive from the effect). Every field SHALL have a sensible default so unused properties can be ignored. SPRITE effects SHALL expose `sprite_frames: SpriteFrames`, `animation: StringName`, `pixel_size: float`, and `modulate: Color`. PARTICLES effects SHALL expose `process_material: ParticleProcessMaterial`, `draw_material: StandardMaterial3D`, `amount: int`, `lifetime: float`, `explosiveness: float`, and `local_coords: bool`. The effect SHALL carry no audio field; callers retain their existing sound fields (`WeaponData.sound_report`, `WarheadData.sound_impact`, `EntityData.sound_die`).

#### Scenario: Create a sprite effect
- **WHEN** an `FxData` is created with `id = "BulletHitSmall"`, `kind = Kind.SPRITE`, and a `SpriteFrames` value
- **THEN** the resource exposes those values with defaults for every particle field

#### Scenario: Create a particle effect
- **WHEN** an `FxData` is created with `id = "MuzzleFlashSmall"`, `kind = Kind.PARTICLES`, a `ParticleProcessMaterial`, and a `StandardMaterial3D`
- **THEN** the resource exposes those values with defaults for every sprite field

### Requirement: FxData animated texture support
For SPRITE effects, `FxData` SHALL support animated texture data through `SpriteFrames`, covering both a PNG sequence (one texture per frame) and a sprite-sheet grid (frames referencing atlas regions). Playing the effect SHALL advance the frames at the `SpriteFrames` animation's configured speed. A sprite effect SHALL be rendered as a billboard so it faces the camera from the game's isometric view.

#### Scenario: PNG sequence effect
- **WHEN** a SPRITE effect's `SpriteFrames` animation contains one texture per frame
- **THEN** playing the effect advances through those frames and displays them in order

#### Scenario: Sprite-sheet effect
- **WHEN** a SPRITE effect's `SpriteFrames` animation contains frames referencing regions of a single sheet texture
- **THEN** playing the effect displays each region in order

#### Scenario: Billboard facing
- **WHEN** a SPRITE effect is spawned
- **THEN** its sprite is billboarded to face the camera

### Requirement: FxData validation
`FxData` SHALL expose `validate() -> PackedStringArray` reporting an error when `id` is empty, when `kind == Kind.SPRITE` and `sprite_frames` is null, and when `kind == Kind.PARTICLES` and `process_material` is null. A fully specified effect SHALL return an empty array.

#### Scenario: Empty id fails
- **WHEN** `validate()` is called on an `FxData` whose `id` is `""`
- **THEN** the returned array is non-empty and names the empty id

#### Scenario: Sprite effect missing frames fails
- **WHEN** `validate()` is called on a SPRITE effect with null `sprite_frames`
- **THEN** the returned array reports the missing sprite frames

#### Scenario: Particle effect missing process material fails
- **WHEN** `validate()` is called on a PARTICLES effect with null `process_material`
- **THEN** the returned array reports the missing process material

#### Scenario: Valid effect passes
- **WHEN** `validate()` is called on a SPRITE effect with an id and sprite frames, or a PARTICLES effect with an id and process material
- **THEN** the returned array is empty

### Requirement: FxSystem autoload and playback
The system SHALL provide an `FxSystem` autoload exposing `play(fx: FxData, global_transform: Transform3D) -> Node3D`. `play` SHALL instantiate the effect node, parent it to the gameplay root (`get_tree().current_scene`, falling back to the caller's scene root when absent), place it at `global_transform`, and return the node. A null `fx` or one that fails `validate()` SHALL log a warning and return `null` without adding a node.

#### Scenario: Play adds a node
- **WHEN** `play` is called with a valid `FxData` and a transform
- **THEN** a node exists under the gameplay root at that transform and is returned

#### Scenario: Null effect is a no-op
- **WHEN** `play` is called with `null`
- **THEN** no node is added, a warning is logged, and `null` is returned

#### Scenario: Cleanup on map change
- **WHEN** the gameplay scene changes while one-shot effects are alive
- **THEN** those effects are freed with the scene and no orphan nodes remain

### Requirement: Effect kind selection and build
`FxSystem.play` SHALL build different nodes per `FxData.kind`. For `Kind.SPRITE` it SHALL create an `AnimatedSprite3D`, assign `sprite_frames`, play `animation`, set `pixel_size` and `modulate`, enable billboard, and use nearest texture filtering. For `Kind.PARTICLES` it SHALL create a `GPUParticles3D`, assign `process_material` and `draw_material`, set `amount`, `lifetime`, `explosiveness`, and `local_coords`, set the node to one-shot, connect the node's `finished` signal as an early-free, and start emitting after the hook is connected. A PARTICLES `draw_material` SHALL set `vertex_color_use_as_albedo` so the process material's `color` / color-ramp reaches the pixels.

#### Scenario: Sprite effect builds an animated sprite
- **WHEN** `play` is called with a SPRITE `FxData`
- **THEN** an `AnimatedSprite3D` is created with the effect's frames playing the named animation

#### Scenario: Particle effect builds a GPU emitter
- **WHEN** `play` is called with a PARTICLES `FxData`
- **THEN** a `GPUParticles3D` is created with the effect's process material, draw material, amount, lifetime, and explosiveness

### Requirement: One-shot effect lifecycle
A one-shot effect SHALL free itself on a deterministic timer, with the GPU `finished` signal (PARTICLES) as an optional early-out: `duration` when greater than zero, otherwise a value derived from the effect. For SPRITE the derived value SHALL be the total sprite frame time. For PARTICLES the derived value SHALL be a ceiling of twice `lifetime`, covering the emission spread for any `explosiveness` and the full lifetime of the last particle. The timer SHALL remain the authoritative cleanup path so behavior is identical headless and with rendering disabled.

#### Scenario: Auto-free on duration
- **WHEN** a one-shot effect with `duration = 0.2` is played
- **THEN** its node is freed after approximately 0.2 seconds

#### Scenario: Sprite duration derived
- **WHEN** a SPRITE effect has `duration = 0.0` and a `SpriteFrames` animation lasting 0.3 seconds
- **THEN** its node is freed after approximately the animation length

#### Scenario: Particle duration derived as a ceiling
- **WHEN** a PARTICLES effect has `duration = 0.0` and `lifetime = 1.5`
- **THEN** its node is freed after approximately 3.0 seconds, so no particle is cut off

#### Scenario: Particle finished is an early-out
- **WHEN** a PARTICLES effect's engine `finished` signal fires before its timer elapses
- **THEN** its node is freed at that point

### Requirement: Fog-of-war gating of effects
`FxSystem` SHALL NOT spawn an effect whose cell is not currently visible to the local player (`ShroudSystem.is_cell_visible_to_local`) when a shroud grid is initialized (`ShroudSystem.is_grid_ready()`). Before a grid exists, effects SHALL NOT be gated. While an active effect's cell is not visible to the local player, the effect SHALL freeze (pause sprite playback and stop particle processing) rather than render; when the cell becomes visible again the effect SHALL resume. A frozen effect SHALL still be freed once its total age reaches a bounded retention cap, so an unrevealed cell cannot retain effects forever. When fog of war is disabled, effects SHALL always be visible and never gated. This requirement applies to both effect kinds.

#### Scenario: No spawn under shroud
- **WHEN** `play` is called at a cell that is not visible to the local player and a shroud grid is ready
- **THEN** no effect node is added

#### Scenario: No grid is ungated
- **WHEN** no shroud grid has been initialized and `play` is called anywhere
- **THEN** the effect spawns

#### Scenario: Freeze when the cell becomes fogged
- **WHEN** an active effect's cell transitions to not visible to the local player
- **THEN** the effect stops animating/processing and renders nothing until the cell is visible again

#### Scenario: Resume on reveal
- **WHEN** a frozen effect's cell becomes visible to the local player again
- **THEN** the effect resumes animating/processing

#### Scenario: Frozen retention is bounded
- **WHEN** an effect is frozen by fog and its cell never becomes visible
- **THEN** it is still freed once its total age reaches the retention cap

#### Scenario: Fog disabled is ungated
- **WHEN** fog of war is disabled and `play` is called anywhere
- **THEN** the effect spawns and is visible

### Requirement: Pixel-art viewport rendering
FX nodes SHALL render on visual layer 1 (the default) so the low-res orthographic pixel-art viewport (`PixelArtManager`, camera `cull_mask = 0b01`) includes them. SPRITE effects SHALL use `TEXTURE_FILTER_NEAREST` so their pixels stay crisp when the viewport is upscaled.

#### Scenario: Effect is in the pixel-art pass
- **WHEN** an effect node is spawned
- **THEN** its visual layer is 1

#### Scenario: Sprite uses nearest filtering
- **WHEN** a SPRITE effect is spawned
- **THEN** its texture filter is nearest

### Requirement: FxData assignment on combat data
`WeaponData` SHALL expose `muzzle_fx: FxData` and `WarheadData` SHALL expose `impact_fx: FxData`, both defaulting to `null` so existing resources are unchanged. A `null` value SHALL mean no effect.

#### Scenario: Default is no effect
- **WHEN** a `WeaponData` or `WarheadData` is created without an FX reference
- **THEN** `muzzle_fx` / `impact_fx` is `null`

#### Scenario: Assigned effect resolves
- **WHEN** a weapon sets `muzzle_fx` and a warhead sets `impact_fx` to `FxData` resources
- **THEN** the references are available to their consumers without a registry lookup
