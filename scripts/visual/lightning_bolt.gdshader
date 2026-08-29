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
	float core = pow(edge, 3.8);
	float glow = pow(edge, 1.15);
	float flicker = 0.82 + 0.18 * sin(TIME * 42.0 + UV.x * 18.0);
	vec3 col = v_col.rgb * (glow * 0.7 + core * 2.1) * flicker;
	ALBEDO = col;
	ALPHA = (glow * 0.5 + core) * fade * v_col.a;
	EMISSION = col * (1.1 + core);
}

