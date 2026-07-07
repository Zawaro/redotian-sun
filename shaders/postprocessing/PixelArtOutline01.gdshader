shader_type canvas_item;

uniform sampler2D pixel_texture : repeat_disable, filter_nearest;

void fragment() {
    COLOR = texture(pixel_texture, UV);
}