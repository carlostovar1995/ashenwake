shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix, depth_draw_never, fog_disabled;

uniform vec4 core_color : source_color = vec4(0.03, 0.045, 0.11, 0.78);
uniform vec4 rim_color : source_color = vec4(0.1, 0.14, 0.24, 0.0);
uniform float darkness : hint_range(0.0, 1.0) = 1.0;
uniform float falloff : hint_range(0.6, 2.5) = 1.35;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p) * 2.0;
	if (d >= 1.0) {
		discard;
	}

	float t = pow(1.0 - d, falloff);
	vec3 col = mix(rim_color.rgb, core_color.rgb, t);
	float alpha = mix(rim_color.a, core_color.a, t);
	alpha *= 1.0 - smoothstep(0.96, 1.0, d);

	ALBEDO = col;
	ALPHA = clamp(alpha * darkness, 0.0, 0.84);
	EMISSION = col * (0.03 + t * 0.1) * darkness;
}
