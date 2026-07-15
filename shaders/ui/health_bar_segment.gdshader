shader_type canvas_item;

uniform float num_segments : hint_range(1.0, 200.0) = 25.0;

void fragment() {
    if (UV.x > COLOR.a) {
        discard;
    }

    vec3 base_color = COLOR.rgb;
    float seg_pos = fract(UV.x * num_segments);
    float is_bottom = step(0.5, UV.y);

    float brightness = mix(1.0, 0.8, seg_pos);
    float bottom_brightness = mix(0.8, 0.6, seg_pos);
    brightness = mix(brightness, bottom_brightness, is_bottom);

    COLOR = vec4(base_color * brightness, 1.0);
}
