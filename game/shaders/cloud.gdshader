shader_type spatial;
// Walkable clouds and cloud puffs: a dense cumulus surface made of billows (cauliflower bumps) that
// catch the light on one side and fall into soft blue-grey valleys, light glowing through the thin
// edges, a silver rim against the sky, and a slow boil. The collision is the plain shape underneath.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert_wrap, specular_disabled;

uniform vec3 top_col : source_color = vec3(0.95, 0.95, 0.96);
uniform vec3 bottom_col : source_color = vec3(0.62, 0.68, 0.82);
uniform vec3 rim_col : source_color = vec3(1.0, 0.96, 0.92);
uniform float wobble = 0.15;
uniform float glow = 0.05;
uniform float billow = 1.0;         // strength of the bumps
uniform float billow_scale = 1.1;   // bumps per metre (roughly)
uniform float lite = 0.0;

varying vec3 wpos;
varying float hmix;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
// billowed fbm: rounded lumps with creases between them
float billows(vec3 p, int oct) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 4; i++) {
		if (i >= oct) {
			break;
		}
		float n = vnoise(p);
		v += a * (1.0 - abs(n * 2.0 - 1.0));
		p = p * 2.13 + vec3(4.1, 1.3, 7.7);
		a *= 0.48;
	}
	return v;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = vnoise(w * 0.6 + vec3(TIME * 0.15, 0.0, TIME * 0.1));
	VERTEX += NORMAL * (n - 0.5) * wobble;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	hmix = clamp(NORMAL.y * 0.5 + 0.5, 0.0, 1.0);
}

void fragment() {
	int oct = lite > 0.5 ? 2 : 4;
	vec3 p = wpos * billow_scale + vec3(TIME * 0.05, TIME * 0.02, TIME * 0.035);
	float b = billows(p, oct);
	// the lumps bend the normal: gradient of the billow field
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (lite < 0.5) {
		float e = 0.09;
		vec3 g = vec3(billows(p + vec3(e, 0, 0), oct), billows(p + vec3(0, e, 0), oct), billows(p + vec3(0, 0, e), oct)) - b;
		g /= e;
		g -= wn * dot(g, wn);
		wn = normalize(wn - g * 0.16 * billow);
	}
	// valleys between billows are denser and darker, the crowns catch the light
	float crown = smoothstep(0.25, 0.85, b);
	float up = smoothstep(0.2, 0.85, hmix + (b - 0.5) * 0.25);
	vec3 col = mix(bottom_col, top_col, up);
	col *= mix(0.78, 1.02, crown);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	AO = mix(0.72, 1.0, crown);
	AO_LIGHT_AFFECT = 0.25;
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_col * fr * 0.28 + col * glow;
	// light through the thin edges
	BACKLIGHT = vec3(0.42) * (0.6 + 0.4 * (1.0 - crown));
}
