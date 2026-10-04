shader_type sky;
// Physically-inspired sky: analytic Rayleigh + Mie single scattering (Kasten air mass), sun disc,
// a real moon with phase (sphere lit by the sun), stars with a milky band, cumulus and cirrus layers,
// and a haze band that ties the sky into the fog at the horizon. Driven by environment_manager.gd.
uniform vec3 zenith : source_color = vec3(0.25, 0.48, 0.85);      // tint of the scattered light (zenith)
uniform vec3 horizon : source_color = vec3(0.82, 0.88, 0.95);     // tint near the horizon
uniform vec3 ground : source_color = vec3(0.55, 0.6, 0.62);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 haze_col : source_color = vec3(0.9, 0.75, 0.6);
uniform float haze = 0.6;
uniform float turbidity = 2.5;          // 1 = clear, 6 = hazy
uniform float sun_size = 0.03;
uniform float sun_glow = 0.35;
uniform float exposure = 1.0;
uniform float stars = 0.0;              // 0..1 night strength
uniform float cloud_amount = 0.45;
uniform vec3 cloud_col : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 moon_dir = vec3(0.3, 0.5, -0.8);
uniform float moon_visible = 0.0;
uniform float moon_size = 0.018;
uniform float crescent = 0.0;           // kept for compatibility (moon visibility)
uniform float lite = 0.0;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}
float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}
float fbm2(vec2 p, int oct) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 6; i++) {
		if (i >= oct) {
			break;
		}
		v += a * n2(p);
		p = p * 2.07 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}
// Kasten & Young relative optical air mass from the cosine of the zenith angle
float air_mass(float cos_z) {
	float z = acos(clamp(cos_z, -1.0, 1.0)) * 57.29578;
	return 1.0 / (max(cos_z, 0.0) + 0.50572 * pow(max(96.07995 - z, 0.001), -1.6364));
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 sd = normalize(LIGHT0_DIRECTION);
	float sdot = dot(d, sd);
	float sun_h = sd.y;
	// --- scattering ---
	vec3 beta_r = vec3(5.8e-3, 13.5e-3, 33.1e-3) * 1.2;       // per-channel Rayleigh (scaled units)
	vec3 beta_m = vec3(4.0e-3) * turbidity * 0.5;
	float cos_t = sdot;
	float phase_r = 3.0 / (16.0 * 3.14159) * (1.0 + cos_t * cos_t);
	float g = 0.76;
	float phase_m = 3.0 / (8.0 * 3.14159) * ((1.0 - g * g) * (1.0 + cos_t * cos_t)) / ((2.0 + g * g) * pow(1.0 + g * g - 2.0 * g * cos_t, 1.5));
	float m_view = air_mass(max(h, 0.0)) ;
	float m_sun = air_mass(sun_h);
	vec3 ext = beta_r + beta_m;
	vec3 t_view = exp(-ext * m_view * 8.0);
	vec3 t_sun = exp(-ext * m_sun * 8.0);
	float sun_up = smoothstep(-0.12, 0.08, sun_h);
	vec3 sun_rad = sun_tint * mix(0.25, 1.0, sun_up) * (0.3 + 0.7 * LIGHT0_ENERGY) * 6.0;
	vec3 inscatter = sun_rad * (beta_r * phase_r + beta_m * phase_m) / ext * (1.0 - t_view) * t_sun;
	// multiple-scattering ambient: keeps the sky from going black at the zenith
	vec3 ambient = mix(horizon, zenith, pow(clamp(h, 0.0, 1.0), 0.6)) * (0.18 + 0.5 * sun_up) * mix(0.35, 1.0, sun_up);
	vec3 col = inscatter * mix(vec3(1.0), zenith / max(max(zenith.r, zenith.g), max(zenith.b, 0.05)), 0.5) + ambient;
	// haze band that meets the fog at the horizon
	float hz = exp(-max(h, 0.0) * 9.0) * haze;
	col = mix(col, haze_col * (0.5 + 0.5 * sun_up), clamp(hz, 0.0, 1.0));
	if (h < 0.0) {
		col = mix(mix(col, haze_col * (0.5 + 0.5 * sun_up), haze), ground * (0.4 + 0.6 * sun_up), clamp(-h * 4.0, 0.0, 1.0));
	}
	// --- sun disc and glow ---
	float disc = smoothstep(cos(sun_size), cos(sun_size * 0.8), sdot);
	float glow = pow(max(sdot, 0.0), 220.0) * 1.5 + pow(max(sdot, 0.0), 14.0) * sun_glow;
	col += sun_tint * (disc * 14.0 + glow) * LIGHT0_ENERGY * 0.6 * t_sun * sun_up;
	// --- night: stars, milky way, moon ---
	float night = stars * (1.0 - smoothstep(-0.05, 0.15, sun_h));
	if (night > 0.001) {
		vec3 sp = d * 200.0;
		vec3 cell = floor(sp);
		float r = hash3(cell);
		vec3 fp = fract(sp) - 0.5;
		float star = step(0.986, r) * smoothstep(0.2, 0.0, length(fp)) * (0.5 + 0.5 * hash3(cell + 1.3));
		float tw = 0.7 + 0.3 * sin(TIME * (1.0 + r * 5.0) + r * 60.0);
		col += vec3(1.0, 0.97, 0.9) * star * tw * night * 2.4 * smoothstep(-0.05, 0.25, h);
		vec3 band_axis = normalize(vec3(0.3, 0.55, 0.78));
		float band = exp(-pow(dot(d, band_axis) * 2.6, 2.0));
		col += vec3(0.22, 0.2, 0.3) * band * night * 0.35 * (0.3 + fbm2(d.xy * 7.0 + d.z * 3.0, lite > 0.5 ? 3 : 5)) * smoothstep(0.0, 0.2, h);
	}
	if (moon_visible > 0.001) {
		vec3 md = normalize(moon_dir);
		float mdot = dot(d, md);
		float mdisc = smoothstep(cos(moon_size), cos(moon_size * 0.9), mdot);
		if (mdisc > 0.0) {
			// point on the moon sphere and its normal, lit by the sun
			vec3 t = normalize(cross(md, vec3(0.0, 1.0, 0.0)));
			vec3 u = cross(t, md);
			vec3 off = d - md * mdot;
			vec2 uv = vec2(dot(off, t), dot(off, u)) / moon_size;
			float rr = dot(uv, uv);
			vec3 n = normalize(vec3(uv.x, uv.y, -sqrt(max(1.0 - rr, 0.0))));
			// the moon shows the hemisphere facing the sun; the sun is below the horizon at night
			vec3 to_sun = normalize(sd + vec3(0.0, 0.0, 0.0001));
			float lit = clamp(dot(n, -to_sun) , 0.0, 1.0);
			lit = smoothstep(0.02, 0.2, lit);
			float maria = 0.75 + 0.25 * n2(uv * 3.0 + 4.0);
			vec3 moon_c = vec3(1.0, 0.96, 0.88) * maria * (lit * 1.6 + 0.03);
			col = mix(col, moon_c * moon_visible + col * (1.0 - moon_visible), mdisc);
		}
		float mglow = pow(max(mdot, 0.0), 160.0) * 0.6 + pow(max(mdot, 0.0), 20.0) * 0.08;
		col += vec3(0.8, 0.85, 1.0) * mglow * moon_visible * night;
	}
	// --- clouds ---
	if (h > 0.0 && cloud_amount > 0.0 && AT_CUBEMAP_PASS == false) {
		int oct = lite > 0.5 ? 4 : 6;
		vec2 uv = d.xz / (h + 0.1);
		vec2 wind = vec2(TIME * 0.005, TIME * 0.002);
		vec2 cu = uv * 0.8 + wind;
		float base = fbm2(cu * 1.1, oct);
		float det = fbm2(cu * 4.3 + 5.3, oct - 2);
		float cov = 0.64 - cloud_amount * 0.32;
		float dens = smoothstep(cov, cov + 0.3, base * 0.78 + det * 0.3);
		vec2 sdir = normalize(sd.xz + vec2(1e-4));
		float dens2 = smoothstep(cov, cov + 0.3, fbm2((cu + sdir * 0.05) * 1.1, oct - 1) * 0.78 + det * 0.3);
		float lightk = clamp(0.55 + (dens - dens2) * 2.4, 0.0, 1.0);
		vec3 shadow_c = mix(zenith, horizon, 0.5) * (0.12 + 0.5 * sun_up) * (1.0 + night * 0.3);
		vec3 lit_c = mix(horizon, vec3(1.0), 0.4) * mix(vec3(1.0), sun_tint, 0.6) * cloud_col * (0.25 + 0.75 * sun_up);
		vec3 cc = mix(shadow_c, lit_c, lightk);
		cc += sun_tint * pow(max(sdot, 0.0), 8.0) * (1.0 - dens) * 1.6 * LIGHT0_ENERGY * sun_up;
		float fadeh = smoothstep(0.0, 0.1, h);
		col = mix(col, cc, dens * 0.92 * fadeh);
		vec2 ci = uv * vec2(0.35, 2.2) + wind * 2.0;
		float cir = smoothstep(0.55, 0.9, fbm2(ci, oct - 1)) * cloud_amount * 0.55 * smoothstep(0.05, 0.4, h);
		col = mix(col, lit_c * 1.05, cir * (1.0 - dens) * 0.6);
	}
	COLOR = col * exposure;
}
