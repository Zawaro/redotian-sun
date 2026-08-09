## 1. Edge mask bake (FogRenderer.gd)

- [ ] 1.1 Add `SHROUD_GROW`, `SHROUD_FALLOFF`, `FOG_GROW`, `FOG_FALLOFF`, `MASK_MAX_RING` constants
- [ ] 1.2 Implement `_bake_edge_mask(states, extent)` producing an RG8 Image (R = shroud ring distance, G = fog ring distance)
- [ ] 1.3 Implement `_ring_distance(states, target, width, height)` two-pass Manhattan distance transform, clamped to `MASK_MAX_RING`
- [ ] 1.4 Wire `edge_mask` texture into `_rebuild_texture` alongside `fog_grid`; clear it in `_clear_textures`
- [ ] 1.5 Set `shroud_grow`/`shroud_falloff`/`fog_grow`/`fog_falloff` uniforms in `_on_shroud_changed` and `_layout_plane`

## 2. Fog overlay shader (FogOfWarPlane.gdshader)

- [ ] 2.1 Add `edge_mask` (filter_linear), `shroud_grow`, `shroud_falloff`, `fog_grow`, `fog_falloff`, `shroud_enabled` uniforms
- [ ] 2.2 Compute `shroud_alpha`/`fog_alpha` as `1 - smoothstep(0.5 + grow, 0.5 + grow + falloff, dist)` from decoded mask bytes
- [ ] 2.3 Compose with `max()`; discard below alpha 0.003; keep rim `!in_map` discard

## 3. Opaque sheet erosion (FogShroudPlane.gdshader)

- [ ] 3.1 Add `grid_texel` uniform and set it in `_layout_plane`
- [ ] 3.2 Erode: discard shroud fragments with any non-shroud orthogonal neighbor (clamped taps); keep rim opaque
- [ ] 3.3 Verify interior shroud cells still depth-occlude entities (`depth_draw_opaque` intact)

## 4. Fog plane visibility + DebugMenu fix

- [ ] 4.1 Update `_set_plane_visible` so the fog plane renders when shroud OR fog is enabled
- [ ] 4.2 Fix `_on_fog_toggle` parameter order to `(pressed, field)` for `Callable.bind` append semantics

## 5. Tests and verification

- [ ] 5.1 Add/verify `_bake_edge_mask` ring-distance test (known grid: covered=0, ring 1, ring 2, sentinel clamp)
- [ ] 5.2 Add test: mask rebuilt on state change, unchanged buffer does not rebake
- [ ] 5.3 Verify fog toggle flips `rules.fog_of_war` and rebuilds texture (DebugMenu)
- [ ] 5.4 Run `redot --headless -s test/run_tests.gd`; run `gdlint` + `gdformat --check` on changed scripts
- [ ] 5.5 Visual smoke test in editor: no crisp core line, default shroud-on/fog-off soft edge, fog-on case has no internal hard step
