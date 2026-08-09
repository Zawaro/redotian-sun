shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, unshaded;

// Opaque solid-shroud pass. Draws shroud cells (state 0, including the off-map
// rim) as flat black WITHOUT blending — no framebuffer read-modify-write on the
// usually-dominant covered area. The shroud footprint is ERODED by one cell:
// any cell with a non-shroud orthogonal neighbor is discarded, so the sheet's
// hard edge sits at least one cell inside the shroud region where the
// translucent band (FogOfWarPlane) is fully opaque — the crisp core line never
// surfaces. Interior shroud cells keep full opaque coverage.
//
// depth_draw_opaque (NOT depth_draw_never) is required: the opaque pass draws
// front-to-back, so without writing depth the terrain drawn after this sheet
// would overwrite the black. Writing depth also makes the sheet occlude the
// terrain behind it while entities above it (closer) still render on top.
//
// UVs are computed from WORLD-space XZ (MODEL_MATRIX * VERTEX), so the pattern
// is pinned to the map columns regardless of the plane node transform.

uniform sampler2D fog_grid : filter_nearest, repeat_disable;
uniform vec2 grid_origin = vec2(-100.0, -100.0);
uniform vec2 grid_size = vec2(200.0, 200.0);
uniform vec2 grid_texel = vec2(0.01, 0.01);
uniform bool shroud_enabled = true;

varying vec2 plane_xz;

void vertex() {
    plane_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
    if (!shroud_enabled) {
        discard;
    }
    vec2 uv = (plane_xz - grid_origin) / grid_size;
    bool in_map = uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;
    if (in_map) {
        float state = textureLod(fog_grid, uv, 0.0).r * 255.0;
        if (state >= 0.5) {
            discard;
        }
        // Erode: out-of-map neighbors are clamped to the edge texel, which is
        // shroud beyond the map, so rim-adjacent cells are not wrongly discarded.
        vec2 t = grid_texel;
        float n = textureLod(fog_grid, clamp(uv + vec2(0.0, t.y), 0.0, 1.0), 0.0).r * 255.0;
        float s = textureLod(fog_grid, clamp(uv - vec2(0.0, t.y), 0.0, 1.0), 0.0).r * 255.0;
        float e = textureLod(fog_grid, clamp(uv + vec2(t.x, 0.0), 0.0, 1.0), 0.0).r * 255.0;
        float w = textureLod(fog_grid, clamp(uv - vec2(t.x, 0.0), 0.0, 1.0), 0.0).r * 255.0;
        if (n >= 0.5 || s >= 0.5 || e >= 0.5 || w >= 0.5) {
            discard;
        }
    }
    ALBEDO = vec3(0.0);
}
