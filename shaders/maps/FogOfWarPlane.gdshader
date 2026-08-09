shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, depth_test_disabled;

// Translucent fog-of-war overlay. Complements FogShroudPlane.gdshader, which
// draws the solid (opaque) shroud cells; this pass carries only the fog layer
// (state 1) as a flat `fog_darkness` dim with hard cell edges — no blur, no
// halo. Shroud cells (state 0) and visible cells (state 2) are discarded.
//
// depth_test_disabled + high render_priority (set from FogRenderer) draw this
// on top of all 3D entities — the documented x-ray overlay pattern — while the
// 2D SelectionOverlay CanvasLayer still renders above it.
//
// Samples the grid-resolution L8 state texture (0 = shroud, 1 = fog, 2 =
// visible) with nearest filtering, so cell boundaries stay crisp.
//
// UVs are computed from WORLD-space XZ (MODEL_MATRIX * VERTEX), so the rendered
// pattern is pinned to the map columns no matter where the plane node sits.

uniform sampler2D fog_grid : filter_nearest, repeat_disable;
uniform vec2 grid_origin = vec2(-100.0, -100.0);
uniform vec2 grid_size = vec2(200.0, 200.0);
uniform float fog_darkness : hint_range(0.0, 1.0) = 0.65;
uniform bool fog_enabled = false;

varying vec2 plane_xz;

void vertex() {
    plane_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
    if (!fog_enabled) {
        discard;
    }
    vec2 uv = (plane_xz - grid_origin) / grid_size;
    bool in_map = uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;
    // Beyond the map square the rim holds no state; it is drawn opaque by the
    // shroud pass, so nothing to do here.
    float state = in_map ? textureLod(fog_grid, uv, 0.0).r * 255.0 : 0.0;
    if (state < 0.5 || state >= 1.5) {
        discard;
    }
    ALBEDO = vec3(0.0);
    ALPHA = fog_darkness;
}
