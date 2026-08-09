## Why

Shroud and fog cells render with hard, crisp cell boundaries (#274). Two prior attempts — a full signed-distance-field texture and a boundary-ribbon mesh — were reverted for look/perf, leaving hard edges as shipped behavior. The edge of vision reads as a harsh step instead of a soft ramp, which hurts readability when the reveal frontier moves under camera pan/zoom.

## What Changes

- Render soft transition bands between shroud → fog → visible: each region's interior stays flat (opaque black for shroud, `fog_darkness` for fog), and only the boundaries soften over a tunable width.
- Make the shroud boundary read ~0.5 cell larger with a ~1.5-cell smoothstep, hiding the opaque sheet's crisp edge beneath the translucent band's solid zone.
- Erode the opaque shroud sheet by one cell so its hard edge can never surface through the soft band.
- Bake a tiny 2-channel RG8 edge-mask (von-Neumann ring distances to shroud and fog sets) on the existing state-change event — no per-frame CPU cost, no extra draw call.
- Fix a latent `DebugMenu` fog/shroud toggle bug (wrong `bind` argument order) that prevented toggling fog at runtime.

## Capabilities

### New Capabilities
<!-- None — the soft-edge behavior is realized within the existing fog-rendering capability. -->

### Modified Capabilities
- `fog-rendering`: The "Soft-edged shroud and fog borders" requirement (currently an OPEN GAP #274) is realized: the fog overlay gains soft, tunable transition bands between shroud/fog/visible while keeping shroud interiors opaque and fog interiors flat, with the single-draw / no-per-frame-CPU-bake constraints the spec mandates.

## Impact

- `scripts/core/FogRenderer.gd`: edge-mask bake (`_bake_edge_mask`, `_ring_distance`), grow/falloff uniforms, `grid_texel` for erosion taps, fog-plane visibility now covers shroud-on/fog-off default.
- `shaders/maps/FogOfWarPlane.gdshader`: samples `edge_mask` (filter_linear), computes per-region alpha via `max()` of shroud and fog bands.
- `shaders/maps/FogShroudPlane.gdshader`: erodes the opaque footprint by one cell via 4 orthogonal neighbor taps.
- `scripts/ui/DebugMenu.gd`: `_on_fog_toggle` parameter order fixed.
- No scene file changes; both planes share the existing draped mesh.
