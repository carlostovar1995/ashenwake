shader_type spatial;
render_mode blend_mix, cull_disabled, shadows_disabled, specular_schlick_ggx, unshaded;

uniform vec4 ice_color : source_color = vec4(0.42, 0.9, 1.0, 0.9);
uniform vec4 core_color : source_color = vec4(0.82, 0.98, 1.0, 1.0);
uniform vec4 base_glow : source_color = vec4(0.12, 0.95, 0.58, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 1.6);
	float h = UV.y;
	float core = smoothstep(0.2, 0.95, h);
	float root = 1.0 - smoothstep(0.0, 0.34, h);
	float facet = 0.78 + hash(floor(UV * vec2(7.0, 13.0))) * 0.45;
	vec3 col = mix(ice_color.rgb, core_color.rgb, core * 0.62);
	col = mix(col, base_glow.rgb, root * 0.9);
	col *= facet;
	col += core_color.rgb * (0.16 + fres * 0.55);
	ALBEDO = col;
	ALPHA = clamp((0.66 + fres * 0.24 + root * 0.12) * fade, 0.0, 1.0);
	EMISSION = col * (2.0 + core * 1.1 + root * 2.8 + fres * 1.15) * fade;
}
