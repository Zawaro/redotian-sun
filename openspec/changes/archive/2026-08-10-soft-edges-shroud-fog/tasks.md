## 1. Edge mask bake (FogRenderer.gd)

- [x] 1.1 Add `SHROUD_GROW`, `SHROUD_FALLOFF`, `FOG_GROW`, `FOG_FALLOFF`, `MASK_MAX_RING` constants
- [x] 1.2 Implement `_ring_distance(states, target, width, height)` two-pass Chebyshev distance transform clamped to `MASK_MAX_RING`
- [x] 1.3 Implement `_mask_from_dists(width, height)` packing the shroud/fog ring buffers into the RG8 `edge_mask`
- [x] 1.4 Wire `edge_mask` + `fog_grid` textures into `_init_textures`; clear them in `_clear_textures`
- [x] 1.5 Set `shroud_grow`/`shroud_falloff`/`fog_grow`/`fog_falloff` uniforms in `_on_shroud_changed` and `_layout_plane`

## 2. Fog overlay shader (FogOfWarPlane.gdshader)

- [x] 2.1 Add `edge_mask` (filter_linear), `shroud_grow`, `shroud_falloff`, `fog_grow`, `fog_falloff`, `shroud_enabled` uniforms
- [x] 2.2 Compute `shroud_alpha`/`fog_alpha` as `1 - smoothstep(0.5 + grow, 0.5 + grow + falloff, dist)` from decoded mask bytes
- [x] 2.3 Compose with `max()`; discard below alpha 0.003; keep rim `!in_map` discard

## 3. Opaque sheet erosion (FogShroudPlane.gdshader)

- [x] 3.1 Add `grid_texel` uniform and set it in `_layout_plane`
- [x] 3.2 Erode: discard shroud fragments with any non-shroud orthogonal neighbor (clamped taps); keep rim opaque
- [x] 3.3 Verify interior shroud cells still depth-occlude entities (`depth_draw_opaque` intact)

## 4. Fog plane visibility + DebugMenu fix

- [x] 4.1 Update `_set_plane_visible` so the fog plane renders when shroud OR fog is enabled
- [x] 4.2 Fix `_on_fog_toggle` parameter order to `(pressed, field)` for `Callable.bind` append semantics

## 5. Incremental bake + persistent textures (FogRenderer.gd)

- [x] 5.1 ShroudSystem emits the resolved local dirty cell set on `state_changed(dirty)`; only allied-player changes are emitted
- [x] 5.2 `_on_shroud_changed(dirty)` recomputes effective state only for dirty cells via `get_cell_effective_state`
- [x] 5.3 Persistent L8 grid + RG8 mask images updated via `ImageTexture.update()` (no per-tick re-allocation)
- [x] 5.4 `_update_edge_mask` re-bakes only the band around changed cells (dilated by `MASK_MAX_RING`), via `_sweep_dist`
- [x] 5.5 `_ring_distance` refactored to share the exact guarded 2-sweep `_sweep_dist` (fixes east-column/south-row edge artifact)

## 6. Event-driven building culling + allocation-free queries

- [x] 6.1 Replace `FogRenderer._physics_process` per-frame building poll with `_sync_buildings()` on `state_changed` + spawn
- [x] 6.2 Cache `ShroudSystem._allied_player_ids` per player with live team validation (no per-query allocation)
- [x] 6.3 Inline `_bresenham_cells` into `_cell_reachable` (zero-alloc shadowcast; delete `_bresenham_cells`)

## 7. Tests and verification

- [x] 7.1 `test_incremental_edge_mask_matches_full_recompute`: randomized band re-bake equals full `_ring_distance` (scattered + border flips)
- [x] 7.2 `test_grid_image_pixel_roundtrip`: L8 `set_pixel` byte conversion guard
- [x] 7.3 Mask rebuilt on state change (content), unchanged buffer does not rebake; enemy-only resolve leaves local state untouched
- [x] 7.4 Fog toggle flips `rules.fog_of_war` and rebuilds texture (DebugMenu)
- [x] 7.5 Run `redot --headless -s test/run_tests.gd`; run `gdlint` + `gdformat --check` on changed scripts
- [x] 7.6 Visual smoke test in editor: no crisp core line, default shroud-on/fog-off soft edge, fog-on case has no internal hard step
