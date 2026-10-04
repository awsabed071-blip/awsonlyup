shader_type spatial;
// Realism layer for imported props: keeps the prop's own base colour (atlas) but drives detail,
// normals, roughness and grime from the surface library; separate families for tops, sides, roofs.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_col : source_color = vec4(1.0);
uniform bool use_tex = true;
uniform float base_rough = 0.8;
uniform float base_metal = 0.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float desat = 0.0;
uniform float lib_color = 0.6;                  // how much the library colour replaces the prop colour

uniform sampler2DArray surf_a : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray surf_n : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float side_layer = 1.0;
uniform float side_tile = 2.0;
uniform float top_layer = 1.0;
uniform float top_tile = 2.0;
uniform float roof_layer = -1.0;
uniform float roof_tile = 2.0;
uniform float detail = 0.8;
uniform float bump = 1.0;
uniform float streaks = 0.4;
uniform float grime = 0.6;
uniform float rough_mix = 0.6;
uniform float lite = 0.0;

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
	vec3 base = albedo_col.rgb;
	if (use_tex) {
		base *= texture(albedo_tex, UV).rgb;
	}
	float l = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(base, vec3(l), desat) * tint;
	vec3 n = normalize(ln);
	float upw = smoothstep(0.62, 0.82, wnrm.y);
	float fl = side_layer;
	float ft = side_tile;
	if (roof_layer >= 0.0 && wnrm.y > 0.2 && wnrm.y < 0.8) {
		fl = roof_layer;
		ft = roof_tile;
	}
	vec4 A;
	vec4 N;
	vec3 on;
	sl_sample(lp, n, fl, ft, bump, true, A, N, on);
	if (upw > 0.01 && top_layer != fl) {
		vec4 A2;
		vec4 N2;
		vec3 on2;
		sl_sample(lp, n, top_layer, top_tile, bump, true, A2, N2, on2);
		A = mix(A, A2, upw);
		N = mix(N, N2, upw);
		on = normalize(mix(on, on2, upw));
	}
	float lum = dot(A.rgb, vec3(0.299, 0.587, 0.114));
	// library colour, re-tinted towards the prop's own hue
	vec3 lib = A.rgb * (base / max(vec3(l), vec3(0.05))) * 0.5 + A.rgb * 0.5;
	vec3 col = mix(base * (0.6 + lum * 0.8), lib, lib_color);
	float cav = sl_cavity(N);
	col *= mix(1.0, cav, grime);
	float rough = mix(base_rough, A.a, rough_mix);
	if (streaks > 0.0 && lite < 0.5) {
		float st = sl_streak(wpos, wnrm);
		col *= 1.0 - st * streaks * 0.3;
	}
	col *= 0.92 + 0.16 * sl_noise(wpos * 0.11);
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = base_metal;
	AO = mix(1.0, cav, 0.8);
	AO_LIGHT_AFFECT = 0.12;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(MODEL_NORMAL_MATRIX * on), 0.0)).xyz);
}
