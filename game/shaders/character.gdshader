shader_type spatial;
// The hero: the kit's painted atlas with softer, more physical shading (cloth roughness, a light rim
// that separates the silhouette from busy backgrounds). For the cape, the vertex stage bends the
// rigid mesh from the shoulders down: it trails behind when running, lifts when falling, swings to
// the side in turns and flutters in the wind. The angles come from a spring in player.gd.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_col : source_color = vec4(1.0);
uniform bool use_tex = true;
uniform float rough = 0.68;
uniform float rim_amount = 0.45;
uniform float rim_tint_amount = 0.35;
uniform float spec = 0.35;
// cape
uniform bool is_cape = false;
uniform float cape_len = 1.12;       // length of the cape below its pivot, mesh units
uniform float cape_back_z = -0.1;    // where it hangs from (behind the shoulders)
uniform float swing_back = 0.0;      // radians, + = hem goes backwards and up
uniform float swing_side = 0.0;      // radians, + = hem goes to +x
uniform float flutter = 0.0;         // 0..1 wind in the cloth
uniform float flutter_speed = 9.0;

void vertex() {
	if (is_cape) {
		float t = clamp(-VERTEX.y / cape_len, 0.0, 1.0);
		float tb = pow(t, 1.6);
		float wave = sin(TIME * flutter_speed - t * 5.5 + VERTEX.x * 3.0) * 0.6 + sin(TIME * flutter_speed * 1.7 - t * 9.0 - VERTEX.x * 5.0) * 0.4;
		float a = swing_back * tb + flutter * wave * 0.22 * t * t;
		float b = swing_side * tb + flutter * wave * 0.06 * t;
		// backwards: rotate (y, z) around the pivot line
		float dz = VERTEX.z - cape_back_z;
		float ca = cos(a);
		float sa = sin(a);
		float y1 = VERTEX.y * ca - dz * sa;
		float z1 = VERTEX.y * sa + dz * ca;
		vec3 n1 = vec3(NORMAL.x, NORMAL.y * ca - NORMAL.z * sa, NORMAL.y * sa + NORMAL.z * ca);
		// sideways: rotate (x, y) around the vertical through the pivot
		float cb = cos(b);
		float sb = sin(b);
		float x2 = VERTEX.x * cb - y1 * sb;
		float y2 = VERTEX.x * sb + y1 * cb;
		n1 = vec3(n1.x * cb - n1.y * sb, n1.x * sb + n1.y * cb, n1.z);
		VERTEX = vec3(x2, y2, z1 + cape_back_z);
		NORMAL = n1;
	}
}

void fragment() {
	vec3 c = albedo_col.rgb;
	if (use_tex) {
		c *= texture(albedo_tex, UV).rgb;
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = spec;
	RIM = rim_amount;
	RIM_TINT = rim_tint_amount;
}
