shader_type canvas_item;

uniform vec4 color_0 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_1 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_2 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_3 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float split_0 : hint_range(0.0, 1.0) = 1.0;
uniform float split_1 : hint_range(0.0, 1.0) = 1.0;
uniform float split_2 : hint_range(0.0, 1.0) = 1.0;
uniform float band_count = 1.0;
uniform vec2 control_size = vec2(96.0, 32.0);

varying float local_y;

void vertex() {
	local_y = VERTEX.y / max(control_size.y, 1.0);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV) * COLOR;
	vec3 tone = color_0.rgb;
	if (band_count >= 3.5 && local_y >= split_2) {
		tone = color_3.rgb;
	} else if (band_count >= 2.5 && local_y >= split_1) {
		tone = color_2.rgb;
	} else if (band_count >= 1.5 && local_y >= split_0) {
		tone = color_1.rgb;
	}
	COLOR.rgb = src.rgb * tone;
	COLOR.a = src.a;
}
