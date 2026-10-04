extends RefCounted





var L

func _init(level_builder) -> void :
	L = level_builder

static var _mats: = {}

func _m(key: String, c: Color, rough: = 0.8, metal: = 0.0, emit: = Color.BLACK, e: = 0.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var m: = StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		m.metallic = metal
		if e > 0.0:
			m.emission_enabled = true
			m.emission = emit
			m.emission_energy_multiplier = e
		_mats[key] = m
	return _mats[key]

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot: = Vector3.ZERO, sc: = Vector3.ONE) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = sc
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot: = Vector3.ZERO) -> MeshInstance3D:
	var bm: Mesh = Surf.box(size)
	return _mesh(parent, bm, pos, mat, rot)

func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material, segs: = 10, rt: = -1.0, rot: = Vector3.ZERO) -> MeshInstance3D:
	var cm: = CylinderMesh.new()
	cm.top_radius = r if rt < 0.0 else rt
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	return _mesh(parent, cm, pos, mat, rot)

func _tube(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material, segs: = 6) -> MeshInstance3D:
	var cm: = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = maxf(a.distance_to(b), 0.01)
	cm.radial_segments = segs
	cm.rings = 1
	var mi: = MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	parent.add_child(mi)
	var up: = (b - a).normalized() if a.distance_to(b) > 0.001 else Vector3.UP
	var sd: = up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(sd, up, sd.cross(up)), (a + b) * 0.5)
	return mi

func _cable(parent: Node3D, a: Vector3, b: Vector3, sag: float, r: float, mat: Material, segs: = 6) -> void :

	var prev: = a
	for i in range(1, segs + 1):
		var u: = float(i) / segs
		var q: = a.lerp(b, u) + Vector3(0, - sag * 4.0 * u * (1.0 - u), 0)
		_tube(parent, prev, q, r, mat, 4)
		prev = q

func _v3(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func build(p: Dictionary) -> Node3D:
	var kind: String = p.get("kind", "")
	var mech: Dictionary = p.get("m", {})
	var mtype: String = mech.get("type", "")
	var body: PhysicsBody3D
	if mtype == "crumble":
		body = AnimatableBody3D.new()
		(body as AnimatableBody3D).sync_to_physics = true
	elif mtype == "sag":
		body = AnimatableBody3D.new()
		body.set_meta("moving", true)
	else:
		body = StaticBody3D.new()
	body.position = _v3(p.p)
	var vis: = Node3D.new()
	vis.name = "Vis"
	var is_beam: = p.has("pitch")
	var d: = Vector3.ONE
	if is_beam:
		d = _v3(p.d)
		body.basis = Basis(Vector3.UP, float(p.r)) * Basis(Vector3.BACK, float(p.pitch))
		body.set_meta("beam_w", d.z)
		var cs: = CollisionShape3D.new()
		var bs: = BoxShape3D.new()
		bs.size = d
		cs.shape = bs
		body.add_child(cs)
	elif p.has("d"):
		d = _v3(p.d)
		body.rotation.y = float(p.get("r", 0.0))
		var cs2: = CollisionShape3D.new()
		var bs2: = BoxShape3D.new()
		bs2.size = d
		cs2.shape = bs2
		body.add_child(cs2)
	else:
		var rad: = float(p.rad)
		var h: = float(p.h)
		d = Vector3(rad * 2.0, h, rad * 2.0)
		var cs3: = CollisionShape3D.new()
		var cy: = CylinderShape3D.new()
		cy.radius = rad
		cy.height = h
		cs3.shape = cy
		body.add_child(cs3)
	body.add_child(vis)
	match kind:
		"epole":
			_epole(vis, d)
		"transformer", "junction":
			_transformer(vis, d, kind == "junction")
		"dish":
			_dish(vis, d)
		"plank":
			_scaffold_plank(vis, d)
		"girder":
			_girder(vis, d)
		"cloudlet":
			_cloudlet(vis, d, int(absf(float(p.p[0])) * 13.0))
		"ropeplank":
			_ropeplank(vis, d)
		"branch":
			_branch(vis, d, int(absf(float(p.p[2])) * 7.0))
		"nest":
			_nest(vis, d)
		"rail":
			_rail(vis, d)
		"shard":
			_shard(vis, d, int(absf(float(p.p[0]) * 3.0)))
		_:
			_box(vis, d, Vector3.ZERO, L.mat("concrete"))
	if mtype == "crumble":

		body.set_script(load("res://scripts/mech/crumble.gd"))
		body.set("delay", float(mech.get("delay", 0.8)))
		body.set("respawn", float(mech.get("respawn", 3.5)))
	elif mtype == "sag":
		body.set_script(load("res://scripts/mech/sag.gd"))
		if kind == "branch":
			body.set("dip", 0.1)
			body.set("roll", 0.035)

	L._merge_meshes(vis)
	if Game.mobile:
		for gi in body.find_children("*", "GeometryInstance3D", true, false):
			(gi as GeometryInstance3D).visibility_range_end = 380.0
			(gi as GeometryInstance3D).visibility_range_end_margin = 40.0
	return body


func _epole(v: Node3D, d: Vector3) -> void :

	var wood: = _m("ch_pole_wood", Color(0.36, 0.26, 0.18), 0.9)
	var dark: = _m("ch_pole_dark", Color(0.22, 0.16, 0.11), 0.9)
	var r: = d.z * 0.5
	var top: = d.y * 0.5
	_cyl(v, r, d.x, Vector3(0, top - r, 0), wood, 10, r * 0.88, Vector3(0, 0, PI * 0.5))

	for k in 4:
		var x: = - d.x * 0.4 + k * d.x * 0.27
		_cyl(v, r + 0.012, 0.05, Vector3(x, top - r, 0), _m("ch_band", Color(0.3, 0.3, 0.32), 0.4, 0.7), 10, -1.0, Vector3(0, 0, PI * 0.5))
	_box(v, Vector3(0.22, 0.3, 0.02), Vector3( - d.x * 0.1, top - r, r + 0.01), _m("ch_warn", Color(0.95, 0.8, 0.1), 0.6))
	_box(v, Vector3(0.5, 0.012, 0.05), Vector3(d.x * 0.15, top - 0.002, 0.04), dark)

	var cx: = d.x * 0.5 - 0.35
	_box(v, Vector3(0.12, 0.1, 1.5), Vector3(cx, top - r - 0.05, 0), dark)
	var glass: = _m("ch_insulator", Color(0.35, 0.75, 0.6), 0.15, 0.1)
	var wire: = _m("ch_wire", Color(0.05, 0.05, 0.06), 0.6, 0.3)
	for sz in [-0.65, 0.0, 0.65]:
		_cyl(v, 0.05, 0.14, Vector3(cx, top - r + 0.03, sz), glass, 8)
		_cable(v, Vector3(cx, top - r + 0.08, sz), Vector3(cx - d.x * 0.9, top - r - 1.5, sz * 1.6), 0.8, 0.012, wire, 6)

func _transformer(v: Node3D, d: Vector3, junction: bool) -> void :

	var metal: = _m("ch_trans", Color(0.52, 0.55, 0.56), 0.5, 0.6)
	var fins: = _m("ch_fins", Color(0.4, 0.43, 0.45), 0.5, 0.6)
	var wood: = _m("ch_pole_wood", Color(0.36, 0.26, 0.18), 0.9)
	var top: = d.y * 0.5
	_box(v, Vector3(d.x, 0.06, d.z), Vector3(0, top - 0.03, 0), metal)
	if junction:
		_box(v, Vector3(d.x * 0.9, 0.9, d.z * 0.9), Vector3(0, top - 0.5, 0), _m("ch_jbox", Color(0.22, 0.34, 0.3), 0.6, 0.3))
	else:
		_cyl(v, d.x * 0.42, 1.0, Vector3(0, top - 0.55, 0), metal, 12)
		for k in 6:
			var a: = TAU * k / 6.0
			_box(v, Vector3(0.05, 0.8, 0.22), Vector3(cos(a) * d.x * 0.45, top - 0.55, sin(a) * d.x * 0.45), fins, Vector3(0, - a, 0))
	_cyl(v, 0.2, 16.0, Vector3(0, top - 9.0, 0), wood, 8, 0.16)
	_box(v, Vector3(0.24, 0.24, 0.02), Vector3(0, top - 1.6, d.z * 0.5), _m("ch_warn", Color(0.95, 0.8, 0.1), 0.6))

	_cyl(v, 0.05, 0.06, Vector3(d.x * 0.42, top + 0.03, d.z * 0.42), _m("ch_redlamp", Color(1, 0.2, 0.15), 0.4, 0.0, Color(1, 0.15, 0.1), 3.0), 8)

func _dish(v: Node3D, d: Vector3) -> void :

	var steel: = _m("ch_dish_plate", Color(0.8, 0.8, 0.78), 0.45, 0.5)
	var mast: = _m("ch_mast", Color(0.35, 0.36, 0.38), 0.4, 0.7)
	var white: = _m("ch_dish_white", Color(0.94, 0.94, 0.92), 0.4, 0.1)
	var r: = d.x * 0.5
	var top: = d.y * 0.5
	_cyl(v, r, 0.08, Vector3(0, top - 0.04, 0), steel, 16)
	_cyl(v, r + 0.03, 0.05, Vector3(0, top - 0.1, 0), mast, 16)
	_cyl(v, 0.06, 11.0, Vector3(0, top - 5.6, 0), mast, 6)
	for k in 3:
		var a: = TAU * k / 3.0
		_tube(v, Vector3(0, top - 0.1, 0), Vector3(cos(a) * 1.4, top - 3.5, sin(a) * 1.4), 0.02, mast, 4)

	var sm: = SphereMesh.new()
	sm.radius = 0.42
	sm.height = 0.25
	sm.is_hemisphere = true
	_mesh(v, sm, Vector3(r + 0.25, top - 0.45, 0), white, Vector3(0, 0, -2.2))
	_tube(v, Vector3(r + 0.1, top - 0.45, 0), Vector3(r + 0.55, top - 0.1, 0), 0.015, mast, 4)

	_tube(v, Vector3( - r * 0.6, top, 0), Vector3( - r * 0.6, top + 1.1, 0), 0.015, mast, 4)
	for k in 4:
		var yy: = top + 0.5 + k * 0.17
		_tube(v, Vector3( - r * 0.6, yy, -0.28 + k * 0.03), Vector3( - r * 0.6, yy, 0.28 - k * 0.03), 0.01, mast, 4)

func _scaffold_plank(v: Node3D, d: Vector3) -> void :
	var plank: Material = L.mat("floor_wood")
	var tube: = _m("ch_scaffold", Color(0.62, 0.64, 0.66), 0.4, 0.8)
	var top: = d.y * 0.5
	for k in 3:
		_box(v, Vector3(d.x, d.y * 0.9, d.z / 3.0 - 0.03), Vector3(0, top - d.y * 0.45, - d.z / 3.0 + k * d.z / 3.0), plank)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_cyl(v, 0.035, 6.0, Vector3(sx * d.x * 0.42, top - 3.2, sz * d.z * 0.42), tube, 6)
	_tube(v, Vector3( - d.x * 0.42, top - 2.0, - d.z * 0.42), Vector3(d.x * 0.42, top - 4.5, d.z * 0.42), 0.03, tube, 6)

	_box(v, Vector3(d.x * 0.9, 0.05, 0.01), Vector3(0, top - 0.6, d.z * 0.43), _m("ch_tape", Color(1.0, 0.25, 0.2), 0.7))

func _girder(v: Node3D, d: Vector3) -> void :
	var ib: Material = L.mat("ibeam")
	var top: = d.y * 0.5
	_box(v, Vector3(d.x, 0.06, d.z), Vector3(0, top - 0.03, 0), ib)
	_box(v, Vector3(d.x, 0.36, 0.06), Vector3(0, top - 0.24, 0), ib)
	_box(v, Vector3(d.x, 0.06, d.z), Vector3(0, top - 0.45, 0), ib)

	var chain: = _m("ch_chain", Color(0.25, 0.25, 0.27), 0.5, 0.8)
	for sx in [-0.3, 0.3]:
		_tube(v, Vector3(sx * d.x, top, 0), Vector3(0, top + 7.0, 0), 0.025, chain, 4)

func _cloudlet(v: Node3D, d: Vector3, sd: int) -> void :
	var rng: = RandomNumberGenerator.new()
	rng.seed = sd
	var cm: Material = L.cloud_mat()
	var r: = d.x * 0.5
	var top: = d.y * 0.5
	_cyl(v, r, 0.25, Vector3(0, top - 0.13, 0), cm, 14)
	for k in 5:
		var rr: = rng.randf_range(0.35, 0.6) * r * 1.3
		var sm: = SphereMesh.new()
		sm.radius = rr
		sm.height = rr * 1.2
		sm.radial_segments = 10
		sm.rings = 5
		var a: = rng.randf() * TAU
		_mesh(v, sm, Vector3(cos(a) * r * 0.45, top - rr * 0.55, sin(a) * r * 0.45), cm)

func _ropeplank(v: Node3D, d: Vector3) -> void :
	var wood: Material = L.mat("rope_bridge")
	var rope: = _m("ch_rope", Color(0.8, 0.7, 0.5), 0.9)
	var top: = d.y * 0.5
	_box(v, Vector3(d.x * 0.62, d.y, d.z * 1.4), Vector3(0, 0, 0), wood)

	for sz in [-1.0, 1.0]:
		var z: float = sz * d.z * 0.72
		_cyl(v, 0.03, 1.0, Vector3(0, top + 0.45, z), rope, 5)
		_cable(v, Vector3( - d.x * 0.3, top + 0.9, z), Vector3(d.x * 0.3, top + 0.9, z), 0.05, 0.02, rope, 3)
		_tube(v, Vector3(d.x * 0.25, top, z), Vector3(d.x * 0.1, top - 1.4, z + sz * 0.1), 0.02, rope, 4)

func _branch(v: Node3D, d: Vector3, sd: int) -> void :
	var rng: = RandomNumberGenerator.new()
	rng.seed = sd
	var trunk: Material = L.mat("olive_trunk")
	var leaf: Material = L.mat("olive_leaf")
	var r: = d.z * 0.5
	var top: = d.y * 0.5
	_cyl(v, r * 1.1, d.x, Vector3(0, top - r, 0), trunk, 8, r * 0.7, Vector3(0, 0, PI * 0.5))
	for k in 3:
		var x: = - d.x * 0.3 + k * d.x * 0.3
		var sz: = 1.0 if k % 2 == 0 else -1.0
		_tube(v, Vector3(x, top - r, sz * 0.1), Vector3(x + 0.8, top + 0.4, sz * 1.1), r * 0.35, trunk, 5)
		var sm: = SphereMesh.new()
		sm.radius = rng.randf_range(0.45, 0.7)
		sm.height = sm.radius * 1.4
		sm.radial_segments = 8
		sm.rings = 4
		_mesh(v, sm, Vector3(x + 0.9, top + 0.6, sz * 1.25), leaf)

func _nest(v: Node3D, d: Vector3) -> void :
	var twig: Material = L.mat("olive_trunk")
	var r: = d.x * 0.5
	var top: = d.y * 0.5
	var tm: = TorusMesh.new()
	tm.inner_radius = r * 0.75
	tm.outer_radius = r * 1.05
	tm.rings = 18
	tm.ring_segments = 6
	_mesh(v, tm, Vector3(0, top - 0.05, 0), _m("ch_twigs", Color(0.45, 0.34, 0.2), 0.95))
	_cyl(v, r * 0.8, 0.2, Vector3(0, top - 0.12, 0), _m("ch_nest_in", Color(0.35, 0.26, 0.15), 0.95), 14)
	var egg: = _m("ch_egg", Color(0.85, 0.9, 0.95), 0.4)
	for k in 3:
		var a: = TAU * k / 3.0 + 0.4
		var sm: = SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.18
		_mesh(v, sm, Vector3(cos(a) * r * 0.55, top + 0.05, sin(a) * r * 0.55), egg)
	_cyl(v, 0.12, 5.0, Vector3(0, top - 2.6, 0), twig, 6, 0.08)

func _rail(v: Node3D, d: Vector3) -> void :
	var glow: = _m("ch_rail_glow", Color(1.0, 0.9, 0.62), 0.3, 0.0, Color(1.0, 0.85, 0.5), 2.4)
	var frame: = _m("ch_rail_frame", Color(0.26, 0.28, 0.36), 0.35, 0.8)
	var top: = d.y * 0.5
	_box(v, Vector3(d.x, 0.05, d.z * 0.6), Vector3(0, top - 0.025, 0), glow)
	_box(v, Vector3(d.x, d.y - 0.05, d.z), Vector3(0, -0.025, 0), frame)
	for sx in [-1.0, 1.0]:
		var sm: = SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		_mesh(v, sm, Vector3(sx * d.x * 0.5, top + 0.1, 0), glow)

func _shard(v: Node3D, d: Vector3, sd: int) -> void :
	var rng: = RandomNumberGenerator.new()
	rng.seed = sd
	var rock: Material = L.mat("asteroid_top")
	var crack: = _m("ch_crack", Color(0.6, 0.85, 1.0), 0.3, 0.0, Color(0.5, 0.8, 1.0), 2.0)
	var r: = d.x * 0.5
	var top: = d.y * 0.5
	_cyl(v, r, 0.3, Vector3(0, top - 0.15, 0), rock, 7)
	_cyl(v, r * 0.9, 1.4, Vector3(0, top - 1.0, 0), L.mat("asteroid"), 7, 0.1)
	for k in 3:
		var a: = rng.randf() * TAU
		_box(v, Vector3(r * 1.2, 0.015, 0.04), Vector3(cos(a) * r * 0.2, top + 0.005, sin(a) * r * 0.2), crack, Vector3(0, a, 0))
