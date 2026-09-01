shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_add, depth_draw_never;

uniform float fade : hint_range(0.0, 1.0) = 1.0;
varying vec4 v_col;

void vertex() {
	v_col = COLOR;
}

void fragment() {
	float edge = 1.0 - abs(UV.y - 0.5) * 2.0;
	edge = max(edge, 0.0);
	float core = pow(edge, 5.4);
	float glow = pow(edge, 2.4);
	float flicker = 0.78 + 0.22 * sin(TIME * 58.0 + UV.x * 22.0);
	vec3 col = v_col.rgb * (glow * 0.45 + core * 2.6) * flicker;
	ALBEDO = col;
	ALPHA = (glow * 0.28 + core) * fade * v_col.a;
	EMISSION = col * (1.25 + core * 1.4);
}

