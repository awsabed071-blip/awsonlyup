extends Node3D



var height: = 18.0
var to: = Vector3.ZERO
var radius: = 1.6

var _eagle: Node3D
var _wing_l: Node3D
var _wing_r: Node3D
var _head: Node3D
var _area: Area3D
var _state: = "perch"
var _t: = 0.0
var _player: CharacterBody3D = null
var _perch: = Vector3.ZERO
var _axis: = Vector3.ZERO
var _spiral_end: = Vector3.ZERO
var _rise_t: = 3.0
var _glide_t: = 1.5
var _flap: = 0.0
var _away_dir: = Vector3.FORWARD
var _cry_t: = 0.0

static var _mats: = {}

func _mat(key: String, c: Color, rough: = 0.8) -> StandardMaterial3D:
	if not _mats.has(key):
		var m: = StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[key] = m
	return _mats[key]

func _ready() -> void :
	_axis = global_position
	var to_dst: = Vector3(to.x - _axis.x, 0, to.z - _axis.z)
	var dir: = to_dst.normalized() if to_dst.length() > 0.1 else Vector3.FORWARD

	var post_local: = global_transform.basis.inverse() * ( - dir * 0.85)
	_build_post(post_local)
	_perch = to_global(post_local + Vector3(0, 1.75, 0))
	_eagle = Node3D.new()
	add_child(_eagle)
	_eagle.top_level = true
	_build_eagle()
	_eagle.global_position = _perch + Vector3(0, 0.34, 0)
	_eagle.rotation.y = atan2(dir.x, dir.z)
	_away_dir = (dir + Vector3(0, 0.5, 0)).normalized()

	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var cs: = CollisionShape3D.new()
	var cyl: = CylinderShape3D.new()
	cyl.radius = 1.25
	cyl.height = 2.6
	cs.shape = cyl
	cs.position = post_local + Vector3(0, 1.3, 0)
	_area.add_child(cs)
	add_child(_area)
	_area.body_entered.connect(_on_body)

	var top_hands: = to.y + 1.95 + 1.8
	_spiral_end = Vector3(_axis.x, top_hands, _axis.z) + dir * 0.6
	_rise_t = maxf((top_hands - _perch.y) / 4.6, 1.5)
	_glide_t = 1.6

func _on_body(b: Node3D) -> void :
	if _state != "perch" or not (b is CharacterBody3D) or not b.has_method("start_carry"):
		return

	var rel: Vector3 = b.global_position - (_perch - Vector3(0, 1.75, 0))
	if Vector2(rel.x, rel.z).length() > 1.7 or rel.y < -1.0 or rel.y > 2.8:
		return
	if b.start_carry(self):
		_player = b
		_state = "lift"
		_t = 0.0
		Sfx.play("gust", -6.0, 0.1)
		_cry()

func _cry() -> void :
	Sfx.play("eagle", -3.0, 0.08)

func hold_point() -> Vector3:

	return _eagle.global_position - Vector3(0, 0.42, 0)

func _physics_process(delta: float) -> void :
	_t += delta
	var target: = _eagle.global_position
	match _state:
		"perch":
			for ob in _area.get_overlapping_bodies():
				_on_body(ob)
				if _state != "perch":
					break
			target = _perch + Vector3(0, 0.34, 0)
			_head.rotation.y = sin(_t * 0.7) * 0.6 + sin(_t * 2.3) * 0.1
			_fold(delta)
			_cry_t -= delta
			if _cry_t <= 0.0:
				_cry_t = randf_range(9.0, 16.0)
				if _player_near(22.0):
					_cry()
		"lift":

			var k: = clampf(_t / _rise_t, 0.0, 1.0)
			var e: = k * k * (3.0 - 2.0 * k)
			var ang: = k * TAU * 1.1
			var r: = 1.1 * sin(k * PI)
			var base: = _perch.lerp(_spiral_end, e)
			target = base + Vector3(cos(ang) * r, 0.42 + 0.3 * sin(k * PI), sin(ang) * r)
			_flap_wings(delta, 7.5, 0.75)
			if k >= 1.0:
				_state = "glide"
				_t = 0.0
		"glide":
			var k2: = clampf(_t / _glide_t, 0.0, 1.0)
			var e2: = k2 * k2 * (3.0 - 2.0 * k2)
			var drop: = Vector3(to.x, to.y + 1.95 + 0.85, to.z) + Vector3(0, 0.42, 0)
			var from: = _spiral_end + Vector3(0, 0.42, 0)
			target = from.lerp(drop, e2) + Vector3(0, sin(k2 * PI) * 0.6, 0)
			_flap_wings(delta, 3.0, 0.35)
			if k2 >= 1.0:
				if _player and is_instance_valid(_player):
					_player.end_carry(Vector3(0, -0.5, 0))
				_player = null
				_state = "away"
				_t = 0.0
				Sfx.play("gust", -8.0, 0.1)
		"away":
			target = _eagle.global_position + _away_dir * 9.0 * delta
			_flap_wings(delta, 6.0, 0.7)
			var s: = clampf(1.0 - (_t - 2.5) / 1.0, 0.0, 1.0)
			_eagle.scale = Vector3.ONE * maxf(s, 0.001)
			if _t > 7.0:

				_state = "perch"
				_t = 0.0
				_eagle.global_position = _perch + Vector3(0, 0.34, 0)
				_eagle.scale = Vector3.ONE * 0.01
	if _state == "perch" and _eagle.scale.x < 1.0:
		_eagle.scale = Vector3.ONE * minf(_eagle.scale.x + delta * 1.5, 1.0)
	var vel: = (target - _eagle.global_position) / maxf(delta, 0.001)
	_eagle.global_position = target
	var hv: = Vector3(vel.x, 0, vel.z)
	if hv.length() > 0.5 and _state != "perch":
		_eagle.rotation.y = lerp_angle(_eagle.rotation.y, atan2(hv.x, hv.z), 1.0 - exp(-6.0 * delta))
		_eagle.rotation.x = lerpf(_eagle.rotation.x, clampf( - vel.y * 0.04, -0.4, 0.4), 1.0 - exp(-4.0 * delta))
	elif _state != "perch":
		_eagle.rotation.x = lerpf(_eagle.rotation.x, 0.0, 1.0 - exp(-4.0 * delta))

func _player_near(d: float) -> bool:
	if Game.main == null or Game.main.player == null:
		return false
	return (Game.main.player.global_position - _perch).length() < d

func _fold(delta: float) -> void :
	var k: = 1.0 - exp(-6.0 * delta)
	for w in [_wing_l, _wing_r]:
		var sd: = 1.0 if w == _wing_l else -1.0

		w.rotation.y = lerpf(w.rotation.y, sd * 1.35, k)
		w.rotation.z = lerpf(w.rotation.z, sd * -0.25, k)
	_eagle.rotation.x = lerpf(_eagle.rotation.x, -0.75, k)

func _flap_wings(delta: float, freq: float, amp: float) -> void :
	_flap += delta * freq
	for w in [_wing_l, _wing_r]:
		var sd: = 1.0 if w == _wing_l else -1.0
		var want: = sd * (sin(_flap) * amp + 0.1)
		w.rotation.z = lerpf(w.rotation.z, want, 1.0 - exp(-18.0 * delta))
		w.rotation.y = lerpf(w.rotation.y, 0.0, 1.0 - exp(-10.0 * delta))


func _mesh(parent: Node3D, m: Mesh, pos: Vector3, mat: Material, rot: = Vector3.ZERO, sc: = Vector3.ONE) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = sc
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _build_post(at: Vector3) -> void :
	var wood: = _mat("wood", Color(0.45, 0.3, 0.18))
	var pole: = CylinderMesh.new()
	pole.top_radius = 0.08
	pole.bottom_radius = 0.11
	pole.height = 1.75
	pole.radial_segments = 8
	_mesh(self, pole, at + Vector3(0, 0.875, 0), wood)
	var bar: = CylinderMesh.new()
	bar.top_radius = 0.05
	bar.bottom_radius = 0.05
	bar.height = 0.8
	bar.radial_segments = 6
	_mesh(self, bar, at + Vector3(0, 1.72, 0), wood, Vector3(0, 0, PI * 0.5))

	var flag: = BoxMesh.new()
	flag.size = Vector3(0.04, 0.35, 0.5)
	_mesh(self, flag, at + Vector3(0, 1.35, 0.28), _mat("cloth", Color(0.8, 0.12, 0.12)))

func _build_eagle() -> void :
	var brown: = _mat("brown", Color(0.36, 0.22, 0.12))
	var dark: = _mat("dark", Color(0.22, 0.13, 0.07))
	var white: = _mat("white", Color(0.96, 0.95, 0.9))
	var yellow: = _mat("yellow", Color(0.98, 0.72, 0.18), 0.5)
	var black: = _mat("black", Color(0.05, 0.05, 0.05), 0.3)
	var body: = SphereMesh.new()
	body.radius = 0.3
	body.height = 0.6
	_mesh(_eagle, body, Vector3(0, 0, 0), brown, Vector3.ZERO, Vector3(1.0, 1.0, 1.55))
	_head = Node3D.new()
	_head.position = Vector3(0, 0.22, 0.4)
	_eagle.add_child(_head)
	var hm: = SphereMesh.new()
	hm.radius = 0.19
	hm.height = 0.38
	_mesh(_head, hm, Vector3.ZERO, white)
	var beak: = CylinderMesh.new()
	beak.top_radius = 0.0
	beak.bottom_radius = 0.075
	beak.height = 0.22
	beak.radial_segments = 8
	_mesh(_head, beak, Vector3(0, -0.03, 0.2), yellow, Vector3(PI * 0.5 + 0.35, 0, 0))
	for sx in [-1.0, 1.0]:
		var eye: = SphereMesh.new()
		eye.radius = 0.035
		eye.height = 0.07
		_mesh(_head, eye, Vector3(sx * 0.12, 0.06, 0.12), black)

		var brow: = BoxMesh.new()
		brow.size = Vector3(0.12, 0.03, 0.06)
		_mesh(_head, brow, Vector3(sx * 0.1, 0.11, 0.13), white, Vector3(0, 0, sx * 0.35))
	var tail: = BoxMesh.new()
	tail.size = Vector3(0.34, 0.05, 0.42)
	_mesh(_eagle, tail, Vector3(0, 0.02, -0.62), white, Vector3(-0.2, 0, 0))
	for sx in [-1.0, 1.0]:
		var leg: = CylinderMesh.new()
		leg.top_radius = 0.04
		leg.bottom_radius = 0.03
		leg.height = 0.28
		leg.radial_segments = 6
		_mesh(_eagle, leg, Vector3(sx * 0.1, -0.3, 0.05), yellow)

	_wing_l = Node3D.new()
	_wing_r = Node3D.new()
	for w in [_wing_l, _wing_r]:
		var sd: = 1.0 if w == _wing_l else -1.0
		w.position = Vector3(sd * 0.22, 0.12, 0.05)
		_eagle.add_child(w)
		var inner: = BoxMesh.new()
		inner.size = Vector3(0.75, 0.06, 0.5)
		_mesh(w, inner, Vector3(sd * 0.38, 0, 0), brown)
		var outer: = BoxMesh.new()
		outer.size = Vector3(0.7, 0.05, 0.4)
		_mesh(w, outer, Vector3(sd * 1.05, 0, -0.04), dark, Vector3(0, sd * 0.12, 0))
	for mi in _eagle.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
