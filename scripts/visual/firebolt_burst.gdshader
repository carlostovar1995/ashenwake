shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_add, depth_draw_never;

uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.55, 1.0);
uniform vec4 fire_color : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform vec4 rim_color : source_color = vec4(0.72, 0.08, 0.18, 0.95);
uniform float grow : hint_range(0.0, 1.0) = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

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
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.09;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p) * 2.0;
	float ang = atan(p.y, p.x);
	vec2 swirl = vec2(cos(ang + TIME * 1.6), sin(ang + TIME * 1.6)) * d;
	float n = fbm(p * 7.5 + swirl * 0.55 + vec2(TIME * 0.35, 0.0));
	float n2 = fbm(p * 16.0 - swirl * 0.4 + 4.2);

	float petals = 0.055 * (0.45 + n) * abs(sin(ang * 7.0 + n2 * 5.0));
	float edge = max(grow, 0.02) * (1.0 + petals);
	if (d > edge + 0.02) {
		discard;
	}

	float grown = 1.0 - smoothstep(edge - 0.08, edge + 0.01, d);
	grown *= smoothstep(0.0, 0.04, grow);

	float ring = 1.0 - smoothstep(0.0, 0.11, abs(d - grow));
	ring *= step(d, grow + 0.06) * grown;
	ring *= 0.75 + 0.25 * n;

	float core = (1.0 - smoothstep(0.0, 0.32 * max(grow, 0.12), d)) * grown;
	float body = mix(0.2, 0.95, n) * grown * (1.0 - d * 0.35);
	float veins = (1.0 - smoothstep(0.03, 0.12, abs(n2 - 0.52))) * grown * 0.7;

	vec3 col = mix(rim_color.rgb, fire_color.rgb, body);
	col = mix(col, core_color.rgb, core * 0.85 + veins * 0.35);
	col += core_color.rgb * ring * 1.45;
	col += rim_color.rgb * smoothstep(0.72, 1.0, d / max(edge, 0.01)) * 0.45;

	float alpha = (0.22 + body * 0.55 + core * 0.5 + ring * 0.7 + veins * 0.25) * fade;
	alpha *= smoothstep(edge + 0.02, edge - 0.04, d);
	alpha *= fire_color.a;

	ALBEDO = col * (1.35 + core * 1.8 + ring * 1.6);
	ALPHA = clamp(alpha, 0.0, 1.0);
	EMISSION = col * (1.6 + core * 2.8 + ring * 2.4);
}
