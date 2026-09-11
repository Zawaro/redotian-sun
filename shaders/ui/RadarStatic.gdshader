shader_type canvas_item;

// Full-panel CRT static for the radar offline/online transition. `intensity` is
// the overlay's contribution: 0 is fully transparent (no residual static), 1 is
// opaque noise. TIME drives the animation — no CPU noise, no texture upload.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float density : hint_range(16.0, 1024.0) = 64.0;

// Frame index is mixed in as a third hash component (wrapped to keep floats
// precise in long sessions) so every frame is an unrelated pattern rather than
// a shifted copy of the previous one.

float hash3(vec3 p) {
    p = fract(p * vec3(443.897, 441.423, 437.195));
    p += dot(p, p.yzx + 19.19);
    return fract((p.x + p.y) * p.z);
}

void fragment() {
    vec2 grid = floor(UV * density);
    float frame = mod(floor(TIME * 15.0), 256.0);
    float n = hash3(vec3(grid, frame));
    float flicker = 0.85 + 0.15 * hash3(vec3(frame, 7.0, 0.0));
    COLOR = vec4(vec3(n * flicker), intensity);
}
