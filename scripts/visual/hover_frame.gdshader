shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, shadows_disabled, specular_disabled;

uniform vec4 outline_color : source_color = vec4(1.0, 0.92, 0.18, 1.0);
uniform vec2 quad_size = vec2(1.0, 0.24);
uniform float border : hint_range(0.004, 0.08) = 0.016;
uniform bool billboard = true;

void vertex() {
	if (billboard) {
		vec3 cam_x = normalize(INV_VIEW_MATRIX[0].xyz);
		vec3 cam_y = normalize(INV_VIEW_MATRIX[1].xyz);
		vec3 cam_z = normalize(INV_VIEW_MATRIX[2].xyz);
		float sx = length(MODEL_MATRIX[0].xyz);
		float sy = length(MODEL_MATRIX[1].xyz);
		float sz = length(MODEL_MATRIX[2].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(cam_x * sx, 0.0),
			vec4(cam_y * sy, 0.0),
			vec4(cam_z * sz, 0.0),
			MODEL_MATRIX[3]
		);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec2 d = min(UV, vec2(1.0) - UV) * max(quad_size, vec2(0.001));
	if (min(d.x, d.y) > border) {
		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
	} else {
		ALBEDO = outline_color.rgb;
		ALPHA = outline_color.a;
	}
}
