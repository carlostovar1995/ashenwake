shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix, depth_draw_never;

uniform vec4 ice_color : source_color = vec4(0.35, 0.92, 1.0, 0.88);
uniform vec4 crack_color : source_color = vec4(0.96, 1.0, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.12, 0.42, 0.82, 0.95);
uniform float grow : hint_range(0.0, 1.0) = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.4;

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
		p *= 2.07;
		a *= 0.5;
	}
	return v;
}

float voronoi_edge(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float md = 8.0;
	float nd = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + vec2(19.1, 7.3)));
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md) {
				nd = md;
				md = d;
			} else if (d < nd) {
				nd = d;
			}
		}
	}
	return abs(sqrt(nd) - sqrt(md));
}

void fragment() {
	vec2 uv = UV;
	float n = fbm(uv * vec2(9.0, 6.5));
	float n2 = fbm(uv * vec2(22.0, 16.0) + 5.1);

	float teeth = abs(fract(uv.x * 13.0 + n * 0.55) - 0.5) * 2.0;
	float rim = 0.78 + n * 0.10 + (1.0 - teeth) * 0.18 + n2 * 0.04;
	if (uv.y > rim) {
		discard;
	}

	float side_teeth = 0.018 + 0.045 * n2 + 0.03 * abs(sin(uv.y * 31.0 + n * 8.0));
	float side = min(uv.x, 1.0 - uv.x);
	if (side < side_teeth * uv.y) {
		discard;
	}

	float grown = 1.0 - smoothstep(grow - 0.12, grow + 0.015, uv.y);
	grown *= smoothstep(0.0, 0.03, grow);

	float leading = 1.0 - smoothstep(0.0, 0.09, abs(uv.y - grow));
	leading *= step(uv.y, grow + 0.02) * grown;

	float cracks = 1.0 - smoothstep(0.012, 0.085, voronoi_edge(uv * vec2(14.0, 10.0)));
	float hair = 1.0 - smoothstep(0.01, 0.06, voronoi_edge(uv * vec2(28.0, 20.0) + 2.4));
	cracks = max(cracks, hair * 0.7);
	cracks *= smoothstep(0.03, 0.16, uv.y) * grown;
	cracks *= 0.82 + 0.18 * sin(TIME * 9.0 + n * 12.0);

	float frost = mix(0.28, 0.9, n) * grown;
	vec3 col = mix(edge_color.rgb, ice_color.rgb, frost);
	col = mix(col, crack_color.rgb, cracks);
	col += crack_color.rgb * leading * 1.35;

	float fill = (0.22 + frost * 0.55 + cracks * 0.85 + leading * 0.55) * fade;
	fill *= ice_color.a;
	fill *= smoothstep(0.0, 0.05, side);

	ALBEDO = col * (1.55 + cracks * 2.4 + leading * 1.8);
	ALPHA = clamp(fill, 0.0, 1.0) * opacity;
	EMISSION = col * (0.8 + cracks * 2.0 + leading * 1.6) * opacity;
}
