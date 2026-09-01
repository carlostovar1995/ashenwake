shader_type canvas_item;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p) * 2.0;
	float a = 1.0 - smoothstep(0.94, 1.0, r);
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= a;
}
