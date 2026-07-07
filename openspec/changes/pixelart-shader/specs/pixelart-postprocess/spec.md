## ADDED Requirements

### Requirement: 3D pixel art pixelation

The system SHALL apply fullscreen pixelation to the 3D world render. The pixelation SHALL be governed by a uniform `pixel_size` integer (range 1–32, default 4) that determines the side length of each pixel block in screen pixels. The pixel block color SHALL be sampled from the center texel of the block using nearest-neighbor filtering. The UI (Control nodes) SHALL NOT be pixelated.

#### Scenario: Default pixelation size

- **WHEN** the scene is rendered with `pixel_size = 4` at 1920×1080
- **THEN** the 3D render SHALL be divided into 480×270 pixel blocks, each showing the center texel color

#### Scenario: Maximum pixelation

- **WHEN** `pixel_size = 32`
- **THEN** the 3D render SHALL be divided into 60×33 pixel blocks

#### Scenario: Minimum pixelation (nearly native)

- **WHEN** `pixel_size = 1`
- **THEN** the 3D render SHALL be sampled at every pixel with no block grouping

#### Scenario: UI unaffected by pixelation

- **WHEN** a Control node (e.g., MainMenu01 or FPSCounter01) is displayed
- **THEN** the text and elements SHALL render at native resolution without pixel block artifacts

### Requirement: Depth-based entity outline

The system SHALL draw outlines at depth discontinuities in the 3D scene, masked so that outlines only appear where an entity on render layer 2 is present. The outline color SHALL be defined by a uniform `outline_color` (default black at 0.5 alpha). The outline opacity SHALL be computed as `min(outline_color.a, edge * mask)` where `edge` is the depth-discontinuity factor and `mask` is the entity mask value at the pixel block. The outline SHALL replace pixel color via `mix(color, outline_color.rgb, opacity)`.

Depth edge detection SHALL use a 4-tap kernel comparing the center pixel block's depth against blocks at offsets `(-pixel_size, 0)`, `(pixel_size, 0)`, `(0, -pixel_size)`, and `(0, pixel_size)`. The maximum absolute depth difference among the four taps SHALL be mapped through `smoothstep(0.0, outline_threshold, max_diff)` to produce the edge factor.

The entity mask SHALL be sampled from a uniform sampler2D (`entity_mask`, `filter_nearest`) at the block-center UV coordinate. The mask texture SHALL be a SubViewport render containing only geometry on render layer 2, rendered as unshaded white with `transparent_bg = true`.

#### Scenario: Entity outline at depth boundary

- **WHEN** a NodBuggy (on layer 2) is rendered against the GroundPlane (not on layer 2) with a depth difference exceeding `outline_threshold`
- **THEN** the boundary pixels SHALL show `mix(entity_color, outline_color.rgb, 0.5)` (50% black outline)

#### Scenario: No outline on depth-flat terrain

- **WHEN** the GroundPlane spans multiple pixel blocks at the same depth
- **THEN** no outline SHALL be drawn on those interior blocks

#### Scenario: Entity without layer 2 has no outline

- **WHEN** a MeshInstance3D is on layer 1 only and has a depth discontinuity against another object
- **THEN** no outline SHALL be drawn at that boundary (mask = 0)

#### Scenario: Entity with layer 2 enabled receives outline

- **WHEN** any entity scene has render layer 2 checked on its MeshInstance3D
- **THEN** that entity SHALL receive outlines at its depth boundaries against non-layer-2 geometry

### Requirement: Outlines are optional through render layers

The outline system SHALL NOT require code changes to add outlines to new entities or props. Any MeshInstance3D with render layer 2 enabled in the editor SHALL automatically appear in the entity mask and receive outlines at its depth boundaries. Entities and props without layer 2 SHALL NOT receive outlines.

#### Scenario: New prop receives outlines via editor toggle

- **WHEN** a new prop MeshInstance3D has render layer 2 enabled in the scene editor
- **THEN** the prop SHALL appear in outlines on the next frame
- **AND** no code changes are required

### Requirement: EntityMaskManager autoload

The system SHALL include an autoload singleton `EntityMaskManager` that creates a SubViewport (1280×720) with `transparent_bg = true` and a Camera3D rendering only layer 2 (`cull_mask = 0b10`). The mask camera SHALL synchronize its transform, projection mode, size, and far clip plane with the main scene Camera3D every `_process()` frame. The SubViewport texture SHALL be assigned to the `entity_mask` uniform on the post-process shader material.

#### Scenario: Mask camera follows main camera

- **WHEN** the main Camera3D pans, zooms, or rotates
- **THEN** the mask Camera3D SHALL match the main camera's position, rotation, `size` (orthogonal), and `far` within the same frame

#### Scenario: Mask renders only layer 2 geometry

- **WHEN** the scene contains entities on layer 2 and terrain on layer 1
- **THEN** the mask texture SHALL show white pixels at entity positions and transparent (zero alpha) elsewhere

#### Scenario: Mask resolution is 1280×720

- **WHEN** the EntityMaskManager initializes
- **THEN** the SubViewport SHALL have width 1280 and height 720