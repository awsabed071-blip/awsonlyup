shader_type spatial;
// Scrolling stylized waterfall sheet that fades into mist at the bottom.
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
uniform vec3 col : source_color = vec3(0.75, 0.9, 1.0);
uniform float speed = 1.4;
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 uv = UV;
	float streaks = n2(vec2(uv.x * 14.0, uv.y * 3.0 - TIME * speed)) * 0.6 + n2(vec2(uv.x * 30.0, uv.y * 6.0 - TIME * speed * 1.7)) * 0.4;
	float edge = smoothstep(0.0, 0.15, uv.x) * smoothstep(1.0, 0.85, uv.x);
	float fade = 1.0 - smoothstep(0.55, 1.0, uv.y);
	ALBEDO = mix(col, vec3(1.0), streaks * 0.6);
	ALPHA = clamp((0.45 + streaks * 0.5) * edge * fade, 0.0, 1.0);
}
