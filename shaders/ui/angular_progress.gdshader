shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 overlay_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);

void fragment() {
	vec2 dir = UV - vec2(0.5);
	float angle = atan(-dir.x, dir.y);
	float norm = (angle + PI) / (2.0 * PI);

	if (norm <= progress) {
		COLOR = vec4(0.0);
	} else {
		COLOR = overlay_color;
	}
}
