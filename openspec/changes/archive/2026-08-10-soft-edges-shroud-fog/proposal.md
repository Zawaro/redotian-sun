## Why

Shroud and fog cells render with hard, crisp cell boundaries (#274). Two prior attempts — a full signed-distance-field texture and a boundary-ribbon mesh — were reverted for look/perf, leaving hard edges as shipped behavior. The edge of vision reads as a harsh step instead of a soft ramp, which hurts readability when the reveal frontier moves under camera pan/zoom.

## What Changes

- Render soft transition bands between shroud → fog → visible: each region's interior stays flat (opaque black for shroud, `fog_darkness` for fog), and only the boundaries soften over a tunable width.
- Make the shroud boundary read ~0.5 cell larger with a ~1.5-cell smoothstep, hiding the opaque sheet's crisp edge beneath the translucent band's solid zone.
- Erode the opaque shroud sheet by one cell so its hard edge can never surface through the soft band.
- Bake a tiny 2-channel RG8 edge-mask (Chebyshev ring distances to shroud and fog sets) on the existing state-change event — no per-frame CPU cost, no extra draw call.
- Re-bake the edge mask **incrementally**: only the band of cells around actually-changed cells (dilated by `MASK_MAX_RING`) is recomputed, on a persistent texture updated in place via `ImageTexture.update()` — the 0.25s tick no longer re-allocates textures or recomputes the full grid.
- Make the 60Hz paths allocation-free: revealer shadowcasting walks lines in place (no per-cell arrays), `_allied_player_ids` is cached per player with live validation, and enemy-building visibility is maintained on the `state_changed` event instead of a per-frame poll.
- Fix a latent `DebugMenu` fog/shroud toggle bug (wrong `bind` argument order) that prevented toggling fog at runtime.

## Capabilities

### New Capabilities
<!-- None — the soft-edge behavior is realized within the existing fog-rendering capability. -->

### Modified Capabilities
- `fog-rendering`: The "Soft-edged shroud and fog borders" requirement (currently an OPEN GAP #274) is realized: the fog overlay gains soft, tunable transition bands between shroud/fog/visible while keeping shroud interiors opaque and fog interiors flat, with the single-draw / no-per-frame-CPU-bake constraints the spec mandates. The bake is incremental (band-only, persistent textures) and building culling is event-driven rather than per-frame.

## Impact

- `scripts/core/FogRenderer.gd`: edge-mask bake (`_bake_edge_mask` → `_init_textures` / `_update_edge_mask` / `_ring_distance` / `_sweep_dist`), persistent grid + mask textures with `ImageTexture.update()`, grow/falloff uniforms, `grid_texel` for erosion taps, event-driven building sync (`_sync_buildings`), fog-plane visibility now covers shroud-on/fog-off default.
- `scripts/core/ShroudSystem.gd`: `state_changed(dirty)` signal, `get_cell_effective_state`, cached `_allied_player_ids`, zero-alloc inlined Bresenham reachability.
- `shaders/maps/FogOfWarPlane.gdshader`: samples `edge_mask` (filter_linear), computes per-region alpha via `max()` of shroud and fog bands.
- `shaders/maps/FogShroudPlane.gdshader`: erodes the opaque footprint by one cell via 4 orthogonal neighbor taps.
- `scripts/ui/DebugMenu.gd`: `_on_fog_toggle` parameter order fixed.
- No scene file changes; both planes share the existing draped mesh.

