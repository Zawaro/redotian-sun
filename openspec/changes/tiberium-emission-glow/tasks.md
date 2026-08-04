## 1. Emissive crystal material

- [x] 1.1 Add an `EMISSION_ENERGY` constant (3.0) and a static `_build_material(color)` helper in `ResourceComponent.gd` that sets albedo, enables emission, sets emission to the color, and sets `emission_energy_multiplier`
- [x] 1.2 Update the cached-material path in `_ensure_visual_nodes()` to build the material via `_build_material()` using the resource type color (falling back to the current green default)

## 2. World environment bloom

- [x] 2.1 Retune `DefaultWorldEnvironment01.tscn`: `glow_intensity` to 1.0, add `glow_hdr_threshold = 0.9` and `glow_bloom = 0.2`

## 3. Tests & quality gate

- [x] 3.1 Add a unit test in `test/unit/test_resource_component.gd` asserting `_build_material()` produces an emissive material whose emission and albedo match the input color and whose energy multiplier is >= 3.0
- [x] 3.2 Run gdformat/gdlint and the headless test suite; confirm all tests pass
