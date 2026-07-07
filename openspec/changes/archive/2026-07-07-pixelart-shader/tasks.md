## 1. Create shader

- [x] 1.1 Create `shaders/postprocessing/PixelArtPostProcess01.gdshader` with fullscreen quad vertex shader
- [x] 1.2 Implement pixelation via texelFetch block snapping
- [x] 1.3 Implement 4-tap depth-based edge detection
- [x] 1.4 Add entity_mask uniform with filter_nearest
- [x] 1.5 Composite outline with 50% blend where edge × mask > threshold

## 2. Create post-process scene

- [x] 2.1 Create `scenes/components/PixelArtPostProcess01.tscn` with MeshInstance3D + QuadMesh (2×2, flip faces)
- [x] 2.2 Assign the shader material to the QuadMesh

## 3. Create EntityMaskManager autoload

- [x] 3.1 Create `scripts/core/EntityMaskManager.gd` with class_name EntityMaskManager
- [x] 3.2 Create SubViewport (1280×720, transparent_bg) in _ready()
- [x] 3.3 Create Camera3D with cull_mask = 0b10 (layer 2 only)
- [x] 3.4 Implement _process() to sync mask camera to main camera
- [x] 3.5 Push SubViewport texture to shader entity_mask uniform
- [x] 3.6 Handle camera lookup via CameraController reference

## 4. Register autoload and wire scene

- [x] 4.1 Add EntityMaskManager autoload to project.godot
- [x] 4.2 Add PixelArtPostProcess01 instance as child of Camera3D in Camera01.tscn

## 5. Enable entity outlines

- [x] 5.1 Enable render layer 2 on NodBuggy glb mesh children (via SelectComponent._enable_layer_on_mesh_children)
- [x] 5.2 Enable render layer 2 on GDIConYard mesh children (via SelectComponent._enable_layer_on_mesh_children)
- [x] 5.3 Enable render layer 2 on CivilianGuardTower Cube mesh
- [x] 5.4 Enable render layer 2 on TempInfantry01 MeshInstance3D