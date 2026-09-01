shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_add, depth_draw_never;

uniform vec4 color : source_color = vec4(0.45, 0.92, 1.0, 0.85);

void fragment() {
	float x = 1.0 - abs(UV.x - 0.5) * 2.0;
	float y = UV.y;
	float body = pow(max(x, 0.0), 1.45);
	body *= smoothstep(0.0, 0.08, y) * smoothstep(1.0, 0.35, y);
	float core = pow(max(x, 0.0), 3.2) * (1.0 - y * 0.55);
	vec3 col = color.rgb * (0.85 + core * 1.6);
	ALBEDO = col;
	ALPHA = (body * 0.75 + core * 0.5) * color.a;
	EMISSION = col * 2.4;
}
