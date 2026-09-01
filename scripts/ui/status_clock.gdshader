shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 overlay_color : source_color = vec4(0.02, 0.03, 0.06, 0.62);

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p) * 2.0;
	float circle = 1.0 - smoothstep(0.92, 1.0, r);
	if (circle <= 0.001 || progress <= 0.002) {
		COLOR = vec4(0.0);
		return;
	}
	float ang = atan(p.x, -p.y);
	if (ang < 0.0) {
		ang += TAU;
	}
	float cut = progress * TAU;
	float aa = max(fwidth(length(p)) * 3.0, 0.01);
	float mask = 1.0;
	if (progress < 0.998) {
		mask = 1.0 - smoothstep(cut - aa, cut + aa, ang);
	}
	COLOR = overlay_color * mask * circle;
}
