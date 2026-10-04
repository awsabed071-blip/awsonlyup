shader_type spatial;
// The hills around the climb: terra rossa soil, dry grass and green patches on the gentle ground,
// pale limestone on the steep ground and on the terrace walls. World-space, from the surface library.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2DArray surf_a : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray surf_n : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float grass_layer = 12.0;
uniform float rock_layer = 11.0;
uniform float wall_layer = 3.0;
uniform vec3 grass_dry : source_color = vec3(0.58, 0.52, 0.34);
uniform vec3 grass_green : source_color = vec3(0.32, 0.4, 0.2);
uniform vec3 soil : source_color = vec3(0.5, 0.35, 0.25);
uniform vec3 rock : source_color = vec3(0.74, 0.7, 0.62);
uniform float lite = 0.0;

varying vec3 wpos;
varying vec3 wnrm;
varying float terrace;

#include "res://shaders/surf_lib.gdshaderinc"

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	terrace = COLOR.r;
}

void fragment() {
	vec3 n = normalize(wnrm);
	float slope = 1.0 - n.y;
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float big = sl_noise(wpos * 0.004) * 0.6 + sl_noise(wpos * 0.017 + 3.0) * 0.4;
	float mid = sl_noise(wpos * 0.06 + 11.0);
	vec3 gcol = mix(grass_dry, grass_green, smoothstep(0.35, 0.7, big));
	gcol = mix(gcol, soil, smoothstep(0.72, 0.86, mid * 0.7 + big * 0.3) * 0.55);
	float scrub = smoothstep(0.62, 0.72, sl_noise(wpos * 0.21 + 5.0)) * smoothstep(0.3, 0.6, sl_noise(wpos * 0.013 + 9.0));
	gcol = mix(gcol, grass_green * 0.7, scrub * 0.3);
	float rockw = smoothstep(0.28, 0.5, slope + (mid - 0.5) * 0.2);
	float wall = clamp(terrace, 0.0, 1.0) * smoothstep(0.15, 0.35, slope);
	float fade = 1.0 - smoothstep(120.0, 700.0, dist);
	vec4 A = vec4(0.5, 0.5, 0.5, 0.9);
	vec4 N = vec4(0.5, 0.5, 0.5, 0.0);
	vec3 on = n;
	if (fade > 0.01) {
		float lay = wall > 0.5 ? wall_layer : (rockw > 0.5 ? rock_layer : grass_layer);
		float til = wall > 0.5 ? 3.2 : (rockw > 0.5 ? 6.0 : 3.0);
		sl_sample(wpos, n, lay, til, 1.0, lite > 0.5 || wall < 0.5, A, N, on);
		A = mix(vec4(0.5, 0.5, 0.5, 0.9), A, fade);
		on = normalize(mix(n, on, fade));
	}
	float lum = dot(A.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(gcol, rock, rockw);
	col = mix(col, rock * 0.95, wall);
	// library colour blended with the biome palette
	col = mix(col * (0.6 + lum * 0.8), A.rgb * (col / max(vec3(dot(col, vec3(0.333))), vec3(0.05))) , 0.45 * fade);
	col *= mix(1.0, sl_cavity(N), 0.6);
	col *= 0.9 + 0.2 * big;
	ALBEDO = col;
	ROUGHNESS = 0.92;
	AO = mix(1.0, sl_cavity(N), 0.7);
	NORMAL = normalize((VIEW_MATRIX * vec4(on, 0.0)).xyz);
}
