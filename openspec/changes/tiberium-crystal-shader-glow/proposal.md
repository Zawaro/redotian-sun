## Why

Tiberium crystals were flat-colored BoxMesh boxes with no visual distinction. The original Tiberian Sun had luminous tiberium that illuminated its surroundings. StandardMaterial3D with emission washed out the crystal color and couldn't decouple object appearance from environmental illumination. A custom unlit shader, OmniLight3D, particle effects, and billboard glow were needed to achieve the correct look.

## What Changes

- Custom unlit crystal shader with Y-gradient, fresnel, noise variation, and emission pulse
- OmniLight3D per crystal for environmental illumination (light_cull_mask excludes crystal mesh)
- GPUParticles3D for green sparkle effects floating upward
- Billboard Sprite3D with radial gradient for soft glow aura
- ArtData gains emission fields and point light fields for data-driven control
- ResourceComponent reads ArtData and spawns all visual elements
- WorldEnvironment glow tuned for visible bloom

## Capabilities

### New Capabilities
- `tiberium-crystal-rendering`: Custom shader, particles, glow aura, and point light for tiberium crystal entities
- `artdata-visual-controls`: ArtData emission and point light fields for data-driven visual properties

### Modified Capabilities
- `tiberium-art-placeholder`: Crystal material changed from StandardMaterial3D to custom ShaderMaterial; visual nodes now include particles, glow sprite, and point light

## Impact

- **New files**: `shaders/entities/tiberium_crystal.gdshader`, `resources/art/terrain/tiberium_crystal_art.tres`
- **Modified**: `ResourceComponent.gd` (shader material, particles, glow, light), `ArtData.gd` (emission + point light fields), `ArtComponent.gd` (emission application), `tiberium_crystal.tres` (art_data reference), `DefaultWorldEnvironment01.tscn` (glow tuning)
- **No breaking changes**: All new fields default to disabled/zero; existing entities unaffected
