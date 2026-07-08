## 1. Camera Configuration

- [x] 1.1 Set `Camera3D.far = 400.0` in `scenes/hud/Camera01.tscn`

## 2. DirectionalLight3D Configuration

- [x] 2.1 Set `directional_shadow_mode = 0` (Orthogonal) in `scenes/environment/DefaultSunLight01.tscn`
- [x] 2.2 Retain `light_angular_distance = 1.1` (soft edges preferred over sharp parallel rays)
- [x] 2.3 Retain `shadow_blur = 0.9` (soft edges preferred over crisp jagged edges)

## 3. Project Settings

- [x] 3.1 Add `rendering/lights_and_shadows/directional_shadow/size = 4096` to `project.godot`

## 4. Verification (Manual - run in Redot editor)

- [x] 4.1 Run game and verify shadows are crisp at all camera positions
- [x] 4.2 Verify terrain at map edges is not clipped by far plane
