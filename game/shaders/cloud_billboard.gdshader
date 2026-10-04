shader_type spatial;
// Far cumulus as soft billboards: a noisy puff with a flat base, bright on the side facing the sun,
// shadowed below. Several overlapping puffs make one cloud. Fog still applies (unshaded).
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform vec3 top_col : source_color = vec3(1.0, 0.95, 0.9);
uniform vec3 bottom_col : source_color = vec3(0.62, 0.64, 0.74);
uniform vec3 sun_dir = vec3(0.3, 0.5, 0.2);     // towards the sun, world space
uniform float opacity = 0.95;

varying float seed;

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * n2(p);
		p = p * 2.03 + vec2(3.1, 7.7);
		a *= 0.5;
	}
	return v;
}
float shape(vec2 p) {
	float e = 1.0 - length(vec2(p.x, (p.y - 0.12) * 1.45));
	e += (fbm(p * 1.7 + seed) - 0.5) * 0.95 + (fbm(p * 4.6 + seed * 1.7 + TIME * 0.01) - 0.5) * 0.35;
	return e * smoothstep(-0.62, -0.38, p.y);
}

void vertex() {
	// face the camera, keep the node's scale
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sc.x, INV_VIEW_MATRIX[1] * sc.y, INV_VIEW_MATRIX[2] * sc.z, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	seed = fract(MODEL_MATRIX[3].x * 0.0137 + MODEL_MATRIX[3].z * 0.0071) * 40.0;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float s = shape(p);
	float dens = smoothstep(0.0, 0.32, s);
	if (dens < 0.003) {
		discard;
	}
	vec3 sv = (VIEW_MATRIX * vec4(normalize(sun_dir), 0.0)).xyz;
	vec2 sl = normalize(sv.xy + vec2(1e-4));
	float s2 = shape(p + sl * 0.16);
	float lightk = clamp(0.6 + (s - s2) * 2.6, 0.0, 1.0);
	float up = smoothstep(-0.55, 0.7, p.y);
	vec3 col = mix(bottom_col, top_col, clamp(lightk * (0.55 + 0.45 * up), 0.0, 1.0));
	// silver edge when the sun is behind the cloud
	float behind = clamp(-sv.z, 0.0, 1.0);
	col += top_col * (1.0 - dens) * behind * 0.6;
	ALBEDO = col;
	ALPHA = dens * opacity;
}
