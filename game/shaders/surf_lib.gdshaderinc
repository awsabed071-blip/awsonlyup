// Shared by surface.gdshader, prop_real.gdshader, terrain.gdshader and foliage.gdshader:
// object-space triplanar sampling of the surface library (two texture arrays, one layer per family).
//   surf_a: rgb = albedo (sRGB), a = roughness
//   surf_n: rg = tangent normal xy, b = height, a = secondary mask (mortar / chips / soil / lichen)
// Expects the including shader to declare: uniform sampler2DArray surf_a, surf_n.

float sl_hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float sl_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(sl_hash(i + vec3(0, 0, 0)), sl_hash(i + vec3(1, 0, 0)), f.x),
				   mix(sl_hash(i + vec3(0, 1, 0)), sl_hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(sl_hash(i + vec3(0, 0, 1)), sl_hash(i + vec3(1, 0, 1)), f.x),
				   mix(sl_hash(i + vec3(0, 1, 1)), sl_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// p: object-space position in metres, n: object-space normal (normalised).
// A = albedo.rgb + roughness, N = normal.xy + height + mask, on = perturbed object-space normal.
void sl_sample(vec3 p, vec3 n, float lay, float til, float bmp, bool one_axis, out vec4 A, out vec4 N, out vec3 on) {
	vec3 an = abs(n);
	vec3 sg = sign(n + vec3(1e-4));
	vec3 w = pow(an, vec3(8.0));
	if (one_axis) {
		w = an.x > an.y && an.x > an.z ? vec3(1, 0, 0) : (an.y > an.z ? vec3(0, 1, 0) : vec3(0, 0, 1));
	}
	w /= max(dot(w, vec3(1.0)), 1e-4);
	vec3 q = p / til;
	vec2 uvx = vec2(q.z * sg.x, -q.y);
	vec2 uvy = vec2(q.x * sg.y, q.z);
	vec2 uvz = vec2(-q.x * sg.z, -q.y);
	A = vec4(0.0);
	N = vec4(0.0);
	on = vec3(0.0);
	if (w.x > 0.01) {
		vec4 a = texture(surf_a, vec3(uvx, lay));
		vec4 t = texture(surf_n, vec3(uvx, lay));
		vec2 d = (t.xy * 2.0 - 1.0) * bmp;
		d.x *= sg.x;
		d.y = -d.y;
		vec3 nx = vec3(d + n.zy, n.x);
		on += nx.zyx * w.x;
		A += a * w.x;
		N += t * w.x;
	}
	if (w.y > 0.01) {
		vec4 a = texture(surf_a, vec3(uvy, lay));
		vec4 t = texture(surf_n, vec3(uvy, lay));
		vec2 d = (t.xy * 2.0 - 1.0) * bmp;
		d.x *= sg.y;
		vec3 ny = vec3(d + n.xz, n.y);
		on += ny.xzy * w.y;
		A += a * w.y;
		N += t * w.y;
	}
	if (w.z > 0.01) {
		vec4 a = texture(surf_a, vec3(uvz, lay));
		vec4 t = texture(surf_n, vec3(uvz, lay));
		vec2 d = (t.xy * 2.0 - 1.0) * bmp;
		d.x *= -sg.z;
		d.y = -d.y;
		vec3 nz = vec3(d + n.xy, n.z);
		on += nz * w.z;
		A += a * w.z;
		N += t * w.z;
	}
	on = normalize(on);
}

// cavity / ambient occlusion from the height channel: lower than the local average = darker
float sl_cavity(vec4 N) {
	return clamp(0.55 + N.b * 0.6, 0.0, 1.0);
}

// dark rain streaks running down vertical faces (world space)
float sl_streak(vec3 wp, vec3 wn) {
	vec3 an = abs(wn);
	if (an.y > 0.4) {
		return 0.0;
	}
	float along = dot(wp.xz, vec2(1.0 - an.x, an.x));
	float st = sl_noise(vec3(along * 5.0, wp.y * 0.25, 1.3)) * sl_noise(vec3(along * 1.7, wp.y * 0.6, 4.1));
	return smoothstep(0.25, 0.6, st) * (1.0 - an.y * 2.5);
}

// palette: tint_k = 1 -> palette colour times the (grey) library texture; 0 -> library colour
vec3 sl_palette(vec3 tex_rgb, vec3 pal, float k) {
	return tex_rgb * mix(vec3(1.0), pal * 2.0, k);
}
