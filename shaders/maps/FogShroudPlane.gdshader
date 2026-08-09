shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, unshaded;

// Opaque solid-shroud pass. Draws every shroud cell (state 0, including the
// off-map rim) as flat black WITHOUT blending — no framebuffer read-modify-write
// on the usually-dominant covered area. Hard cell edges, no blur, no halo.
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
    float state = in_map ? textureLod(fog_grid, uv, 0.0).r * 255.0 : 0.0;
    if (state >= 0.5) {
        discard;
    }
    ALBEDO = vec3(0.0);
}
