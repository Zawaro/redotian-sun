shader_type canvas_item;

uniform float blur_strength : hint_range(0.1, 20.0) = 2.0;
uniform float blur_boost : hint_range(1.0, 10.0) = 2.5;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // white glow

void fragment() {
	vec2 resolution = vec2(textureSize(TEXTURE, 0));
	vec2 uv = UV;

	vec4 color = vec4(0.0);
	float total = 0.0;

	int radius = int(blur_strength);

	for (int x = -radius; x <= radius; x++) {
		for (int y = -radius; y <= radius; y++) {
			vec2 offset = vec2(float(x), float(y)) / resolution;
			float weight = exp(-(float(x * x + y * y)) / (2.0 * blur_strength * blur_strength));
			color += texture(TEXTURE, uv + offset) * weight;
			total += weight;
		}
	}

	COLOR = (color / total) * blur_boost * tint_color;
}
