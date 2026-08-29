shader_type spatial;
render_mode unshaded, blend_mix, cull_back, shadows_disabled, depth_draw_always;

uniform vec4 tint_color : source_color = vec4(1.0, 0.25, 0.08, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - ndv, 2.2);
	float fill = 0.32 + rim * 0.68;
	ALBEDO = tint_color.rgb;
	ALPHA = fill * strength * tint_color.a;
	EMISSION = tint_color.rgb * (0.45 + rim * 1.6) * strength;
}
