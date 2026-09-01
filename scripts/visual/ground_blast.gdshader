shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_add, depth_draw_never, fog_disabled, specular_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.5, 0.15, 1.0);
uniform float grow : hint_range(0.0, 1.0) = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.02) {
		discard;
	}
	float edge = max(grow, 0.02);
	if (r > edge + 0.03) {
		discard;
	}
	float disc = 1.0 - smoothstep(edge - 0.14, edge, r);
	float ring = 1.0 - smoothstep(0.0, 0.07, abs(r - edge * 0.92));
	ring *= step(r, edge + 0.02);
	float core = (1.0 - smoothstep(0.0, 0.26 * edge, r)) * disc;
	vec3 col = mix(rim_color.rgb, core_color.rgb, core);
	float alpha = (disc * 0.2 + ring * 0.55 + core * 0.32) * fade;
	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 1.0);
	EMISSION = col * (0.7 + ring * 1.1 + core * 0.85);
}
