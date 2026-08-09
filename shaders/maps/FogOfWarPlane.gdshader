shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, depth_test_disabled;

// Translucent fog-of-war overlay. Complements FogShroudPlane.gdshader, which
// draws the solid (opaque) shroud cells with depth write (the entity occlusion
// mechanism); this pass carries the fog dim AND the soft transition bands.
//
// Soft edges: a second tiny RG8 `edge_mask` texture (built by FogRenderer on
// the same state-change event as `fog_grid`, no per-frame CPU) stores, per
// cell, the 8-neighbor Chebyshev ring distance to the nearest shroud cell (R
// channel) and to the nearest fog cell (G channel). Diagonal neighbors count
// the same as cardinal ones, so the falloff band aligns equally to axes and
// diagonals. Bilinear filtering of the mask interpolates distance between texel
// centers, so the band ramps across the cell boundary while covered cells stay
// pinned at distance 0 -> full intensity up to their exact edge. Each region's
// alpha is `1 - smoothstep(0.5 + grow, 0.5 + grow + falloff, dist)` — the solid
// zone extends `grow` cells past the region boundary (so the opaque sheet's
// crisp edge hides under it) then fades over `falloff` cells. Flat interiors,
// soft edges only, widths tunable via the `*_grow`/`*_falloff` uniforms without
// a rebake.
//
// depth_test_disabled + high render_priority (set from FogRenderer) draw this
// on top of all 3D entities — the documented x-ray overlay pattern — while the
// 2D SelectionOverlay CanvasLayer still renders above it.
//
// UVs are computed from WORLD-space XZ (MODEL_MATRIX * VERTEX), so the rendered
// pattern is pinned to the map columns no matter where the plane node sits.

uniform sampler2D fog_grid : filter_nearest, repeat_disable;
uniform sampler2D edge_mask : filter_linear, repeat_disable;
uniform vec2 grid_origin = vec2(-100.0, -100.0);
uniform vec2 grid_size = vec2(200.0, 200.0);
uniform float fog_darkness : hint_range(0.0, 1.0) = 0.65;
uniform float shroud_grow : hint_range(0.0, 2.0) = 0.5;
uniform float shroud_falloff : hint_range(0.0, 4.0) = 1.5;
uniform float fog_grow : hint_range(0.0, 2.0) = 0.25;
uniform float fog_falloff : hint_range(0.0, 4.0) = 1.0;
uniform bool fog_enabled = false;
uniform bool shroud_enabled = true;

varying vec2 plane_xz;

void vertex() {
    plane_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
    if (!fog_enabled && !shroud_enabled) {
        discard;
    }
    vec2 uv = (plane_xz - grid_origin) / grid_size;
    bool in_map = uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;
    // Beyond the map square the rim holds no state; it is drawn opaque by the
    // shroud pass, so nothing to do here.
    if (!in_map) {
        discard;
    }
    vec2 mask = textureLod(edge_mask, uv, 0.0).rg;
    float shroud_dist = mask.r * 255.0;
    float fog_dist = mask.g * 255.0;
    float shroud_alpha = shroud_enabled
        ? 1.0 - smoothstep(
            0.5 + shroud_grow, 0.5 + shroud_grow + shroud_falloff, shroud_dist
        ) : 0.0;
    float fog_alpha = fog_enabled
        ? fog_darkness * (1.0 - smoothstep(
            0.5 + fog_grow, 0.5 + fog_grow + fog_falloff, fog_dist
        )) : 0.0;
    // max() not sum: shroud and fog are mutually exclusive regions, so the
    // dominant band wins. Sum would clamp fog cells hugging a shroud edge to
    // full black and snap the next cell to the 0.65 floor — a hard step.
    float alpha = max(shroud_alpha, fog_alpha);
    if (alpha < 0.003) {
        discard;
    }
    ALBEDO = vec3(0.0);
    ALPHA = alpha;
}
