shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 color_bottom : source_color = vec4(0.05, 0.3, 0.05, 1.0);
uniform vec4 color_top : source_color = vec4(0.2, 1.0, 0.2, 1.0);
uniform float fresnel_power : hint_range(0.1, 5.0) = 2.0;
uniform float fresnel_intensity : hint_range(0.0, 2.0) = 0.6;
uniform float emission_strength : hint_range(0.0, 5.0) = 1.0;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.15;
uniform float noise_scale : hint_range(0.1, 3.0) = 1.5;
uniform float noise_strength : hint_range(0.0, 0.5) = 0.2;

vec3 hash33(vec3 p3) {
	p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yxx) * p3.zyx);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(
			mix(dot(hash33(i), f),
				dot(hash33(i + vec3(1, 0, 0)), f - vec3(1, 0, 0)), f.x),
			mix(dot(hash33(i + vec3(0, 1, 0)), f - vec3(0, 1, 0)),
				dot(hash33(i + vec3(1, 1, 0)), f - vec3(1, 1, 0)), f.x),
			f.y),
		mix(
			mix(dot(hash33(i + vec3(0, 0, 1)), f - vec3(0, 0, 1)),
				dot(hash33(i + vec3(1, 0, 1)), f - vec3(1, 0, 1)), f.x),
			mix(dot(hash33(i + vec3(0, 1, 1)), f - vec3(0, 1, 1)),
				dot(hash33(i + vec3(1, 1, 1)), f - vec3(1, 1, 1)), f.x),
			f.y),
		f.z);
}

void fragment() {
	vec3 obj_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float y = clamp(obj_pos.y * 0.5 + 0.5, 0.0, 1.0);
	vec4 base_color = mix(color_bottom, color_top, y);

	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), fresnel_power);

	float n = value_noise(obj_pos * noise_scale);
	float variation = 1.0 + (n - 0.5) * noise_strength * 2.0;

	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;

	vec3 final_color = base_color.rgb * variation * pulse;
	float brightness = 1.0 + fresnel * fresnel_intensity;

	ALBEDO = final_color * brightness;
	EMISSION = final_color * emission_strength * pulse;
	ALPHA = 1.0;
}
