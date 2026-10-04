shader_type spatial;
// Endless sea of clouds seen from above (and a soft ceiling from below).
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled, shadows_disabled;

uniform vec3 top_col : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 shade_col : source_color = vec3(0.68, 0.74, 0.86);
uniform vec3 under_col : source_color = vec3(0.62, 0.66, 0.74);
uniform float scale = 0.012;
uniform float speed = 0.004;
uniform float fade_near = 30.0;
// openings where the route climbs through the cloud layer (xz = position, w = radius)
uniform vec4 holes[48];
uniform int hole_count = 0;

varying vec3 wpos;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}
float fbm2(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * n2(p);
		p = p * 2.03 + vec2(3.1, 1.7);
		a *= 0.5;
	}
	return v;
}

float hole_dist(vec2 p) {
	// signed distance to the nearest opening edge (negative inside)
	float d = 1e6;
	for (int i = 0; i < 48; i++) {
		if (i >= hole_count) break;
		d = min(d, length(p - holes[i].xy) - holes[i].w);
	}
	return d;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = wpos.xz * scale + vec2(TIME * speed, TIME * speed * 0.6);
	float h = fbm2(uv);
	// the cloud surface dips away around the openings instead of hanging at eye level
	float hd = hole_dist(wpos.xz);
	float rim = smoothstep(0.0, 40.0, hd);
	VERTEX.y += (h - 0.5) * 22.0 * rim - (1.0 - rim) * 14.0;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz * scale + vec2(TIME * speed, TIME * speed * 0.6);
	float h = fbm2(uv);
	float h2 = fbm2(uv * 3.1 + 5.0);
	float lit = smoothstep(0.25, 0.8, h + (h2 - 0.5) * 0.3);
	vec3 col = mix(shade_col, top_col, lit);
	if (!FRONT_FACING) {
		col = under_col * (0.8 + 0.2 * h2);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	EMISSION = col * 0.25;
	float d = length(CAMERA_POSITION_WORLD - wpos);
	float open_a = smoothstep(0.0, 18.0, hole_dist(wpos.xz) + (h2 - 0.5) * 14.0);
	ALPHA = min(clamp(d / fade_near, 0.0, 1.0), open_a);
	ALPHA_SCISSOR_THRESHOLD = 0.02;
}
