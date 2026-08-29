shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_add, depth_draw_never;

uniform vec4 color : source_color = vec4(0.82, 0.94, 1.0, 0.28);

void fragment() {
	float x = 1.0 - abs(UV.x - 0.5) * 2.0;
	float y = UV.y;
	float body = pow(max(x, 0.0), 1.1) * smoothstep(0.0, 0.2, y) * smoothstep(1.0, 0.25, y);
	ALBEDO = color.rgb;
	ALPHA = body * color.a;
	EMISSION = color.rgb * 0.35;
}
