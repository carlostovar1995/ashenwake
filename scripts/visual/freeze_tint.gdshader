shader_type spatial;
render_mode unshaded, blend_mix, cull_back, shadows_disabled, depth_draw_always;

uniform vec4 tint_color : source_color = vec4(0.62, 0.9, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.88;

void fragment() {
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - ndv, 1.6);
	float fill = 0.62 + rim * 0.38;
	ALBEDO = tint_color.rgb;
	ALPHA = fill * strength * tint_color.a;
	EMISSION = tint_color.rgb * (0.55 + rim * 1.35) * strength;
}
