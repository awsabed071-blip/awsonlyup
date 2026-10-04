shader_type spatial;
// Memories are drawn as warm light: fresnel rim, soft inner glow, gentle shimmer.
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform vec4 tint : source_color = vec4(1.0, 0.78, 0.42, 1.0);
uniform float alpha = 0.0;
uniform float time = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float shimmer = 0.85 + 0.15 * sin(wpos.y * 9.0 - time * 2.4);
	float band = smoothstep(0.0, 1.0, fract(wpos.y * 1.3 - time * 0.35));
	vec3 c = tint.rgb * (0.18 + 1.9 * fr) * shimmer + tint.rgb * 0.08 * band;
	ALBEDO = c * alpha;
}
