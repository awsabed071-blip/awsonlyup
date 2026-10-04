extends Area3D


var size: = Vector3(8, 4, 6)
var wind_dir: = Vector3.RIGHT
var strength: = 8.0
var period: = 5.0
var _players: Array = []
var _parts: GPUParticles3D
var _calm: GPUParticles3D
var _was_on: = false

func _ready() -> void :
	collision_layer = 0
	collision_mask = 2
	var cs: = CollisionShape3D.new()
	var shp: = BoxShape3D.new()
	shp.size = size
	cs.shape = shp
	cs.position = Vector3(0, size.y * 0.5 - 0.3, 0)
	add_child(cs)
	body_entered.connect( func(b): if b is CharacterBody3D: _players.append(b))
	body_exited.connect( func(b): _players.erase(b))


	_calm = _streaks(40, 4.0, 6.5, 0.32, 0.05, 1.3, 2.0)
	_calm.emitting = true
	_parts = _streaks(170, 15.0, 22.0, 0.85, 0.07, 2.2, 1.1)
	_parts.emitting = false

func _streaks(amount: int, vmin: float, vmax: float, alpha: float, thick: float, length: float, life: float) -> GPUParticles3D:
	var gp: = GPUParticles3D.new()
	gp.amount = amount
	gp.lifetime = life
	gp.local_coords = false
	var pm: = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX

	var ext: = size * 0.5
	pm.emission_box_extents = Vector3(ext.x, ext.y * 0.7, ext.z)
	var gdir: = (global_transform.basis.inverse() * wind_dir).normalized() if is_inside_tree() else wind_dir.normalized()
	pm.direction = gdir
	pm.spread = 4.0
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = Vector3.ZERO
	pm.particle_flag_align_y = true
	var g: = Gradient.new()
	g.set_color(0, Color(0.45, 0.9, 1.0, 0.0))
	g.add_point(0.2, Color(0.45, 0.9, 1.0, alpha))
	g.add_point(0.75, Color(0.7, 0.97, 1.0, alpha))
	g.set_color(g.get_point_count() - 1, Color(0.7, 0.97, 1.0, 0.0))
	var gt: = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	gp.process_material = pm
	var bm: = BoxMesh.new()
	bm.size = Vector3(thick, length, thick)
	var sm: = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.vertex_color_use_as_albedo = true
	sm.albedo_color = Color(0.5, 0.95, 1.0)

	sm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	sm.distance_fade_min_distance = 1.2
	sm.distance_fade_max_distance = 4.5
	bm.material = sm
	gp.draw_pass_1 = bm
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB( - size * 0.5 - Vector3(20, 4, 20), size + Vector3(40, 8, 40))
	gp.position = Vector3(0, size.y * 0.35, 0) - (global_transform.basis.inverse() * wind_dir).normalized() * size.z * 0.3
	add_child(gp)
	return gp

func gust() -> float:
	var s: = sin(TAU * Game.world_time / period)
	return clamp(s * 1.8 - 0.8, 0.0, 1.0)

func _physics_process(_delta: float) -> void :
	var g: = gust()
	var on: = g > 0.05
	if on != _was_on:
		_was_on = on
		_parts.emitting = on
		if on and not _players.is_empty():
			Sfx.play("gust", -4.0, 0.1)

	for p in _players:
		if is_instance_valid(p):
			p.wind_push += wind_dir.normalized() * strength * 0.2 * g
