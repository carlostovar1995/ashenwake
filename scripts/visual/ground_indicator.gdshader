shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix, depth_draw_never, fog_disabled, specular_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.5, 0.2, 1.0);
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.05;
uniform float outline_alpha : hint_range(0.0, 1.0) = 0.8;
uniform float outline_width : hint_range(0.004, 0.8) = 0.18;
uniform int shape_mode : hint_range(0, 1) = 0;
uniform vec2 quad_size = vec2(1.0, 1.0);

void fragment() {
	float fill = 0.0;
	float ring = 0.0;
	if (shape_mode == 0) {
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		if (r > 1.0) {
			discard;
		}
		float radius = max(quad_size.x, 0.001);
		float w = clamp(outline_width / radius, 0.003, 0.48);
		fill = 1.0 - smoothstep(0.97, 1.0, r);
		ring = smoothstep(1.0 - w - 0.003, 1.0 - w, r) * (1.0 - smoothstep(0.988, 1.0, r));
	} else {
		vec2 d = min(UV, vec2(1.0) - UV) * quad_size;
		float m = min(d.x, d.y);
		fill = 1.0;
		ring = 1.0 - smoothstep(0.0, max(outline_width, 0.01), m);
	}
	float a = fill * fill_alpha + ring * outline_alpha;
	ALBEDO = color.rgb;
	ALPHA = clamp(a * color.a, 0.0, 1.0);
	EMISSION = color.rgb * (0.45 + ring * 1.35);
}
