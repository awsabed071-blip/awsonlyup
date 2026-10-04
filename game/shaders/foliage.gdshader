shader_type spatial;
// Trees in the landscape (olive, cypress, pine) drawn with MultiMesh: leaf/bark detail from the
// library, a gentle wind sway, light through the leaves when backlit, per-tree colour variation.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2DArray surf_a : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray surf_n : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 leaf_col : source_color = vec3(0.38, 0.44, 0.3);
uniform vec3 leaf_col2 : source_color = vec3(0.5, 0.55, 0.42);
uniform vec3 bark_col : source_color = vec3(0.36, 0.3, 0.25);
uniform float leaf_layer = 19.0;
uniform float bark_layer = 18.0;
uniform float sway = 0.6;
uniform float lite = 0.0;

varying vec3 lp;
varying vec3 ln;
varying float is_bark;
varying float var_i;

#include "res://shaders/surf_lib.gdshaderinc"

void vertex() {
	is_bark = COLOR.r;
	var_i = INSTANCE_CUSTOM.r;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float ph = TIME * (0.9 + var_i * 0.4) + wp.x * 0.05 + wp.z * 0.04;
	float k = h * h * 0.004 * sway * (1.0 - is_bark * 0.7);
	VERTEX.x += sin(ph) * k;
	VERTEX.z += cos(ph * 0.8) * k * 0.7;
	lp = VERTEX * 2.0;
	ln = NORMAL;
}

void fragment() {
	vec3 n = normalize(ln);
	vec4 A;
	vec4 N;
	vec3 on;
	float lay = is_bark > 0.5 ? bark_layer : leaf_layer;
	sl_sample(lp, n, lay, is_bark > 0.5 ? 1.5 : 1.0, 1.0, true, A, N, on);
	float lum = dot(A.rgb, vec3(0.299, 0.587, 0.114));
	vec3 lc = mix(leaf_col, leaf_col2, clamp(var_i * 0.7 + N.a * 0.5, 0.0, 1.0));
	vec3 col = is_bark > 0.5 ? bark_col : lc;
	col = mix(col * (0.6 + lum * 0.8), A.rgb * (col / max(vec3(dot(col, vec3(0.333))), vec3(0.05))), 0.4);
	col *= mix(1.0, sl_cavity(N), 0.5);
	ALBEDO = col;
	ROUGHNESS = is_bark > 0.5 ? 0.95 : 0.9;
	SPECULAR = 0.25;
	AO = mix(1.0, sl_cavity(N), 0.6);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(MODEL_NORMAL_MATRIX * on), 0.0)).xyz);
	if (is_bark < 0.5) {
		BACKLIGHT = lc * 0.25;
	}
}
