## Why

Shadows are blocky and low-quality when using the orthogonal Camera3D. This is caused by the shadow map being spread across the full camera `far` clip distance (5000 units), while the actual visible gameplay area is only ~500 units. The current DirectionalLight3D settings (PSSM 4-split, angular distance, blur) are designed for perspective cameras, not orthogonal RTS views.

## What Changes

- Reduce `Camera3D.far` from 5000.0 to ~400 units to concentrate shadow resolution on the visible area
- Switch DirectionalLight3D shadow mode from PSSM 4-split to Orthogonal (optimized for orthogonal cameras)
- Set `light_angular_distance` to 0 for perfectly parallel light rays (sharper shadows)
- Reduce `shadow_blur` from 0.9 to 0.1 for crisper shadow edges
- Increase shadow map resolution from default 2048 to 4096 in project settings

## Capabilities

### New Capabilities

- `shadow-rendering`: Configuration of shadow map quality, camera far clip, and directional light shadow settings for orthogonal RTS camera

### Modified Capabilities

(None — this is purely visual configuration, no existing spec-level behavior changes)

## Impact

- **Scenes modified**: `scenes/hud/Camera01.tscn` (far clip), `scenes/environment/DefaultSunLight01.tscn` (shadow mode, angular distance, blur)
- **Project settings**: `project.godot` (shadow map size)
- **Performance**: Minor GPU cost from larger shadow map, offset by reduced object rendering from lower far clip
- **Visual**: Significantly sharper shadows across all gameplay
- **Risk**: Low — purely visual changes, no gameplay logic affected
