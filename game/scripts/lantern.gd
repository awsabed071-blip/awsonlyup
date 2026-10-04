extends Node3D



@export var lit: = true
@export var glow_energy: = 1.4
@export var glow_range: = 5.0
@export var cast_light: = true

var _glass_mat: StandardMaterial3D
var _flame_mat: StandardMaterial3D
var _flame: MeshInstance3D
var _light: OmniLight3D
var _k: = 1.0
var _target: = 1.0
var _fade: = 1.0
var _t: = 0.0

static var _brass: StandardMaterial3D
static var _brass_dark: StandardMaterial3D

func _init() -> void :
	_build()

func _mat_brass() -> StandardMaterial3D:
	if _brass == null:
		_brass = StandardMaterial3D.new()
		_brass.albedo_color = Color(0.86, 0.64, 0.28)
		_brass.metallic = 0.85
		_brass.roughness = 0.32
		_brass_dark = StandardMaterial3D.new()
		_brass_dark.albedo_color = Color(0.5, 0.34, 0.14)
		_brass_dark.metallic = 0.8
		_brass_dark.roughness = 0.45
	return _brass

func _cyl(r: float, rt: float, h: float, y: float, m: Material, segs: = 8) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	var cm: = CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = rt
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.position = Vector3(0, y, 0)
	mi.material_override = m
	add_child(mi)
	return mi

func _build() -> void :
	var brass: = _mat_brass()

	_cyl(0.13, 0.15, 0.04, 0.02, _brass_dark)
	_cyl(0.15, 0.13, 0.03, 0.055, brass)

	_glass_mat = StandardMaterial3D.new()
	_glass_mat.albedo_color = Color(1.0, 0.72, 0.36, 0.55)
	_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_mat.emission_enabled = true
	_glass_mat.emission = Color(1.0, 0.6, 0.25)
	_glass_mat.emission_energy_multiplier = 1.2
	_glass_mat.roughness = 0.2
	_glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cyl(0.11, 0.135, 0.26, 0.2, _glass_mat)

	for i in 8:
		var a: = TAU * (i + 0.5) / 8.0
		var bar: = MeshInstance3D.new()
		var bm: = BoxMesh.new()
		bm.size = Vector3(0.018, 0.27, 0.018)
		bar.mesh = bm
		var r: = 0.123
		bar.position = Vector3(cos(a) * r, 0.2, sin(a) * r)
		bar.rotation = Vector3(0, - a, 0)
		bar.rotate_object_local(Vector3.BACK, 0.09)
		bar.material_override = brass
		add_child(bar)
	_cyl(0.118, 0.118, 0.02, 0.075, brass)
	_cyl(0.142, 0.142, 0.022, 0.33, brass)

	_cyl(0.16, 0.05, 0.12, 0.4, brass)
	var dome: = MeshInstance3D.new()
	var sm: = SphereMesh.new()
	sm.radius = 0.055
	sm.height = 0.11
	sm.radial_segments = 10
	sm.rings = 5
	dome.mesh = sm
	dome.position = Vector3(0, 0.47, 0)
	dome.material_override = brass
	add_child(dome)
	var ring: = MeshInstance3D.new()
	var tm: = TorusMesh.new()
	tm.inner_radius = 0.025
	tm.outer_radius = 0.042
	tm.rings = 12
	tm.ring_segments = 6
	ring.mesh = tm
	ring.position = Vector3(0, 0.54, 0)
	ring.rotation = Vector3(PI * 0.5, 0, 0)
	ring.material_override = brass
	add_child(ring)

	_flame_mat = StandardMaterial3D.new()
	_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_mat.albedo_color = Color(1.0, 0.8, 0.45)
	_flame_mat.emission_enabled = true
	_flame_mat.emission = Color(1.0, 0.62, 0.22)
	_flame_mat.emission_energy_multiplier = 6.0
	_flame = MeshInstance3D.new()
	var fm: = SphereMesh.new()
	fm.radius = 0.035
	fm.height = 0.1
	fm.radial_segments = 8
	fm.rings = 4
	_flame.mesh = fm
	_flame.position = Vector3(0, 0.17, 0)
	_flame.material_override = _flame_mat
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flame)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.72, 0.42)
	_light.omni_range = glow_range
	_light.light_energy = glow_energy
	_light.shadow_enabled = false
	_light.position = Vector3(0, 0.2, 0)
	add_child(_light)
	for c in get_children():
		if c is GeometryInstance3D and c != _flame:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _ready() -> void :
	_k = 1.0 if lit else 0.0
	_target = _k
	_light.omni_range = glow_range
	_light.visible = cast_light
	_apply()

func set_lit(on: bool, fade: = 0.8) -> void :
	lit = on
	_target = 1.0 if on else 0.0
	_fade = maxf(fade, 0.01)
	if fade <= 0.01:
		_k = _target
		_apply()

func _process(delta: float) -> void :
	_t += delta
	if _k != _target:
		_k = move_toward(_k, _target, delta / _fade)
	_apply()

func _apply() -> void :
	var flick: = 0.88 + 0.08 * sin(_t * 13.0) + 0.05 * sin(_t * 29.0 + 1.3)
	_flame.visible = _k > 0.02
	_flame.scale = Vector3(1.0, 0.8 + 0.25 * sin(_t * 17.0) * 0.5 + 0.2, 1.0) * (0.4 + 0.6 * _k)
	_flame_mat.emission_energy_multiplier = 6.0 * _k * flick
	_glass_mat.emission_energy_multiplier = 1.6 * _k * flick + 0.02
	_glass_mat.albedo_color = Color(0.42, 0.34, 0.26, 0.75).lerp(Color(1.0, 0.72, 0.36, 0.55), _k)
	_light.light_energy = glow_energy * _k * flick
	_light.visible = cast_light and _k > 0.02
