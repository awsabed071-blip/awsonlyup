extends "res://scripts/mech/eagle_lift.gd"




var _kite: Node3D
var _tail: Array[Node3D] = []
var _snd_t: = 0.0

func _mat2(key: String, c: Color, rough: = 0.7, emit: = 0.0) -> StandardMaterial3D:
	var m: = _mat(key, c, rough)
	if emit > 0.0 and not m.emission_enabled:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _build_post(at: Vector3) -> void :
	var wood: = _mat("wood", Color(0.45, 0.3, 0.18))
	var pole: = CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.09
	pole.height = 1.3
	pole.radial_segments = 8
	_mesh(self, pole, at + Vector3(0, 0.65, 0), wood)

	var spool: = CylinderMesh.new()
	spool.top_radius = 0.16
	spool.bottom_radius = 0.16
	spool.height = 0.2
	spool.radial_segments = 12
	_mesh(self, spool, at + Vector3(0, 1.35, 0), _mat("kite_spool", Color(0.85, 0.8, 0.66), 0.9), Vector3(PI * 0.5, 0, 0))

func _build_eagle() -> void :

	_head = Node3D.new()
	_eagle.add_child(_head)
	_wing_l = Node3D.new()
	_wing_r = Node3D.new()
	_eagle.add_child(_wing_l)
	_eagle.add_child(_wing_r)
	var stick: = _mat("kite_stick", Color(0.5, 0.36, 0.2), 0.8)
	var string_m: = _mat("kite_string", Color(0.95, 0.93, 0.85), 0.9)
	var bar: = CylinderMesh.new()
	bar.top_radius = 0.035
	bar.bottom_radius = 0.035
	bar.height = 0.7
	bar.radial_segments = 6
	_mesh(_eagle, bar, Vector3(0, -0.42, 0), stick, Vector3(0, 0, PI * 0.5))
	_kite = Node3D.new()
	_kite.position = Vector3(0, 2.4, 0)
	_eagle.add_child(_kite)

	for sx in [-1.0, 1.0]:
		var a: = Vector3(sx * 0.33, -0.42, 0)
		var b: = Vector3(0, 1.75, 0.05)
		var cm: = CylinderMesh.new()
		cm.top_radius = 0.006
		cm.bottom_radius = 0.006
		cm.height = a.distance_to(b)
		cm.radial_segments = 4
		var mi: = _mesh(_eagle, cm, (a + b) * 0.5, string_m)
		var up: = (b - a).normalized()
		var sd: = up.cross(Vector3.FORWARD).normalized()
		mi.transform = Transform3D(Basis(sd, up, sd.cross(up)), (a + b) * 0.5)

	var H: = 1.5
	var W: = 1.05
	var top: = Vector3(0, H, 0)
	var bot: = Vector3(0, - H * 0.9, 0)
	var lft: = Vector3( - W, H * 0.25, 0)
	var rgt: = Vector3(W, H * 0.25, 0)
	var ctr: = Vector3(0, H * 0.25, 0)
	var cols: = [Color(0.85, 0.12, 0.14), Color(0.1, 0.55, 0.3), Color(0.96, 0.95, 0.9), Color(0.1, 0.1, 0.12)]
	var tris: = [[top, rgt, ctr], [rgt, bot, ctr], [bot, lft, ctr], [lft, top, ctr]]
	for k in 4:
		var st: = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in tris[k]:
			st.set_normal(Vector3.BACK)
			st.add_vertex(v)
		var am: = st.commit()
		var mi2: = MeshInstance3D.new()
		mi2.mesh = am
		mi2.material_override = _mat2("kite_%d" % k, cols[k], 0.8, 0.25)
		_kite.add_child(mi2)
	var sv: = CylinderMesh.new()
	sv.top_radius = 0.02
	sv.bottom_radius = 0.02
	sv.height = H * 1.9
	sv.radial_segments = 5
	_mesh(_kite, sv, Vector3(0, H * 0.05, 0.02), stick)
	var sh: = CylinderMesh.new()
	sh.top_radius = 0.02
	sh.bottom_radius = 0.02
	sh.height = W * 2.0
	sh.radial_segments = 5
	_mesh(_kite, sh, Vector3(0, H * 0.25, 0.02), stick, Vector3(0, 0, PI * 0.5))

	var prev: Node3D = _kite
	for k in 7:
		var seg: = Node3D.new()
		seg.position = Vector3(0, - H * 0.9 if k == 0 else -0.45, 0)
		prev.add_child(seg)
		var bow: = BoxMesh.new()
		bow.size = Vector3(0.3, 0.1, 0.02)
		_mesh(seg, bow, Vector3.ZERO, _mat2("kite_bow%d" % (k % 3), [Color(0.95, 0.75, 0.2), Color(0.85, 0.12, 0.14), Color(0.96, 0.95, 0.9)][k % 3], 0.8, 0.2), Vector3(0, 0, 0.6 if k % 2 == 0 else -0.6))
		_tail.append(seg)
		prev = seg

func _cry() -> void :
	Sfx.play("kite", -6.0, 0.1)

func _fold(delta: float) -> void :

	_kite.rotation.z = sin(_t * 1.3) * 0.25
	_kite.rotation.x = -0.25 + sin(_t * 0.9) * 0.08
	_eagle.rotation.x = lerpf(_eagle.rotation.x, 0.0, 1.0 - exp(-4.0 * delta))
	_eagle.position.y += sin(_t * 1.1) * 0.004
	_wave_tail(1.0)

func _flap_wings(delta: float, freq: float, amp: float) -> void :
	_kite.rotation.z = sin(_t * 2.1) * 0.35 * amp
	_kite.rotation.x = -0.35
	_wave_tail(2.0)

func _wave_tail(speed: float) -> void :
	for k in _tail.size():
		_tail[k].rotation.z = sin(_t * 3.0 * speed - k * 0.7) * 0.35
		_tail[k].rotation.x = sin(_t * 2.1 * speed - k * 0.5) * 0.2
