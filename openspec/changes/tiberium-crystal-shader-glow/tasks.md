## 1. Custom Crystal Shader

- [x] 1.1 Create `shaders/entities/tiberium_crystal.gdshader` with unshaded render mode, Y-gradient, fresnel, noise variation, and emission pulse
- [x] 1.2 Add hash33 and value_noise functions for procedural noise

## 2. ArtData Visual Controls

- [x] 2.1 Add emission fields to ArtData (emission_enabled, emission_color, emission_energy_multiplier)
- [x] 2.2 Add point light fields to ArtData (point_light_enabled, point_light_color, point_light_energy, point_light_range, point_light_attenuation)
- [x] 2.3 Add doc comments for all new ArtData fields

## 3. ArtComponent Emission

- [x] 3.1 Add `_apply_emission()` helper to ArtComponent
- [x] 3.2 Call `_apply_emission()` in `_load_model()` and `_add_placeholder()`

## 4. ResourceComponent Visual Stack

- [x] 4.1 Replace StandardMaterial3D with ShaderMaterial using crystal shader for tiberium
- [x] 4.2 Set shader uniforms (color_bottom, color_top, emission_strength) from ResourceType color
- [x] 4.3 Assign crystal meshes to rendering layer 2
- [x] 4.4 Add `_spawn_point_light()` with light_cull_mask = 1
- [x] 4.5 Add `_spawn_sparkles()` with GPUParticles3D (6 particles, box emission, zero gravity)
- [x] 4.6 Add `_spawn_glow_sprite()` with billboard Sprite3D and procedural radial gradient
- [x] 4.7 Add `_make_particle_mesh()` and `_make_glow_texture()` helpers

## 5. Resource Files

- [x] 5.1 Create `resources/art/terrain/tiberium_crystal_art.tres` with emission and point light settings
- [x] 5.2 Update `resources/entities/terrain/tiberium_crystal.tres` to reference art_data

## 6. WorldEnvironment

- [x] 6.1 Tune glow_intensity and glow_bloom in DefaultWorldEnvironment01.tscn
