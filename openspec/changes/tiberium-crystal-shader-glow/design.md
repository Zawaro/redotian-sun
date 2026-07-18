## Context

Tiberium crystals were placeholder BoxMesh clusters with StandardMaterial3D. The material was flat green with no visual interest. Emission on StandardMaterial3D washed out the crystal color because it adds brightness to the albedo. OmniLight3D was added for environmental illumination but also affected the crystal itself. The crystal shader approach (unlit, fresnel, noise) is the industry standard for rendering crystals/gems in games.

## Goals / Non-Goals

**Goals:**
- Custom unlit shader that ignores scene lighting (crystal keeps its color)
- Y-gradient for depth (base darker, top brighter)
- Fresnel effect for edge glow
- Noise variation for organic surface
- Animated emission pulse for breathing glow
- OmniLight3D for terrain illumination (excluded from crystal via light_cull_mask)
- Green sparkle particles floating upward
- Billboard glow aura for soft halo effect
- All properties controllable via ArtData .tres files

**Non-Goals:**
- Crystal growth/harvest animations (deferred)
- Per-pixel emission textures (deferred)
- Particle effects beyond sparkles (deferred)

## Decisions

### 1. Custom shader over StandardMaterial3D

StandardMaterial3D emission adds brightness to albedo, washing out the crystal color. A custom unlit shader gives full control: crystal appearance independent of scene lighting, with emission only for bloom trigger.

### 2. light_cull_mask to separate crystal from light

Crystal meshes on layer 2, OmniLight3D light_cull_mask = 1. Light illuminates terrain but not the crystal itself. Crystal keeps perfect albedo color.

### 3. Procedural glow texture

64x64 radial gradient generated at runtime. No external texture asset needed. Soft falloff from center to edge.

### 4. GPUParticles3D with zero gravity

Particles emit upward from a box covering the cell area. Zero gravity keeps them floating. Short lifetime, small size, subtle effect.

## Risks / Trade-offs

- **Shader compilation** — First frame may stutter as shader compiles. Acceptable for tiberium (created at spawn time, not mid-combat).
- **Particle count** — 6 particles per crystal. With many crystals on screen, particle count could grow. Keep amount low.
- **Billboard overdraw** — Billboard glow sprite adds overdraw. Keep alpha low (0.25) and scale reasonable.
