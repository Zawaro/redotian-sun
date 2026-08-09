## Context

Fog-of-war renders via two planes sharing one draped `ArrayMesh` in `FogRenderer.gd`:
- `FogShroudPlane.gdshader` — opaque black, `depth_draw_opaque`. The depth write is load-bearing: it occludes ground entities in shroud cells without per-instance culling.
- `FogOfWarPlane.gdshader` — translucent dim, `depth_test_disabled`, `render_priority 127` (x-ray, drawn after all opaque).

Both sample one L8 state texture (`0=shroud, 1=fog, 2=visible`) with `filter_nearest`, UVs pinned to world XZ, rebuilt in GDScript only when the effective-state buffer changes (a compare gate) — the sole allowed CPU cost point. Grid is the diamond extent (~100×100 cells).

History: a full SDF/EDT `fog_soft` texture was reverted (look/perf) and a boundary-ribbon mesh was reverted ("didn't work properly"). The spec `fog-rendering` marks soft edges an OPEN GAP (#274) with the constraints: single-draw, no per-frame CPU bake, shroud interiors opaque, fog interiors flat, tunable width.

The smoke-tested approach now shipped in this branch works; this design records the decisions behind it.

## Goals / Non-Goals

**Goals:**
- Soft, tunable transition bands between shroud → fog → visible, with flat interiors.
- The shroud boundary reads ~0.5 cell larger with a ~1.5-cell smoothstep (no crisp core line).
- Zero per-frame CPU cost; bake runs only on the existing state-change event.
- Single draw (no extra geometry pass), world-XZ column pinning preserved, stays below the 2D SelectionOverlay.

**Non-Goals:**
- Re-deriving a general SDF/EDT pipeline (reverted for look/perf in #198).
- Softening interior cell structure — interiors must remain flat and crisp at cell granularity.
- Per-instance shroud culling of entities (a separate open gap, #275/#276); the eroded opaque sheet plus existing culling is sufficient.
- Minimap soft edges or reveal-pulse animations (future work, see "Risks").

## Decisions

### 1. Baked 2-channel ring-distance mask, not a full EDT
`_rebuild_texture` additionally bakes an RG8 `edge_mask`: R = 8-neighbor Chebyshev ring distance to nearest shroud cell, G = to nearest fog cell, via a two-pass Chebyshev distance transform (`_ring_distance`, O(n), 8 compares/cell), clamped to `MASK_MAX_RING = 4`. Uploaded with `filter_linear`.
- **Why over a full SDF:** the two-pass transform is ~80k integer compares per bake vs a full EDT; at 100×100 cells both are sub-millisecond, but the integer ring field is enough — bilinear interpolation of an integer ring field already ramps linearly between texel centers.
- **Why Chebyshev, not Manhattan:** diagonal neighbors count the same as cardinal ones, so the falloff band aligns equally to axes and diagonals — the 45° rotation of a Manhattan diamond. Diagonal cell edges ramp at the same width as cardinal edges (square-cornered grown cell), which reads smoother on diagonal transitions. Cost is 8 vs 4 compares/cell; still O(n).
- **Why over shader-side multi-tap:** one bilinear sample in the fragment shader instead of 4–9 nearest taps per fragment; the CPU bake is event-gated, not per-frame.
- **Why RG8, not bit-packed L8:** nearest filtering is required for crisp state classification (0.5/1.5 thresholds); the side texture keeps the state texture untouched.

### 2. Grow-then-falloff alpha in the fog shader
`FogOfWarPlane.gdshader` computes `alpha = max(shroud_alpha, fog_alpha)` where each is `1 - smoothstep(0.5 + grow, 0.5 + grow + falloff, dist)`, decoded from the mask byte (`* 255`). Defaults: `SHROUD_GROW 0.5`, `SHROUD_FALLOFF 1.5`, `FOG_GROW 0.25`, `FOG_FALLOFF 1.0`.
- **Why grow:** the solid zone extends past the region boundary, so the opaque sheet's crisp edge (at dist 0.5) sits *under* fully-opaque band — the core line vanishes. This is the "shroud cell 1.5× bigger" from the issue.
- **Why `max()` not `min(1, a+b)`:** shroud and fog are mutually exclusive regions; sum saturates a fog cell hugging shroud to black and snaps the next cell to the 0.65 floor — a hard internal step. `max()` fades through the dim floor.
- **Why pinned flat interiors:** covered cells store distance 0; bilinear keeps them at 0 up to the exact cell edge, and `smoothstep` returns 0 there → full intensity across the entire footprint. No 2×2 phantom footprint.

### 3. One-cell erosion of the opaque shroud sheet
`FogShroudPlane.gdshader` samples the 4 orthogonal `fog_grid` neighbors (nearest, `grid_texel` UV offset) and discards any shroud fragment with a non-shroud neighbor.
- **Why:** belt-and-suspenders on the crisp core. Even with grow, the opaque sheet's razor edge would read at its cell line; eroding by one cell pushes that edge ≥1 cell inside the region, permanently under the band's solid zone. Interior shroud cells keep `depth_draw_opaque` occlusion.
- **Why 4 neighbors not 8:** erosion is separate from the band metric — it only needs to retreat the opaque edge ≥1 cell; orthogonal checks suffice and diagonal-only gaps are covered by the band's solid zone anyway.
- Rim fragments (`!in_map`) skip erosion and draw opaque black as before.

### 4. Fog plane visible for shroud-only mode
`_set_plane_visible` now shows the fog plane when *either* shroud or fog is enabled (default game state is shroud on / fog off). The shader gates each band by its own `*_enabled` uniform, so toggle combinations compose correctly.

### 5. Fix DebugMenu toggle bind order
`_on_fog_toggle(pressed, field)` — Godot's `Callable.bind` appends args after the signal's own, so the handler must declare `(pressed: bool, field: StringName)`.

## Risks / Trade-offs

- [Soft band dims entities in fog/visible cells near the boundary] → The fog plane is already x-ray translucent; entities near a shroud edge are dimmed rather than occluded. Per spec this matches fog semantics; the band is narrow (grow 0.5).
- [Eroded opaque sheet leaves a 1-cell rim without depth occlusion] → Entities there are covered by the translucent band plus existing per-instance culling (#275/#276 track the gap); interior shroud cells retain full occlusion.
- [Erosion adds 4 texture taps to the opaque sheet's fragment shader] → Nearest taps on a tiny cache-resident texture; the sheet is the dominant-screen-area pass, so this is the main added GPU cost. If it ever matters, bake erosion into the mask's alpha channel instead.
- [Bilinear banding at convex corners] → The Chebyshev field plus smoothstep shapes it acceptably; pixel-perfect corners would need a 4× texel re-bake (same shader), deferred.
- [Diagonal corners of eroded sheet] → 4-neighbor erosion leaves shroud cells diagonally adjacent to fog drawn by the opaque sheet; the band's solid zone covers the gap, verified in smoke test.
- [Wide-band tunability beyond 4 cells] → `MASK_MAX_RING = 4` bounds the falloff; exceeding it needs a larger ring bake (uniform-driven, no shader change).
