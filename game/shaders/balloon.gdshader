shader_type spatial;
// Hot-air balloon envelope with vertical gores.
uniform vec3 c1 : source_color = vec3(0.95, 0.3, 0.25);
uniform vec3 c2 : source_color = vec3(1.0, 0.85, 0.3);
uniform vec3 c3 : source_color = vec3(0.2, 0.55, 0.85);
uniform float gores = 12.0;
void fragment() {
	float g = floor(UV.x * gores);
	float m = mod(g, 3.0);
	vec3 col = m < 0.5 ? c1 : (m < 1.5 ? c2 : c3);
	float seam = smoothstep(0.0, 0.04, fract(UV.x * gores)) * smoothstep(1.0, 0.96, fract(UV.x * gores));
	ALBEDO = col * (0.8 + 0.2 * seam);
	ROUGHNESS = 0.6;
	BACKLIGHT = col * 0.3;
}
