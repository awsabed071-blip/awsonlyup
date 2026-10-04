extends Node3D
# Lighting, sky and post-processing for the whole climb. Six "looks" blend with height
# (dusk in the old village, night on the rooftops and in the works, deep night over the clouds and
# the isles, the thin edge of space, and finally dawn). Cutscenes can override the look.

var env: Environment
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_mat: ShaderMaterial
var level
var _cur_look: = {}
var _t: = 0.0

# zenith/horizon/ground: sky tints; sun_col/sun_e/sun_elev/sun_az: the key light; fog: fog colour;
# fog_d: fog density; amb: ambient colour; clouds/stars: sky content; sat: saturation; hfog: height fog;
# sea: cloud-sea tint; win: window lights; cres: moon visibility; turb: haze turbidity; exp: exposure;
# temp: colour grading warmth (-1 cold .. 1 warm); lift: shadow lift (grey in the blacks).
const LOOKS: = [
	{ # 1 old village: late dusk, the last amber light low on the hills, blue in the shadows
		"zenith": Color(0.22, 0.30, 0.52), "horizon": Color(0.86, 0.6, 0.42), "ground": Color(0.42, 0.36, 0.32), 
		"sun_col": Color(1.0, 0.68, 0.46), "sun_e": 1.1, "sun_elev": 6.0, "sun_az": 250.0, 
		"fog": Color(0.62, 0.52, 0.48), "fog_d": 0.0012, "amb": Color(0.5, 0.52, 0.62), "amb_e": 0.75, 
		"clouds": 0.55, "stars": 0.12, "sat": 0.86, "hfog": 0.004, "sea": Color(0.95, 0.82, 0.72), "win": 0.6, "cres": 0.0, 
		"turb": 3.2, "exp": 1.0, "temp": 0.15, "lift": 0.02, 
	}, 
	{ # 2 rooftops: after the evening prayer, deep blue hour, windows lit
		"zenith": Color(0.08, 0.12, 0.3), "horizon": Color(0.5, 0.36, 0.4), "ground": Color(0.2, 0.2, 0.26), 
		"sun_col": Color(0.9, 0.62, 0.55), "sun_e": 0.55, "sun_elev": 1.0, "sun_az": 255.0, 
		"fog": Color(0.32, 0.3, 0.4), "fog_d": 0.0011, "amb": Color(0.36, 0.4, 0.58), "amb_e": 0.8, 
		"clouds": 0.45, "stars": 0.45, "sat": 0.8, "hfog": 0.003, "sea": Color(0.7, 0.62, 0.7), "win": 1.0, "cres": 0.4, 
		"turb": 2.8, "exp": 1.0, "temp": -0.1, "lift": 0.03, 
	}, 
	{ # 3 the works: midnight, steel under a cold moon, sodium lamps far below
		"zenith": Color(0.02, 0.035, 0.1), "horizon": Color(0.16, 0.17, 0.28), "ground": Color(0.08, 0.09, 0.13), 
		"sun_col": Color(0.6, 0.7, 1.0), "sun_e": 0.55, "sun_elev": 42.0, "sun_az": 130.0, 
		"fog": Color(0.12, 0.14, 0.24), "fog_d": 0.0012, "amb": Color(0.3, 0.36, 0.56), "amb_e": 0.85, 
		"clouds": 0.3, "stars": 0.8, "sat": 0.78, "hfog": 0.0, "sea": Color(0.5, 0.55, 0.72), "win": 1.0, "cres": 1.0, 
		"turb": 2.2, "exp": 1.0, "temp": -0.35, "lift": 0.035, 
	}, 
	{ # 4 sea of clouds: moonlit silver, quiet
		"zenith": Color(0.02, 0.03, 0.1), "horizon": Color(0.18, 0.22, 0.4), "ground": Color(0.4, 0.44, 0.58), 
		"sun_col": Color(0.74, 0.8, 1.0), "sun_e": 0.65, "sun_elev": 48.0, "sun_az": 160.0, 
		"fog": Color(0.2, 0.25, 0.42), "fog_d": 0.0006, "amb": Color(0.4, 0.46, 0.68), "amb_e": 0.85, 
		"clouds": 0.15, "stars": 0.95, "sat": 0.8, "hfog": 0.0, "sea": Color(0.66, 0.72, 0.9), "win": 1.0, "cres": 1.0, 
		"turb": 1.8, "exp": 1.0, "temp": -0.3, "lift": 0.04, 
	}, 
	{ # 5 hanging isles: the hour before dawn, thin air, the brightest stars
		"zenith": Color(0.015, 0.025, 0.08), "horizon": Color(0.12, 0.14, 0.3), "ground": Color(0.16, 0.18, 0.28), 
		"sun_col": Color(0.72, 0.78, 1.0), "sun_e": 0.6, "sun_elev": 55.0, "sun_az": 200.0, 
		"fog": Color(0.12, 0.14, 0.3), "fog_d": 0.0005, "amb": Color(0.38, 0.42, 0.66), "amb_e": 0.9, 
		"clouds": 0.2, "stars": 1.0, "sat": 0.82, "hfog": 0.0, "sea": Color(0.52, 0.56, 0.8), "win": 1.0, "cres": 1.0, 
		"turb": 1.5, "exp": 1.0, "temp": -0.25, "lift": 0.04, 
	}, 
	{ # 6 the edge of space: black sky, hard light, the first violet of dawn at the rim
		"zenith": Color(0.01, 0.012, 0.03), "horizon": Color(0.3, 0.22, 0.4), "ground": Color(0.1, 0.1, 0.18), 
		"sun_col": Color(0.95, 0.9, 1.0), "sun_e": 0.9, "sun_elev": 24.0, "sun_az": 95.0, 
		"fog": Color(0.14, 0.14, 0.26), "fog_d": 0.00025, "amb": Color(0.36, 0.36, 0.6), "amb_e": 0.85, 
		"clouds": 0.0, "stars": 1.0, "sat": 0.85, "hfog": 0.0, "sea": Color(0.5, 0.5, 0.75), "win": 1.0, "cres": 1.0, 
		"turb": 1.0, "exp": 1.0, "temp": -0.15, "lift": 0.03, 
	}, 
]

const LOOK_NIGHT: = {
	"zenith": Color(0.02, 0.03, 0.09), "horizon": Color(0.1, 0.13, 0.26), "ground": Color(0.05, 0.06, 0.08), 
	"sun_col": Color(0.58, 0.68, 1.0), "sun_e": 0.4, "sun_elev": 38.0, "sun_az": -30.0, 
	"fog": Color(0.07, 0.09, 0.18), "fog_d": 0.0014, "amb": Color(0.24, 0.3, 0.52), "amb_e": 0.7, 
	"clouds": 0.25, "stars": 1.0, "sat": 0.85, "hfog": 0.004, 
	"sea": Color(0.8, 0.8, 0.9), "win": 1.0, "cres": 1.0, "turb": 2.0, "exp": 1.0, "temp": -0.3, "lift": 0.03, 
}
const LOOK_DUSK: = {
	"zenith": Color(0.18, 0.22, 0.38), "horizon": Color(0.74, 0.52, 0.44), "ground": Color(0.3, 0.29, 0.31), 
	"sun_col": Color(1.0, 0.6, 0.42), "sun_e": 0.7, "sun_elev": 4.0, "sun_az": 250.0, 
	"fog": Color(0.48, 0.42, 0.46), "fog_d": 0.0013, "amb": Color(0.4, 0.4, 0.52), "amb_e": 0.65, 
	"clouds": 0.6, "stars": 0.15, "sat": 0.78, "hfog": 0.004, 
	"sea": Color(0.8, 0.8, 0.9), "win": 1.0, "cres": 0.0, "turb": 3.5, "exp": 1.0, "temp": 0.1, "lift": 0.02, 
}
const LOOK_DAWN: = {
	"zenith": Color(0.2, 0.3, 0.58), "horizon": Color(1.0, 0.72, 0.5), "ground": Color(0.7, 0.58, 0.52), 
	"sun_col": Color(1.0, 0.78, 0.55), "sun_e": 1.4, "sun_elev": 5.0, "sun_az": 95.0, 
	"fog": Color(0.9, 0.72, 0.62), "fog_d": 0.0004, "amb": Color(0.66, 0.6, 0.66), "amb_e": 0.9, 
	"clouds": 0.25, "stars": 0.2, "sat": 1.05, "hfog": 0.0, 
	"sea": Color(0.95, 0.85, 0.82), "win": 0.6, "cres": 0.2, "turb": 2.5, "exp": 1.05, "temp": 0.35, "lift": 0.01, 
}
var override_look: Dictionary = {}
var override_w: = 0.0
var _ow_tw: Tween
var _last_y: = 0.0
var _grade: ColorRect
var _grade_mat: ShaderMaterial

func set_override(look: Dictionary, w: float, dur: = 0.0) -> void :
	if not look.is_empty():
		override_look = look
	if _ow_tw:
		_ow_tw.kill()
	if dur <= 0.0:
		override_w = w
		update_for_height(_last_y, true)
	else:
		_ow_tw = create_tween()
		_ow_tw.tween_property(self, "override_w", w, dur)

func setup(level_ref) -> void :
	level = level_ref
	world_env = WorldEnvironment.new()
	env = Environment.new()
	var sky: = Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_128 if Game.mobile else Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_strength = 0.85
	env.glow_bloom = 0.04
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_sky_affect = 0.2
	env.fog_aerial_perspective = 0.55
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.95
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 160.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_blur = 1.4
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.6
	sun.light_angular_distance = 0.6
	add_child(sun)
	_build_grade()
	apply_quality()
	Game.settings_changed.connect(apply_quality)
	update_for_height(0.0, true)

func _build_grade() -> void :
	# full-screen colour grade: warmth, shadow lift, vignette and a touch of grain
	var layer: = CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_grade = ColorRect.new()
	_grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: = Shader.new()
	sh.code = """shader_type canvas_item;
render_mode blend_mix;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float temp = 0.0;
uniform float lift = 0.02;
uniform float vignette = 0.28;
uniform float grain = 0.025;
uniform float sat = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, sat);
	c += vec3(0.05, 0.01, -0.06) * temp * (0.6 + 0.4 * (1.0 - l));
	c = c * (1.0 - lift) + lift * vec3(0.9, 0.95, 1.1) * lift * 8.0;
	vec2 uv = SCREEN_UV - 0.5; uv.x *= 1.6;
	float v = smoothstep(0.35, 1.25, length(uv));
	c *= 1.0 - v * vignette;
	c += (hash(SCREEN_UV * 1000.0 + fract(TIME)) - 0.5) * grain;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}"""
	_grade_mat = ShaderMaterial.new()
	_grade_mat.shader = sh
	_grade.material = _grade_mat
	layer.add_child(_grade)

func apply_quality() -> void :
	var q: int = Game.settings.quality
	if Game.mobile:
		_apply_quality_mobile(q)
		return
	env.ssao_enabled = q >= 1
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.8
	env.ssao_power = 1.5
	env.ssil_enabled = q >= 3
	env.sdfgi_enabled = q >= 3
	if q >= 3:
		env.sdfgi_use_occlusion = true
		env.sdfgi_cascades = 4
		env.sdfgi_min_cell_size = 0.4
		env.sdfgi_energy = 0.9
	env.volumetric_fog_enabled = q >= 2
	env.volumetric_fog_density = 0.0018
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_anisotropy = 0.65
	env.volumetric_fog_sky_affect = 0.0
	env.glow_enabled = q >= 1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = [70.0, 120.0, 170.0, 240.0][q]
	_grade.visible = q >= 1
	var vp: = get_viewport()
	if vp:
		vp.scaling_3d_scale = float(Game.settings.get("render_scale", 1.0))
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if vp.scaling_3d_scale >= 0.99 else Viewport.SCALING_3D_MODE_FSR2
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA if q >= 1 else Viewport.SCREEN_SPACE_AA_FXAA
		vp.use_taa = q >= 2
		vp.msaa_3d = Viewport.MSAA_2X if q >= 2 else Viewport.MSAA_DISABLED
		vp.mesh_lod_threshold = [3.0, 2.0, 1.0, 0.5][q]
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 4096, 8192][q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q])

func _apply_quality_mobile(q: int) -> void :
	env.ssao_enabled = q >= 3
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.5
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false
	env.glow_enabled = q >= 1
	sun.shadow_enabled = q >= 1
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = [30.0, 45.0, 70.0, 110.0][q]
	sun.shadow_blur = 1.0
	_grade.visible = q >= 1
	_grade_mat.set_shader_parameter("grain", 0.0 if q < 2 else 0.02)
	var vp: = get_viewport()
	if vp:
		vp.scaling_3d_scale = float(Game.settings.get("render_scale", 0.8))
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if (vp.scaling_3d_scale >= 0.99 or q == 0) else Viewport.SCALING_3D_MODE_FSR
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q >= 1 else Viewport.SCREEN_SPACE_AA_DISABLED
		vp.use_taa = false
		vp.msaa_3d = Viewport.MSAA_2X if q >= 3 else Viewport.MSAA_DISABLED
		vp.mesh_lod_threshold = [6.0, 4.0, 2.5, 1.5][q]
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 2048, 4096][q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW][q])

func _zone_weights(y: float) -> Array:
	var zs: Array = level.zones
	var n: = zs.size()
	for i in range(n - 1, -1, -1):
		var y0: = float(zs[i].y0)
		if y >= y0 - 25.0:
			if i > 0 and y < y0 + 25.0:
				var t: = smoothstep(y0 - 25.0, y0 + 25.0, y)
				return [i - 1, i, t]
			return [i, i, 0.0]
	return [0, 0, 0.0]

func _lerp_look(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var look: = {}
	for k in a.keys():
		var va = a[k]
		var vb = b.get(k, va)
		if va is Color:
			look[k] = (va as Color).lerp(vb, t)
		else:
			look[k] = lerp(float(va), float(vb), t)
	return look

func update_for_height(y: float, instant: = false) -> void :
	_last_y = y
	var w: = _zone_weights(y)
	var look: = _lerp_look(LOOKS[w[0]], LOOKS[w[1]], float(w[2]))
	if w[0] == 5 and w[1] == 5:
		var zs: Array = level.zones
		var top: float = float(level.nodes[-1].p[1])
		var k6: float = clamp((y - float(zs[5].y0)) / maxf(top - float(zs[5].y0), 1.0), 0.0, 1.0)
		var dawn: float = 0.55 * pow(k6, 1.6)
		look = _lerp_look(look, LOOK_DAWN, dawn)
		look.stars = lerp(1.0, 0.45, dawn / 0.55)
	if override_w > 0.001 and not override_look.is_empty():
		look = _lerp_look(look, override_look, override_w)
	if instant or _cur_look.is_empty() or override_w > 0.001:
		_cur_look = look
	else:
		var kk: = 1.0 - exp(-1.8 * get_process_delta_time())
		_cur_look = _lerp_look(_cur_look, look, kk)
	_apply(_cur_look)

var _punch: = 0.0
var _punch_v: = 0.0

func punch(k: float) -> void :
	# a hard landing knocks the colour out of the world for a second
	_punch = maxf(_punch, k)

func _process(delta: float) -> void :
	if _punch > 0.001 or _punch_v > 0.001:
		_punch_v = lerpf(_punch_v, _punch, 1.0 - exp(-14.0 * delta))
		_punch = maxf(_punch - delta * 0.55, 0.0)
		if _grade_mat:
			_grade_mat.set_shader_parameter("sat", 1.0 - _punch_v * 0.7)
			_grade_mat.set_shader_parameter("lift", float(_cur_look.get("lift", 0.02)) - _punch_v * 0.04)
	elif _punch_v != 0.0:
		_punch_v = 0.0
		if _grade_mat:
			_grade_mat.set_shader_parameter("sat", 1.0)
			_grade_mat.set_shader_parameter("lift", float(_cur_look.get("lift", 0.02)))

func _apply(l: Dictionary) -> void :
	sky_mat.set_shader_parameter("zenith", l.zenith)
	sky_mat.set_shader_parameter("horizon", l.horizon)
	sky_mat.set_shader_parameter("ground", l.ground)
	sky_mat.set_shader_parameter("sun_tint", l.sun_col)
	sky_mat.set_shader_parameter("stars", l.stars)
	sky_mat.set_shader_parameter("cloud_amount", l.clouds)
	sky_mat.set_shader_parameter("turbidity", float(l.get("turb", 2.5)))
	sky_mat.set_shader_parameter("exposure", float(l.get("exp", 1.0)))
	sky_mat.set_shader_parameter("haze_col", (l.fog as Color).lerp(l.horizon, 0.35))
	sky_mat.set_shader_parameter("haze", 0.75 if float(l.get("hfog", 0.0)) > 0.0 else 0.45)
	sky_mat.set_shader_parameter("lite", 1.0 if Game.mobile else 0.0)
	var cres: float = float(l.get("cres", 0.0))
	# at night the key light is the moon: the sky draws the moon disc where the light comes from
	var el: = deg_to_rad(float(l.sun_elev))
	var az: = deg_to_rad(float(l.sun_az))
	var ldir: = Vector3(cos(el) * sin(az), sin(el), cos(el) * cos(az))
	sky_mat.set_shader_parameter("moon_dir", ldir)
	sky_mat.set_shader_parameter("moon_visible", cres)
	sky_mat.set_shader_parameter("moon_size", 0.016)
	sky_mat.set_shader_parameter("sun_size", 0.026)
	sun.light_color = l.sun_col
	sun.light_energy = l.sun_e
	sun.rotation_degrees = Vector3( - l.sun_elev, l.sun_az, 0)
	# when the moon is the light, it must not draw a sun disc: the sky uses sun_h for the daylight model,
	# so push the daylight part below the horizon by handing the shader a dim sun through LIGHT0_ENERGY
	env.fog_light_color = l.fog
	env.fog_density = l.fog_d * (2.0 if Game.mobile else 1.0)
	env.fog_height = -40.0
	env.fog_height_density = l.hfog
	env.ambient_light_color = l.amb
	env.ambient_light_energy = l.amb_e
	env.ambient_light_sky_contribution = 0.55
	env.adjustment_saturation = l.sat
	env.tonemap_exposure = float(l.get("exp", 1.0))
	env.volumetric_fog_albedo = l.fog
	if _grade_mat:
		_grade_mat.set_shader_parameter("temp", float(l.get("temp", 0.0)))
		_grade_mat.set_shader_parameter("lift", float(l.get("lift", 0.02)))
		_grade_mat.set_shader_parameter("sat", 1.0)
