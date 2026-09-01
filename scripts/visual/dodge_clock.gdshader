shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled, blend_mix;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ready_color : source_color = vec4(0.58, 0.58, 0.62, 0.92);
uniform vec4 cooldown_color : source_color = vec4(0.20, 0.20, 0.22, 0.94);

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p) * 2.0;
	float circle = 1.0 - smoothstep(0.90, 1.0, r);
	if (circle <= 0.001) {
		discard;
	}
	float ang = atan(p.x, -p.y);
	if (ang < 0.0) {
		ang += TAU;
	}
	float on_cd = 0.0;
	if (progress >= 0.998) {
		on_cd = 1.0;
	} else if (progress > 0.002) {
		float cut = progress * TAU;
		float aa = max(fwidth(length(p)) * 4.0, 0.012);
		on_cd = 1.0 - smoothstep(cut - aa, cut + aa, ang);
	}
	vec4 col = mix(ready_color, cooldown_color, on_cd);
	ALBEDO = col.rgb;
	ALPHA = col.a * circle;
}
