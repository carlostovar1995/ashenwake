shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, specular_disabled, ambient_light_disabled;

uniform vec4 outline_color : source_color = vec4(1.0, 0.92, 0.18, 1.0);
uniform float width : hint_range(0.002, 0.08) = 0.01;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	if (FRONT_FACING) {
		discard;
	}
	ALBEDO = outline_color.rgb;
	ALPHA = 1.0;
}
