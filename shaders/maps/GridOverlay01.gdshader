shader_type spatial;
render_mode unshaded, world_vertex_coords;

uniform float size : hint_range(1.0, 100.0) = 2.0;
uniform vec4 color1 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color2 : source_color = vec4(0.7, 0.7, 0.7, 1.0);

void fragment() {
    vec2 pos = floor(VERTEX.xz / size);
    float pattern_mask = mod(pos.x + mod(pos.y, 2.0), 2.0);
    ALBEDO = mix(color1.rgb, color2.rgb, pattern_mask);
}