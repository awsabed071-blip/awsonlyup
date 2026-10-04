extends Node3D




var height: = 18.0
var to: = Vector3.ZERO
var radius: = 1.6

const HALF: = 1.05
const SPEED: = 2.3

var car: AnimatableBody3D
var plank: AnimatableBody3D
var state: = "bottom"
var plank_out: = false
var _area: Area3D
var _inside: Array = []
var _y: = 0.0
var _top_y: = 10.0
var _t: = 0.0
var _wait: = 0.0
var _empty_t: = 0.0
var _seq: = []
var _seq_i: = 0
var _seq_t: = 0.0
var _dir: = Vector3.FORWARD
var _plank_len: = 3.0
var _plank_k: = 0.0
var _lamp: OmniLight3D
var _lamp_mat: StandardMaterial3D
var _cable: MeshInstance3D
var _sparks: GPUParticles3D
var _shake: = 0.0
var _hum: AudioStreamPlayer3D

static var _mats: = {}

func _mat(key: String, c: Color, metal: = 0.0, rough: = 0.7) -> StandardMaterial3D:
	if not _mats.has(key):
		var m: = StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = metal
		m.roughness = rough
		_mats[key] = m
	return _mats[key]

func _ready() -> void :
	var loc_to: = to_local(to)
	_top_y = loc_to.y
	var flat: = Vector3(loc_to.x, 0, loc_to.z)
	_dir = flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD
	_plank_len = maxf(flat.length() - HALF + 0.55, 1.0)
	_build_shaft()
	_build_car()
	_build_plank()
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var cs: = CollisionShape3D.new()
	var bs: = BoxShape3D.new()
	bs.size = Vector3(HALF * 2.0 - 0.1, 1.2, HALF * 2.0 - 0.1)
	cs.shape = bs
	cs.position = Vector3(0, 0.7, 0)
	_area.add_child(cs)
	car.add_child(_area)
	_area.body_entered.connect( func(b): if b is CharacterBody3D: _inside.append(b))
	_area.body_exited.connect( func(b): _inside.erase(b))
	_set_car(0.0)


func _make_sequence() -> void :

	_seq.clear()
	var y: = 0.0
	var stops: = [0.36, 0.7]
	for f in stops:
		var ys: float = _top_y * f
		_seq.append(["move", (ys - y) / SPEED, y, ys])
		_seq.append(["stall", 0.55, ys, ys])
		_seq.append(["sag", 0.16, ys, ys - 0.4])
		_seq.append(["stall", 0.45, ys - 0.4, ys - 0.4])
		y = ys - 0.4
	_seq.append(["move", (_top_y - y) / SPEED, y, _top_y])
	_seq_i = 0
	_seq_t = 0.0

func _physics_process(delta: float) -> void :
	_t += delta
	var standing: = false
	for b in _inside:
		if is_instance_valid(b) and b.is_on_floor():
			standing = true
	match state:
		"bottom":
			if standing:
				_wait += delta
				if _wait > 0.5:
					_make_sequence()
					state = "rising"
					_wait = 0.0
					Sfx.play("creak", -4.0, 0.08)
					if _hum:
						_hum.play()
			else:
				_wait = 0.0
		"rising":
			_seq_t += delta
			var seg: Array = _seq[_seq_i]
			var k: = clampf(_seq_t / maxf(float(seg[1]), 0.01), 0.0, 1.0)
			var e: = k
			if seg[0] == "move":
				e = k * k * (3.0 - 2.0 * k) if float(seg[1]) < 2.0 else k
			_set_car(lerpf(float(seg[2]), float(seg[3]), e))
			if k >= 1.0:
				_seq_i += 1
				_seq_t = 0.0
				if _seq_i < _seq.size():
					var nxt: String = _seq[_seq_i][0]
					if nxt == "sag":
						_bang()
					elif seg[0] == "move" and nxt == "stall":
						Sfx.play("creak", -6.0, 0.1)
				else:
					state = "top"
					_wait = 0.0
					_empty_t = 0.0
					Sfx.play("ding", -4.0, 0.0)
					if _hum:
						_hum.stop()
		"top":
			_plank_k = minf(_plank_k + delta / 0.7, 1.0)
			plank_out = _plank_k >= 0.99
			if standing:
				_empty_t = 0.0
			else:
				_empty_t += delta
			if (_empty_t > 3.5 and _plank_k >= 1.0) or _empty_t > 9.0:
				state = "lowering"
		"lowering":
			_plank_k = maxf(_plank_k - delta / 0.6, 0.0)
			plank_out = false
			if _plank_k <= 0.0:
				_set_car(maxf(_y - SPEED * 1.4 * delta, 0.0))
				if _y <= 0.001:
					state = "bottom"
	_update_plank()

	_shake = maxf(_shake - delta * 2.5, 0.0)
	var sh: = Vector3(sin(_t * 61.0), 0, cos(_t * 53.0)) * 0.035 * _shake
	for c in car.get_children():
		if c is MeshInstance3D and c.has_meta("frame"):
			(c as MeshInstance3D).position = c.get_meta("base") + sh

	var flick: = 0.75 + 0.25 * sin(_t * 9.0) * sin(_t * 23.0)
	if fmod(_t, 4.1) < 0.12 or _shake > 0.3:
		flick *= 0.25
	_lamp.light_energy = 1.3 * flick
	_lamp_mat.emission_energy_multiplier = 3.0 * flick

func _bang() -> void :
	_shake = 1.0
	Sfx.play("clank", -1.0, 0.05)
	_sparks.restart()
	_sparks.emitting = true
	if Game.main and Game.main.rig:
		for b in _inside:
			if b == Game.main.player:
				Game.main.rig.add_shake(0.5)
				Game.haptic(40, 0.7)

func _set_car(y: float) -> void :
	_y = y
	car.position = Vector3(0, y - 0.1, 0)
	var top: = _top_y + 3.6
	var L: = maxf(top - (y + 2.55), 0.1)
	_cable.scale = Vector3(1, L, 1)
	_cable.position = Vector3(0, y + 2.55 + L * 0.5, 0)

func _update_plank() -> void :
	var yaw: = atan2(_dir.x, _dir.z)
	var ext: = _plank_k * _plank_len
	plank.visible = _plank_k > 0.01
	plank.position = Vector3(0, _top_y - 0.09, 0) + _dir * (HALF - _plank_len * 0.5 + ext)
	plank.rotation = Vector3(0, yaw, 0)
	for c in plank.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = _plank_k < 0.95


func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, frame: = false) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	var bm: = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = m
	if frame:
		mi.set_meta("frame", true)
		mi.set_meta("base", pos)
	parent.add_child(mi)
	return mi

func _build_shaft() -> void :
	var rail: = _mat("rail", Color(0.35, 0.33, 0.3), 0.7, 0.45)
	var rust: = _mat("rust", Color(0.55, 0.28, 0.14), 0.4, 0.8)
	var top: = _top_y + 3.6

	var back: = - _dir
	var side: = Vector3( - _dir.z, 0, _dir.x)
	for sd in [-1.0, 1.0]:
		var p: Vector3 = back * (HALF + 0.12) + side * sd * (HALF + 0.12)
		_box(self, Vector3(0.14, top, 0.14), p + Vector3(0, top * 0.5 - 0.1, 0), rail)
	var beam: = _box(self, Vector3(0.22, 0.22, 2.0 * HALF + 0.5), back * (HALF + 0.12) + Vector3(0, top, 0), rust)
	beam.rotation.y = atan2(side.x, side.z)
	var arm: = _box(self, Vector3(0.16, 0.16, HALF + 0.3), back * (HALF * 0.5) + Vector3(0, top, 0), rust)
	arm.rotation.y = atan2(_dir.x, _dir.z)
	var wheel: = MeshInstance3D.new()
	var tm: = TorusMesh.new()
	tm.inner_radius = 0.16
	tm.outer_radius = 0.3
	wheel.mesh = tm
	wheel.position = Vector3(0, top - 0.1, 0)
	wheel.rotation = Vector3(0, atan2(side.x, side.z), PI * 0.5)
	wheel.material_override = rail
	add_child(wheel)
	_cable = MeshInstance3D.new()
	var cm: = CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.025
	cm.height = 1.0
	cm.radial_segments = 5
	_cable.mesh = cm
	_cable.material_override = _mat("cable", Color(0.12, 0.12, 0.12), 0.5, 0.5)
	add_child(_cable)

	var sign_mat: = _mat("warn", Color(0.95, 0.75, 0.1), 0.0, 0.6)
	var sgn: = _box(self, Vector3(0.7, 0.45, 0.04), back * (HALF + 0.2) + side * 0.0 + Vector3(0, 1.5, 0), sign_mat)
	sgn.rotation.y = atan2(_dir.x, _dir.z)

func _build_car() -> void :
	car = AnimatableBody3D.new()
	car.sync_to_physics = true
	car.set_meta("moving", true)
	add_child(car)
	var steel: = _mat("steel", Color(0.5, 0.52, 0.55), 0.6, 0.4)
	var paint: = _mat("paint", Color(0.2, 0.45, 0.55), 0.2, 0.6)
	var rust: = _mat("rust", Color(0.55, 0.28, 0.14), 0.4, 0.8)

	var cs: = CollisionShape3D.new()
	var bs: = BoxShape3D.new()
	bs.size = Vector3(HALF * 2.0, 0.2, HALF * 2.0)
	cs.shape = bs
	car.add_child(cs)
	_box(car, Vector3(HALF * 2.0, 0.2, HALF * 2.0), Vector3.ZERO, steel)

	var side: = Vector3( - _dir.z, 0, _dir.x)
	for a in [Vector3(1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(-1, 0, -1)]:
		_box(car, Vector3(0.1, 2.4, 0.1), a * (HALF - 0.06) + Vector3(0, 1.3, 0), paint, true)
	_box(car, Vector3(HALF * 2.0 + 0.1, 0.12, HALF * 2.0 + 0.1), Vector3(0, 2.55, 0), paint, true)
	for sd in [-1.0, 1.0]:
		var r: = _box(car, Vector3(0.06, 0.06, HALF * 2.0), side * sd * (HALF - 0.06) + Vector3(0, 1.05, 0), rust, true)
		r.rotation.y = atan2(_dir.x, _dir.z)

	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color(1.0, 0.9, 0.6)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1.0, 0.8, 0.45)
	var bulb: = MeshInstance3D.new()
	var sm: = SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	bulb.mesh = sm
	bulb.material_override = _lamp_mat
	bulb.position = Vector3(0, 2.4, 0)
	car.add_child(bulb)
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.82, 0.5)
	_lamp.omni_range = 4.5
	_lamp.position = Vector3(0, 2.3, 0)
	car.add_child(_lamp)

	_sparks = GPUParticles3D.new()
	_sparks.amount = 40
	_sparks.lifetime = 0.7
	_sparks.one_shot = true
	_sparks.explosiveness = 0.9
	_sparks.emitting = false
	var pm: = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -12, 0)
	pm.color = Color(1.0, 0.75, 0.3)
	_sparks.process_material = pm
	var qm: = QuadMesh.new()
	qm.size = Vector2(0.05, 0.05)
	var spm: = StandardMaterial3D.new()
	spm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spm.albedo_color = Color(1.0, 0.8, 0.35)
	spm.vertex_color_use_as_albedo = true
	spm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.material = spm
	_sparks.draw_pass_1 = qm
	_sparks.position = - _dir * HALF + Vector3(0, 2.5, 0)
	car.add_child(_sparks)

	var hs: AudioStream = Sfx._load("motor_loop")
	if hs:
		_hum = AudioStreamPlayer3D.new()
		_hum.stream = hs
		_hum.bus = "SFX"
		_hum.volume_db = -10.0
		_hum.unit_size = 6.0
		_hum.max_distance = 40.0
		car.add_child(_hum)

func _build_plank() -> void :
	plank = AnimatableBody3D.new()
	plank.sync_to_physics = true
	plank.set_meta("moving", true)
	add_child(plank)
	var cs: = CollisionShape3D.new()
	var bs: = BoxShape3D.new()
	bs.size = Vector3(1.2, 0.18, _plank_len)
	cs.shape = bs
	plank.add_child(cs)
	var wood: = _mat("plank", Color(0.62, 0.45, 0.26), 0.0, 0.85)
	var mi: = MeshInstance3D.new()
	var bm: = BoxMesh.new()
	bm.size = Vector3(1.2, 0.18, _plank_len)
	mi.mesh = bm
	mi.material_override = wood
	plank.add_child(mi)

	var stripe: = _mat("stripe", Color(0.95, 0.8, 0.2), 0.0, 0.6)
	for k in int(_plank_len / 0.8):
		var s: = MeshInstance3D.new()
		var sb: = BoxMesh.new()
		sb.size = Vector3(1.0, 0.02, 0.12)
		s.mesh = sb
		s.position = Vector3(0, 0.1, - _plank_len * 0.5 + 0.4 + k * 0.8)
		s.material_override = stripe
		plank.add_child(s)
