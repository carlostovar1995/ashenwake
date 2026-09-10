shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix, depth_draw_opaque;

uniform float fade_width = 0.35;
uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform float emission_energy = 3.0;

instance uniform float beam_length = 14.0;
instance uniform vec3 beam_origin = vec3(0.0);
instance uniform vec3 beam_dir = vec3(0.0, 0.0, -1.0);
instance uniform vec4 tint : source_color = vec4(1.0, 0.82, 0.35, 0.85);

varying float along;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	along = dot(world - beam_origin, beam_dir);
}

void fragment() {
	if (along > beam_length) {
		discard;
	}
	vec4 tex = texture(albedo_tex, UV);
	float fade = smoothstep(beam_length, beam_length - fade_width, along);
	vec3 col = tex.rgb * tint.rgb;
	ALBEDO = col;
	ALPHA = tex.a * tint.a * fade;
	EMISSION = col * emission_energy;
}
