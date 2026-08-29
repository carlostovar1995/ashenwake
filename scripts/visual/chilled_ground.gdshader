shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix, depth_draw_never, fog_disabled, specular_disabled;

uniform vec4 frost_color : source_color = vec4(0.62, 0.92, 1.0, 0.85);
uniform vec4 dark_color : source_color = vec4(0.22, 0.48, 0.78, 0.70);
uniform vec4 rim_color : source_color = vec4(0.82, 0.96, 1.0, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.08;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p *= 2.08;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = uv - vec2(0.5);
	float d = length(p) * 2.0;
	if (d > 1.0) {
		discard;
	}

	vec2 swirl = p;
	float ang = atan(p.y, p.x) + TIME * 0.12;
	swirl = vec2(cos(ang), sin(ang)) * d * 0.5;
	float n = fbm(uv * 7.5 + swirl * 1.4 + vec2(TIME * 0.035, 0.0));
	float n2 = fbm(uv * 18.0 - swirl * 0.8 + 3.1);

	float frost = smoothstep(0.32, 0.78, n) * (1.0 - d * 0.22);
	frost *= 0.55 + n2 * 0.45;
	float veins = 1.0 - smoothstep(0.04, 0.14, abs(n2 - 0.52));
	veins *= smoothstep(0.15, 0.55, n) * (1.0 - d * 0.35);

	float rim = smoothstep(0.82, 0.92, d) * (1.0 - smoothstep(0.985, 1.0, d));
	rim *= 0.75 + 0.25 * sin(TIME * 2.4 + d * 8.0);

	vec3 col = mix(dark_color.rgb, frost_color.rgb, 0.35 + frost * 0.65);
	col = mix(col, frost_color.rgb * 1.2, veins * 0.7);
	col = mix(col, rim_color.rgb, rim * 0.85);

	float alpha = (0.58 + frost * 0.28 + veins * 0.22 + rim * 0.55) * fade * opacity;
	alpha *= smoothstep(1.0, 0.90, d);

	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 0.92);
	EMISSION = col * (0.55 + rim * 1.1 + veins * 0.45);
}
