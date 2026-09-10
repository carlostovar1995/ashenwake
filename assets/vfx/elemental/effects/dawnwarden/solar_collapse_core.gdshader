shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled, specular_disabled, depth_draw_never, blend_mix;

uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float explode : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sun_color : source_color = vec3(3.294, 2.884, 1.697);
uniform float fresnel_power = 4.0;

void fragment() {
	float ndv = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float facing = 1.0 - pow(1.0 - ndv, fresnel_power);
	float rim = pow(1.0 - ndv, mix(1.7, 2.6, explode));
	float a = mix(facing, rim, explode) * fade_alpha;
	if (a < 0.03) {
		discard;
	}
	vec3 col = sun_color * mix(1.0, 1.4, explode);
	ALBEDO = col;
	ALPHA = a;
	EMISSION = col;
}
