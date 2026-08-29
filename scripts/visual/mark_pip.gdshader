shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear;
uniform vec4 tint : source_color = vec4(1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 overlay_color : source_color = vec4(0.04, 0.05, 0.08, 0.72);

void vertex() {
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

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	float a = tex.a * tint.a;
	if (a < 0.02) {
		discard;
	}
	vec2 p = UV - vec2(0.5);
	float ang = atan(p.x, -p.y);
	if (ang < 0.0) {
		ang += TAU;
	}
	float mask = 0.0;
	if (progress >= 0.998) {
		mask = 1.0;
	} else if (progress > 0.002) {
		float cut = progress * TAU;
		mask = 1.0 - smoothstep(cut - 0.05, cut + 0.05, ang);
	}
	vec3 rgb = tex.rgb * tint.rgb;
	ALBEDO = mix(rgb, overlay_color.rgb, overlay_color.a * mask);
	ALPHA = a;
}
