shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, ambient_light_disabled, fog_disabled, specular_disabled, depth_draw_never, blend_mix;

uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float explode : hint_range(0.0, 1.0) = 0.0;
uniform vec3 fire_color : source_color = vec3(4.416, 1.774, 0.0);
uniform sampler2D fire_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 scroll_speed = vec2(0.1, 3.0);

void fragment() {
	float mask = texture(fire_tex, UV + TIME * scroll_speed).r;
	float ndv = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - ndv, 2.4);
	float a = mask * fade_alpha * mix(1.0, rim, explode);
	if (a < 0.05) {
		discard;
	}
	ALBEDO = fire_color;
	ALPHA = a;
	EMISSION = fire_color;
}
