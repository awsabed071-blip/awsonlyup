shader_type spatial;
// World surfaces for the procedural pieces: real PBR albedo/normal/roughness from the surface library
// (object-space triplanar in metres), a palette tint per material, and weathering: rain streaks down
// walls, worn bevelled edges, grime in cavities, moss/dust on tops, a secondary mask (mortar, rust...).
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 color_a : source_color = vec3(0.5, 0.5, 0.5);
uniform vec3 color_b : source_color = vec3(0.5, 0.5, 0.5);
uniform vec3 top_color : source_color = vec3(0.5, 0.7, 0.3);
uniform float top_amount : hint_range(0.0, 1.0) = 0.0;
uniform float noise_scale = 0.35;
uniform float roughness_v : hint_range(0.0, 1.0) = 0.85;     // roughness offset
uniform float metallic_v : hint_range(0.0, 1.0) = 0.0;
uniform float stripes = 0.0;
uniform float stripe_width = 0.35;
uniform float hazard = 0.0;
uniform float rib = 0.0;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_strength = 0.0;
uniform float pulse = 0.0;
uniform float fresnel_glow = 0.0;

uniform sampler2DArray surf_a : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray surf_n : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float layer = 0.0;
uniform float tile = 2.0;                 // metres per texture tile
uniform float tint_k = 1.0;               // 1: palette drives the colour, 0: library colour
uniform float detail = 1.0;               // contrast of the library albedo
uniform float bump = 1.0;
uniform vec3 mask_color : source_color = vec3(0.5, 0.48, 0.45);
uniform float mask_amount = 0.0;
uniform float mask_rough = 0.9;
uniform float mask_metal = 0.0;
uniform float streaks = 0.0;
uniform float wear = 0.0;
uniform vec3 wear_color : source_color = vec3(1.0, 0.97, 0.9);
uniform float grime = 0.6;
uniform float lite = 0.0;
uniform float top_layer = -1.0;
uniform float top_tile = 2.0;
uniform float top_tint_k = 0.0;

varying vec3 lp;
varying vec3 ln;
varying vec3 wpos;
varying vec3 wnrm;

#include "res://shaders/surf_lib.gdshaderinc"

void vertex() {
	lp = VERTEX * vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	ln = NORMAL;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(ln);
	vec3 an = abs(n);
	vec4 A;
	vec4 N;
	vec3 on;
	sl_sample(lp, n, layer, tile, bump, lite > 0.5, A, N, on);
	float big = sl_noise(wpos * noise_scale * 0.35) * 0.6 + sl_noise(wpos * noise_scale * 1.3 + 7.0) * 0.4;
	vec3 pal = mix(color_a, color_b, clamp(big * 1.2 - 0.1, 0.0, 1.0));
	float tk = tint_k;
	float upf = top_layer >= 0.0 ? smoothstep(0.72, 0.9, n.y) : 0.0;
	if (upf > 0.01) {
		vec4 A2;
		vec4 N2;
		vec3 on2;
		sl_sample(lp, n, top_layer, top_tile, bump, true, A2, N2, on2);
		A = mix(A, A2, upf);
		N = mix(N, N2, upf);
		on = normalize(mix(on, on2, upf));
		tk = mix(tint_k, top_tint_k, upf);
	}
	vec3 col = sl_palette(A.rgb, pal, tk);
	// contrast of the library detail and a slow world-scale variation against tiling
	float lum = dot(A.rgb, vec3(0.299, 0.587, 0.114));
	col *= mix(1.0, 0.5 + lum, (detail - 1.0) * 0.5 + 0.0);
	col *= 0.92 + 0.16 * big;
	float cav = sl_cavity(N);
	col *= mix(1.0, cav, grime);
	float rough = clamp(A.a + (roughness_v - 0.85) * 0.6, 0.04, 1.0);
	float metal = metallic_v;
	float mk = clamp(N.a * mask_amount, 0.0, 1.0);
	col = mix(col, mask_color * (0.7 + lum * 0.6), mk);
	rough = mix(rough, mask_rough, mk);
	metal = mix(metal, mask_metal, mk);

	if (hazard > 0.0 && an.y < 0.5) {
		float h = fract((wpos.x + wpos.y + wpos.z) * 1.2);
		vec3 hz = h < 0.5 ? vec3(0.95, 0.75, 0.1) : vec3(0.08, 0.08, 0.08);
		col = mix(col, hz * (0.8 + lum * 0.4), hazard);
	}
	if (streaks > 0.0) {
		float st = sl_streak(wpos, wnrm);
		col *= 1.0 - st * streaks * 0.35;
		rough = min(1.0, rough + st * streaks * 0.1);
	}
	if (wear > 0.0) {
		float edge = 1.0 - max(an.x, max(an.y, an.z));
		float wm = smoothstep(0.08, 0.26, edge) * (0.55 + 0.45 * lum);
		col = mix(col, col * wear_color * 1.35, wm * wear);
		rough = mix(rough, rough * 0.8, wm * wear);
	}
	float up = smoothstep(0.55, 0.85, wnrm.y);
	if (top_amount > 0.0) {
		float tn = sl_noise(wpos * 1.3 + 7.0) * 0.6 + (1.0 - cav) * 0.8 + N.a * 0.3;
		float topmask = clamp(up * top_amount * (0.55 + tn), 0.0, 1.0);
		col = mix(col, top_color * (0.8 + lum * 0.4), topmask);
		rough = mix(rough, 0.95, topmask);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	AO = mix(1.0, cav, 0.85);
	AO_LIGHT_AFFECT = 0.15;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(MODEL_NORMAL_MATRIX * on), 0.0)).xyz);
	vec3 em = emission_color * emission_strength;
	if (pulse > 0.0) {
		em *= 0.6 + 0.4 * sin(TIME * pulse);
	}
	if (fresnel_glow > 0.0) {
		float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		em += emission_color * fr * fresnel_glow;
	}
	EMISSION = em;
}
