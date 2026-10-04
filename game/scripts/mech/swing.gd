extends Node3D




var to: = Vector3.ZERO
var pad_r: = 1.3
var builder: Node = null

const SEAT_H: = 0.55
const PERIOD: = 2.7

var state: = "idle"
var _t: = 0.0
var _phase: = 0.0
var _theta: = 0.0
var _theta_r: = 1.4
var _L: = 5.0
var _u: = Vector3.FORWARD
var _side: = Vector3.RIGHT
var _pivot: = Vector3.ZERO
var _rest: = Vector3.ZERO
var _arm: Node3D
var _player: CharacterBody3D = null
var _fly_from: = Vector3.ZERO
var _last_sign: = 0.0
var _body: = Vector3.ZERO
var rides: = 0

func _ready() -> void :
	var s: = global_position
	var d: = Vector3(to.x - s.x, 0, to.z - s.z)
	var dh: = maxf(d.length(), 1.0)
	_u = d / dh
	_side = Vector3.UP.cross(_u).normalized()
	var dy: = (to.y + 0.7) - (s.y + SEAT_H)
	_theta_r = clampf(2.0 * atan2(maxf(dy, 0.5), dh), 0.9, 1.75)
	_L = dh / sin(_theta_r)

	_rest = s + Vector3(0, SEAT_H, 0)
	var fy: = _rest.y + _L * (1.0 - cos(_theta_r))
	_rest.y += (to.y + 0.7) - fy
	_pivot = _rest + Vector3(0, _L, 0)
	_build()

func _build() -> void :
	var wood: = _mat("swing_wood", Color(0.52, 0.34, 0.2), 0.8)
	var rope: = _mat("swing_rope", Color(0.86, 0.8, 0.64), 0.9)
	var red: = _mat("swing_red", Color(0.8, 0.14, 0.14), 0.7)
	var root: = Node3D.new()
	root.top_level = true
	add_child(root)
	root.global_transform = Transform3D.IDENTITY

	var base: = global_position
	for sd in [-1.0, 1.0]:
		var top: Vector3 = _pivot + _side * sd * 1.1
		for fb in [-1.0, 1.0]:
			var foot: Vector3 = base + _side * sd * (pad_r - 0.15) + _u * fb * 0.9
			_tube(root, foot, top, 0.11, wood)
	_tube(root, _pivot - _side * 1.35, _pivot + _side * 1.35, 0.13, wood)

	for k in 5:
		var q: = _pivot + _side * lerpf(-1.1, 1.1, k / 4.0)
		var rb: = MeshInstance3D.new()
		var bm: = BoxMesh.new()
		bm.size = Vector3(0.05, 0.6, 0.12)
		rb.mesh = bm
		rb.material_override = red if k % 2 == 0 else _mat("swing_green", Color(0.1, 0.5, 0.3), 0.7)
		root.add_child(rb)
		rb.global_transform = Transform3D(Basis.looking_at(_u), q + Vector3(0, -0.35, 0))

	_arm = Node3D.new()
	_arm.top_level = true
	add_child(_arm)
	_arm.global_transform = Transform3D(Basis(_side, Vector3.UP, _u), _pivot)
	for sd in [-1.0, 1.0]:
		_tube(_arm, Vector3(sd * 0.42, 0, 0), Vector3(sd * 0.42, - _L + 0.05, 0), 0.025, rope)
	var seat: = MeshInstance3D.new()
	var sbm: = BoxMesh.new()
	sbm.size = Vector3(1.0, 0.07, 0.36)
	seat.mesh = sbm
	seat.material_override = wood
	seat.position = Vector3(0, - _L, 0)
	_arm.add_child(seat)
	var cushion: = MeshInstance3D.new()
	var cbm: = BoxMesh.new()
	cbm.size = Vector3(0.7, 0.05, 0.3)
	cushion.mesh = cbm
	cushion.material_override = red
	cushion.position = Vector3(0, - _L + 0.06, 0)
	_arm.add_child(cushion)
	if Game.mobile:
		for gi in find_children("*", "GeometryInstance3D", true, false):
			(gi as GeometryInstance3D).visibility_range_end = 260.0

func _mat(key: String, c: Color, rough: = 0.8) -> StandardMaterial3D:
	var m: = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.resource_name = key
	return m

func _tube(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> void :
	var cm: = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = a.distance_to(b)
	cm.radial_segments = 8
	cm.rings = 1
	var mi: = MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	parent.add_child(mi)
	var up: = (b - a).normalized()
	var sd: = up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(sd, up, sd.cross(up)), (a + b) * 0.5)

func seat_point() -> Vector3:
	return _pivot + (_u * sin(_theta) - Vector3.UP * cos(_theta)) * _L

func rest_point() -> Vector3:
	return _rest

func carry_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, atan2(_u.x, _u.z)), _body)

func _seated_body() -> Vector3:

	return seat_point() + Vector3(0, -0.35, 0) + _u * 0.3

func _physics_process(delta: float) -> void :
	_t += delta
	match state:
		"idle":
			_theta = sin(_t * 1.1) * 0.035
			var pl: = _find_player()
			if pl and pl.state == pl.State.NORMAL and pl.is_on_floor():
				var rel: Vector3 = pl.global_position - Vector3(_rest.x, global_position.y, _rest.z)
				if Vector2(rel.x, rel.z).length() < 1.0 and absf(rel.y) < 0.8:
					_body = _seated_body()
					if pl.start_carry(self, "swing"):
						_player = pl
						state = "ride"
						_t = 0.0
						_phase = 0.0
						_last_sign = 0.0
						rides += 1
						pl.play_anim("Sit_Chair_Idle", 0.2)
						Sfx.play("swing_creak", -6.0, 0.1)
		"ride":
			_phase += delta * TAU / PERIOD
			var amp: = minf(_theta_r, 0.3 + 0.3 * _t)
			var sn: = sin(_phase)
			_theta = amp * sn if sn > 0.0 else amp * 0.55 * sn
			if signf(cos(_phase)) != _last_sign:
				_last_sign = signf(cos(_phase))
				Sfx.play("swing_creak", -10.0 + amp * 3.0, 0.1)
			_body = _seated_body()
			if _player:
				_player.ride_crank = _theta
				_player.ride_pitch = - _theta * 0.35

			if amp >= _theta_r and sn > 0.995:
				state = "fly"
				_t = 0.0
				_fly_from = _body
				Sfx.play("whoosh", -4.0, 0.05)
				if _player:
					_player.carry_pose = "free"
					_player.play_anim("Jump_Idle", 0.15)
		"fly":
			var k: = clampf(_t / 0.55, 0.0, 1.0)
			_body = _fly_from.lerp(to + Vector3(0, 0.05, 0), k) + Vector3(0, sin(k * PI) * 0.6, 0)
			_theta = _theta_r * cos(_t * TAU / PERIOD)
			if k >= 1.0:
				if _player and is_instance_valid(_player):
					_player.end_carry(Vector3(0, -1.0, 0))
				_player = null
				state = "settle"
				_t = 0.0
		"settle":
			_theta = _theta_r * cos(_t * TAU / PERIOD) * exp( - _t / 2.5)
			if _t > 9.0:
				state = "idle"
				_t = 0.0
	_arm.global_transform = Transform3D(Basis(_side, Vector3.UP, _u) * Basis(Vector3.RIGHT, - _theta), _pivot)

func _find_player() -> CharacterBody3D:
	if Game.main and Game.main.player:
		return Game.main.player
	var root: = get_tree().current_scene
	if root:
		var pl: = root.find_child("Player", true, false)
		if pl is CharacterBody3D:
			return pl
		for c in root.get_children():
			for cc in c.get_children():
				if cc is CharacterBody3D and cc.has_method("start_carry"):
					return cc
	return null
