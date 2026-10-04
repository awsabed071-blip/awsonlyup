extends RefCounted



var B

func _init(builder) -> void :
	B = builder


func _box(parent: Node3D, size: Vector3, pos: Vector3, m: String, collide: = false, basis: = Basis.IDENTITY) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	var bm: Mesh = Surf.box(size)
	mi.mesh = bm
	mi.transform = Transform3D(basis, pos)
	mi.material_override = B.mat(m)
	parent.add_child(mi)
	if collide:
		var cs: = CollisionShape3D.new()
		var bs: = BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.transform = Transform3D(basis, pos)
		parent.add_child(cs)
	return mi

func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, m: String, segs: = 20, r_top: = -1.0, collide: = false) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	var cm: = CylinderMesh.new()
	cm.top_radius = r if r_top < 0.0 else r_top
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.position = pos
	mi.material_override = B.mat(m)
	parent.add_child(mi)
	if collide:
		var cs: = CollisionShape3D.new()
		var sh: = CylinderShape3D.new()
		sh.radius = maxf(r, r_top)
		sh.height = h
		cs.shape = sh
		cs.position = pos
		parent.add_child(cs)
	return mi

func _beam_mesh(parent: Node3D, pairs: Array, t: float, m: String) -> MeshInstance3D:
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pr in pairs:
		B._st_beam(st, pr[0], pr[1], t)
	st.generate_normals()
	var mi: = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = B.mat(m)
	parent.add_child(mi)
	return mi

func _light(parent: Node3D, pos: Vector3, col: Color, energy: float, rng_: float) -> OmniLight3D:
	var l: = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_
	l.position = pos
	l.shadow_enabled = false
	parent.add_child(l)
	return l

func _label(parent: Node3D, text: String, pos: Vector3, size: = 96, col: = Color(0.1, 0.35, 0.38)) -> Label3D:
	var lb: = Label3D.new()
	lb.text = text
	lb.font = load("res://assets/fonts/Lalezar.ttf")
	lb.font_size = size
	lb.pixel_size = 0.01
	lb.modulate = col
	lb.outline_size = 0
	lb.position = pos
	lb.double_sided = false
	lb.shaded = true
	parent.add_child(lb)
	return lb

func _v3(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func tower(p: Dictionary) -> Node3D:
	var body: = StaticBody3D.new()
	var cx: float = p.c[0]
	var cz: float = p.c[1]
	body.position = Vector3(cx, 0, cz)
	var rt: float = p.rt
	var rin: float = p.rin
	var rout: float = p.rout
	var rm: = (rin + rout) * 0.5
	var th0: float = p.th0
	var sg: float = p.dir
	var dth: float = p.dth
	var sh: float = p.sh
	var y0: float = p.y0
	var n: int = int(p.n)
	var top: float = p.top
	var base: float = p.base

	var h: = top - base
	_cyl(body, rt, h, Vector3(0, base + h * 0.5, 0), "tank_white", 40, -1.0, true)

	for k in [0.12, 0.5, 0.88]:
		_cyl(body, rt + 0.03, 0.35, Vector3(0, base + h * k, 0), "tank_band", 40)
	_cyl(body, rt + 0.08, 0.22, Vector3(0, top - 0.11, 0), "tank_band", 40)

	_cyl(body, rt + 0.3, 0.8, Vector3(0, base - 0.4, 0), "concrete", 24)
	var legs: = []
	for i in 4:
		var a: = TAU * i / 4.0 + 0.4
		var tp: = Vector3(cos(a) * (rt - 0.6), base - 0.8, sin(a) * (rt - 0.6))
		var bt: = Vector3(cos(a) * (rt + 0.4), base - 7.0, sin(a) * (rt + 0.4))
		legs.append([tp, bt])
	for i in 4:
		var a1: Vector3 = legs[i][0].lerp(legs[i][1], 0.45)
		var a2: Vector3 = legs[(i + 1) % 4][0].lerp(legs[(i + 1) % 4][1], 0.45)
		legs.append([a1, a2])
	_beam_mesh(body, legs, 0.28, "rail")
	var rng: = RandomNumberGenerator.new()
	rng.seed = int(p.get("seed", 1))
	var rock: = MeshInstance3D.new()
	rock.mesh = B._island_visual(B._island_mesh(rt + 2.2, 7.0, rng, 0.3, false), rt + 2.2, int(p.get("seed", 1)))
	rock.position = Vector3(0, base - 7.0, 0)
	rock.set_surface_override_material(0, B.mat("mossy"))
	rock.set_surface_override_material(1, B.mat("rock"))
	body.add_child(rock)

	var rail_from: = int(p.get("rail_from", 4))
	var rail_n: = int(p.get("rail_n", n - 12))
	var tread: = 0.92 / rm + 0.02
	for k in n:
		var th: = th0 + sg * k * dth
		var yk: = y0 + k * sh
		var c: = Vector3(cos(th) * rm, yk - sh * 0.5, sin(th) * rm)
		var bas: = Basis(Vector3.UP, - th)
		_box(body, Vector3(rout - rin, sh, tread * rm + 0.04), c, "grating", false, bas)

		var pitch: = atan2(sh, dth * rm)
		var seg: = dth * rm / cos(pitch) + 0.06
		var rb: = bas * Basis(Vector3.RIGHT, - pitch * sg)
		var rcs: = CollisionShape3D.new()
		var rbs: = BoxShape3D.new()
		var rr: = (rt + rout) * 0.5
		rbs.size = Vector3(rout - rt, 0.3, seg * rr / rm)
		rcs.shape = rbs
		rcs.transform = Transform3D(rb, Vector3(cos(th) * rr, yk, sin(th) * rr) - rb.y * 0.15)
		body.add_child(rcs)

		if k % 2 == 0:
			var inner: = Vector3(cos(th) * (rin + 0.05), yk - sh - 0.5, sin(th) * (rin + 0.05))
			var outer: = Vector3(cos(th) * (rout - 0.15), yk - sh, sin(th) * (rout - 0.15))
			_beam_mesh(body, [[inner, outer]], 0.07, "rail")

		if k >= rail_from and k < rail_n:
			var ro: = rout - 0.05
			var pa: = Vector3(cos(th) * ro, yk, sin(th) * ro)
			var ths: = th + sg * dth
			var pb: = Vector3(cos(ths) * ro, yk + sh, sin(ths) * ro)
			if k % 3 == 0:
				_beam_mesh(body, [[pa, pa + Vector3(0, 1.0, 0)]], 0.06, "rail")
			_beam_mesh(body, [[pa + Vector3(0, 1.0, 0), pb + Vector3(0, 1.0, 0)]], 0.05, "tank_band")
			_beam_mesh(body, [[pa + Vector3(0, 0.5, 0), pb + Vector3(0, 0.5, 0)]], 0.035, "rail")
			var mid: = (pa + pb) * 0.5 + Vector3(0, 0.5, 0)
			var cs: = CollisionShape3D.new()
			var bs: = BoxShape3D.new()
			bs.size = Vector3(0.1, 1.0, pa.distance_to(pb) + 0.05)
			cs.shape = bs
			cs.position = mid
			cs.basis = Basis(Vector3.UP, - th)
			body.add_child(cs)

	var br: Array = p.get("bridge", [])
	if br.size() == 5:
		var a: = Vector3(float(br[0]) - cx, float(br[4]), float(br[1]) - cz)
		var b: = Vector3(float(br[2]) - cx, float(br[4]), float(br[3]) - cz)
		var L: = Vector2(b.x - a.x, b.z - a.z).length()
		if L > 0.05:
			var yaw: = atan2( - (b.z - a.z), b.x - a.x)
			var bas: = Basis(Vector3.UP, yaw)
			_box(body, Vector3(L + 0.3, 0.3, 1.4), (a + b) * 0.5 - Vector3(0, 0.15, 0), "floor_wood", true, bas)
			for sgn in [-1.0, 1.0]:
				var off: = bas * Vector3(0, 0, sgn * 0.68)
				_beam_mesh(body, [[a + off - Vector3(0, 0.3, 0), b + off - Vector3(0, 0.3, 0)]], 0.08, "rail")

	var th_end: = th0 + sg * (n - 1) * dth
	var far: = Vector3(cos(th_end + PI), 0, sin(th_end + PI))
	_cyl(body, 0.45, 0.35, Vector3(0, top + 0.17, 0) + far * 1.2, "tank_band", 16)
	var pole_base: = far * (rt - 0.35) + Vector3(0, top, 0)
	_beam_mesh(body, [[pole_base, pole_base + Vector3(0, 3.2, 0)]], 0.07, "rail")
	var flag: = _box(body, Vector3(0.04, 0.7, 1.1), pole_base + Vector3(0, 2.8, 0.58), "carpet")
	flag.rotation.y = - th_end

	var lab_a: = th0 + PI
	var lb: = _label(body, "خزّان الحارة", Vector3(cos(lab_a) * (rt + 0.05), base + h * 0.3, sin(lab_a) * (rt + 0.05)), 160)
	lb.rotation.y = - lab_a + PI * 0.5
	B._merge_meshes(body)
	return body


func station(p: Dictionary) -> Node3D:
	var d: = _v3(p.d)
	var body: = StaticBody3D.new()
	body.position = _v3(p.p)
	body.rotation.y = p.get("r", 0.0)
	var tag: String = p.get("tag", "")
	var mname: String = p.get("mat", "concrete")
	_box(body, d, Vector3.ZERO, mname, true)
	var hy: = d.y * 0.5
	if tag.ends_with("train"):

		for sx in [-1.0, 1.0]:
			_box(body, Vector3(0.25, 0.04, d.z), Vector3(sx * (d.x * 0.5 - 0.13), hy + 0.02, 0), "ibeam")
		_box(body, Vector3(d.x + 0.1, 0.35, d.z + 0.1), Vector3(0, - hy + 0.1, 0), "limestone")
		var post: = Vector3( - d.x * 0.3, hy, d.z * 0.5 - 0.2)
		_beam_mesh(body, [[post, post + Vector3(0, 3.6, 0)]], 0.1, "rail")
		var sign: = _box(body, Vector3(1.9, 0.6, 0.08), post + Vector3(0, 3.3, 0), "tank_band")
		var lb: = _label(body, "محطة", post + Vector3(0, 3.3, 0.06), 64, Color(1, 1, 1))
		lb.shaded = false
		var lb2: = _label(body, "محطة", post + Vector3(0, 3.3, -0.06), 64, Color(1, 1, 1))
		lb2.rotation.y = PI
		lb2.shaded = false
		_light(body, post + Vector3(0, 3.0, 0), Color(1.0, 0.85, 0.6), 0.8, 7.0)
	elif tag.ends_with("crane"):
		var trim: = _box(body, Vector3(d.x + 0.02, d.y * 0.5, d.z + 0.02), Vector3(0, - d.y * 0.25, 0), "ibeam")
		var m: = (B.mat("ibeam") as ShaderMaterial).duplicate()
		m.set_shader_parameter("hazard", 1.0)
		trim.material_override = m
		_box(body, Vector3(0.9, 0.9, 0.9), Vector3(d.x * 0.3, hy + 0.45, - d.z * 0.3), "drum", true)
	elif tag.ends_with("balloon"):
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var q: = Vector3(sx * (d.x * 0.5 - 0.15), hy, sz * (d.z * 0.5 - 0.15))
				_beam_mesh(body, [[q - Vector3(0, 0.6, 0), q + Vector3(0, 0.45, 0)]], 0.14, "olive_trunk")
		_light(body, Vector3(0, hy + 1.2, 0), Color(1.0, 0.75, 0.45), 0.6, 6.0)
	elif tag.ends_with("rocket"):

		var pairs: = []
		var w: = d.x * 0.5 - 0.3
		for i in 6:
			var y: = - hy - i * 2.5
			pairs.append([Vector3( - w, y, - w), Vector3(w, y, - w)])
			pairs.append([Vector3( - w, y, w), Vector3(w, y, w)])
			pairs.append([Vector3( - w, y, - w), Vector3(w, y - 2.5, - w)])
			pairs.append([Vector3(w, y, w), Vector3( - w, y - 2.5, w)])
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				pairs.append([Vector3(sx * w, - hy, sz * w), Vector3(sx * w, - hy - 15.0, sz * w)])
		_beam_mesh(body, pairs, 0.12, "rocket_red")
		for sx in [-1.0, 1.0]:
			var bl: = _cyl(body, 0.12, 0.2, Vector3(sx * (d.x * 0.5 - 0.2), hy + 0.1, d.z * 0.5 - 0.2), "lamp_glow", 10)
		_light(body, Vector3(0, hy + 1.5, 0), Color(0.6, 0.8, 1.0), 0.7, 8.0)
	B._merge_meshes(body)
	return body


func viaduct(p: Dictionary) -> Node3D:
	var d: = _v3(p.d)
	var body: = StaticBody3D.new()
	body.position = _v3(p.p)
	body.basis = Basis(Vector3.UP, p.r) * Basis(Vector3.BACK, p.pitch)
	_box(body, d, Vector3.ZERO, "concrete", true)
	var hy: = d.y * 0.5
	for sz in [-0.72, 0.72]:
		_box(body, Vector3(d.x, 0.12, 0.12), Vector3(0, hy + 0.06, sz), "rail")
	var n: = int(d.x / 1.2)
	for i in n:
		_box(body, Vector3(0.22, 0.07, 2.2), Vector3( - d.x * 0.5 + (i + 0.5) * d.x / n, hy + 0.01, 0), "wood")

	var np: = int(d.x / 9.0) + 1
	for i in np:
		var x: = - d.x * 0.5 + 2.0 + i * (d.x - 4.0) / maxf(np - 1, 1)
		var pil: = MeshInstance3D.new()
		var bm: Mesh = Surf.box(Vector3(1.2, 16.0, 1.6))
		pil.mesh = bm
		pil.material_override = B.mat("concrete")
		body.add_child(pil)
		var inv: = Basis(Vector3.BACK, - float(p.pitch))
		pil.transform = Transform3D(inv, Vector3(x, - hy - 8.0 / cos(float(p.pitch)), 0))
	B._merge_meshes(body)
	return body


func crane_mast(p: Dictionary) -> Node3D:
	var d: = _v3(p.d)
	var body: = StaticBody3D.new()
	body.position = _v3(p.p)
	body.rotation.y = p.get("r", 0.0)
	var cs: = CollisionShape3D.new()
	var bs: = BoxShape3D.new()
	bs.size = d
	cs.shape = bs
	body.add_child(cs)
	var w: = d.x * 0.5 - 0.1
	var hy: = d.y * 0.5
	var pairs: = []
	var corners: = [Vector3( - w, 0, - w), Vector3(w, 0, - w), Vector3(w, 0, w), Vector3( - w, 0, w)]
	for k in 4:
		pairs.append([corners[k] + Vector3(0, - hy, 0), corners[k] + Vector3(0, hy, 0)])
	var seg: = 2.4
	var nn: = int(d.y / seg)
	for i in nn:
		var y: = - hy + i * seg
		for k in 4:
			var a: Vector3 = corners[k] + Vector3(0, y, 0)
			var b: Vector3 = corners[(k + 1) % 4] + Vector3(0, y, 0)
			pairs.append([a, b])
			pairs.append([a, corners[(k + 1) % 4] + Vector3(0, y + seg, 0)])
	_beam_mesh(body, pairs, 0.13, "ibeam")

	_box(body, Vector3(2.4, 2.0, 2.0), Vector3(0, hy - 1.0, 1.6), "train_cream")
	_box(body, Vector3(2.45, 0.8, 2.05), Vector3(0, hy - 0.6, 1.6), "glass")
	_box(body, Vector3(3.0, 0.8, 3.0), Vector3(0, - hy + 0.4, 0), "concrete")
	B._merge_meshes(body)
	return body

func crane_jib(p: Dictionary) -> Node3D:
	var d: = _v3(p.d)
	var body: = StaticBody3D.new()
	body.position = _v3(p.p)
	body.rotation.y = p.get("r", 0.0)
	var cs: = CollisionShape3D.new()
	var bs: = BoxShape3D.new()
	bs.size = d
	cs.shape = bs
	body.add_child(cs)
	var hx: = d.x * 0.5
	var hy: = d.y * 0.5
	var hz: = d.z * 0.5 - 0.05
	var pairs: = []
	pairs.append([Vector3( - hx, - hy, - hz), Vector3(hx, - hy, - hz)])
	pairs.append([Vector3( - hx, - hy, hz), Vector3(hx, - hy, hz)])
	pairs.append([Vector3( - hx, hy, 0), Vector3(hx, hy, 0)])
	var n: = int(d.x / 1.6)
	for i in n + 1:
		var x: = - hx + i * d.x / maxf(n, 1)
		pairs.append([Vector3(x, - hy, - hz), Vector3(x, - hy, hz)])
		pairs.append([Vector3(x, - hy, - hz), Vector3(x, hy, 0)])
		pairs.append([Vector3(x, - hy, hz), Vector3(x, hy, 0)])
	_beam_mesh(body, pairs, 0.1, "ibeam")
	if d.x < 9.0:

		_box(body, Vector3(2.2, 1.8, d.z + 0.2), Vector3(hx - 1.4, - hy - 0.6, 0), "concrete")
	B._merge_meshes(body)
	return body


func vehicle(p: Dictionary) -> Node3D:
	var mech: Dictionary = p.m
	var kind: String = mech.get("kind", "")
	var body: = AnimatableBody3D.new()
	body.sync_to_physics = true
	body.set_meta("moving", true)
	body.position = _v3(p.p)
	body.rotation.y = p.get("r", 0.0)
	var dims: = _v3(mech.get("dims", [2, 0.4, 2]))
	match kind:
		"train":
			_train(body, dims)
		"crane":
			_pallet(body, dims, float(mech.get("jib_y", 0.0)) - float(p.p[1]))
		"balloon":
			_basket(body, dims)
		"rocket":
			_rocket(body, dims)
	body.set_script(load("res://scripts/mech/path_mover.gd"))
	body.call("setup", mech.pts, float(mech.get("dwell", 3.0)), float(mech.get("speed", 5.0)))
	body.set("phase", float(mech.get("phase", 0.0)))
	body.set("kind", kind)
	var fx: = Node.new()
	fx.name = "FX"
	fx.set_script(load("res://scripts/mech/vehicle_fx.gd"))
	fx.set("kind", kind)
	if kind == "crane":
		fx.set("jib_rel", float(mech.get("jib_y", 0.0)) - float(p.p[1]))
	body.add_child(fx)
	return body

func _train(body: Node3D, dims: Vector3) -> void :
	var L: = dims.x
	var H: = dims.y
	var W: = dims.z

	var cs: = CollisionShape3D.new()
	var bs: = BoxShape3D.new()
	bs.size = dims
	cs.shape = bs
	body.add_child(cs)
	var hy: = H * 0.5
	_box(body, Vector3(L - 0.2, H * 0.45, W), Vector3(0, - hy + H * 0.225 + 0.25, 0), "train_red")
	_box(body, Vector3(L - 0.2, H * 0.42, W - 0.04), Vector3(0, hy - H * 0.21 - 0.12, 0), "train_cream")
	_box(body, Vector3(L, 0.14, W + 0.1), Vector3(0, hy - 0.07, 0), "train_red")
	_box(body, Vector3(L - 0.6, 0.06, W - 0.5), Vector3(0, hy + 0.02, 0), "grating")

	var nw: = 5
	for i in nw:
		var x: = - L * 0.5 + 0.8 + i * (L - 1.6) / (nw - 1)
		for sz in [-1.0, 1.0]:
			_box(body, Vector3(1.0, 0.7, 0.04), Vector3(x, hy - H * 0.21 - 0.12, sz * (W * 0.5)), "glass")

	for sx in [-1.0, 1.0]:
		_box(body, Vector3(0.04, 0.8, W - 0.6), Vector3(sx * (L * 0.5 - 0.08), hy - 0.75, 0), "glass")
		for sz in [-0.8, 0.8]:
			_cyl(body, 0.13, 0.08, Vector3(sx * (L * 0.5 - 0.06), - hy + 0.7, sz), "lamp_glow", 12).rotation.z = PI * 0.5

	for sx in [-1.0, 1.0]:
		_box(body, Vector3(2.2, 0.45, W - 0.5), Vector3(sx * (L * 0.3), - hy + 0.05, 0), "rail")
		for wx in [-0.6, 0.6]:
			for sz in [-0.72, 0.72]:
				var wh: = _cyl(body, 0.32, 0.14, Vector3(sx * L * 0.3 + wx, - hy + 0.02, sz), "rubber", 14)
				wh.rotation.x = PI * 0.5

	_beam_mesh(body, [[Vector3(-0.6, hy, 0), Vector3(0, hy + 0.7, 0)], [Vector3(0.6, hy, 0), Vector3(0, hy + 0.7, 0)]], 0.05, "rail")
	var num: = _label(body, "٧", Vector3(0, - hy + H * 0.25 + 0.25, W * 0.5 + 0.03), 90, Color(1, 0.95, 0.8))
	num.shaded = false
	var num2: = _label(body, "٧", Vector3(0, - hy + H * 0.25 + 0.25, - W * 0.5 - 0.03), 90, Color(1, 0.95, 0.8))
	num2.rotation.y = PI
	num2.shaded = false
	B._merge_meshes(body)
	var snd = Sfx.make_3d("train_loop", body, -6.0, 9.0, 70.0)
	if snd:
		snd.name = "Snd"

func _pallet(body: Node3D, dims: Vector3, jib_rel: float) -> void :
	var L: = dims.x
	var cs: = CollisionShape3D.new()
	var bs: = BoxShape3D.new()
	bs.size = dims
	cs.shape = bs
	body.add_child(cs)
	var hy: = dims.y * 0.5
	var n: = 6
	for i in n:
		_box(body, Vector3(L, 0.08, L / n - 0.06), Vector3(0, hy - 0.04, - L * 0.5 + (i + 0.5) * L / n), "wood")
	for sx in [-1.0, 0.0, 1.0]:
		_box(body, Vector3(0.16, dims.y - 0.08, L), Vector3(sx * (L * 0.5 - 0.1), -0.04, 0), "olive_trunk")

	var hook: = Vector3(0, hy + 2.6, 0)
	var pairs: = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			pairs.append([Vector3(sx * (L * 0.5 - 0.12), hy, sz * (L * 0.5 - 0.12)), hook])
	_beam_mesh(body, pairs, 0.035, "pole")
	var hk: = _box(body, Vector3(0.35, 0.5, 0.2), hook + Vector3(0, 0.2, 0), "ibeam")
	B._merge_meshes(body)

	var cable: = MeshInstance3D.new()
	cable.name = "Cable"
	var cm: = CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.035
	cm.height = 1.0
	cm.radial_segments = 6
	cable.mesh = cm
	cable.material_override = B.mat("pole")
	body.add_child(cable)
	var trolley: = MeshInstance3D.new()
	trolley.name = "Trolley"
	var tb: Mesh = Surf.box(Vector3(1.0, 0.45, 1.4))
	trolley.mesh = tb
	trolley.material_override = B.mat("rail")
	body.add_child(trolley)
	var snd = Sfx.make_3d("motor_loop", body, -10.0, 6.0, 55.0)
	if snd:
		snd.name = "Snd"

func _basket(body: Node3D, dims: Vector3) -> void :
	var L: = dims.x
	var hy: = dims.y * 0.5
	var cs: = CollisionShape3D.new()
	var bs: = BoxShape3D.new()
	bs.size = dims
	cs.shape = bs
	body.add_child(cs)
	_box(body, dims, Vector3.ZERO, "wicker")
	var wall_h: = 1.0
	var t: = 0.14

	for sz in [-1.0, 1.0]:
		_box(body, Vector3(L, wall_h, t), Vector3(0, hy + wall_h * 0.5, sz * (L * 0.5 - t * 0.5)), "wicker", true)
	var door: = 1.3
	var seg_len: = (L - door) * 0.5
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(body, Vector3(t, wall_h, seg_len), Vector3(sx * (L * 0.5 - t * 0.5), hy + wall_h * 0.5, sz * (door * 0.5 + seg_len * 0.5)), "wicker", true)

	for sz in [-1.0, 1.0]:
		_box(body, Vector3(L + 0.06, 0.1, 0.22), Vector3(0, hy + wall_h, sz * (L * 0.5 - 0.07)), "olive_trunk")

	var env: = MeshInstance3D.new()
	var sm: = SphereMesh.new()
	sm.radius = 3.4
	sm.height = 7.8
	sm.radial_segments = 40
	sm.rings = 20
	env.mesh = sm
	var m: = ShaderMaterial.new()
	m.shader = load("res://shaders/balloon.gdshader")
	m.set_shader_parameter("c1", Color(0.85, 0.16, 0.18))
	m.set_shader_parameter("c2", Color(0.98, 0.94, 0.86))
	m.set_shader_parameter("c3", Color(0.12, 0.45, 0.42))
	env.material_override = m
	env.position = Vector3(0, hy + 6.9, 0)
	body.add_child(env)
	var pairs: = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			pairs.append([Vector3(sx * (L * 0.5 - 0.1), hy + wall_h, sz * (L * 0.5 - 0.1)), Vector3(sx * 1.4, hy + 3.4, sz * 1.4)])
	_beam_mesh(body, pairs, 0.04, "olive_trunk")

	_cyl(body, 0.35, 0.4, Vector3(0, hy + 3.3, 0), "rail", 12)
	var flame: = _cyl(body, 0.26, 0.9, Vector3(0, hy + 3.9, 0), "flame", 10, 0.02)
	flame.name = "Flame"
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fl: = _light(body, Vector3(0, hy + 3.6, 0), Color(1.0, 0.6, 0.25), 0.0, 9.0)
	fl.name = "FlameLight"

	B._merge_meshes(body)

func _rocket(body: Node3D, dims: Vector3) -> void :
	var R: = dims.x * 0.5
	var hy: = dims.y * 0.5

	_cyl(body, R, dims.y, Vector3.ZERO, "metal_panel", 32, -1.0, true)
	_cyl(body, R + 0.05, 0.12, Vector3(0, hy - 0.06, 0), "rocket_red", 32)
	for sz in [-1.0, 1.0]:
		var pairs: = []
		for i in 7:
			var a: float = PI * 0.5 * sz + (i - 3) * 0.26
			var q: = Vector3(cos(a) * (R - 0.08), hy, sin(a) * (R - 0.08))
			pairs.append([q, q + Vector3(0, 1.0, 0)])
			if i < 6:
				var a2: float = a + 0.26
				var q2: = Vector3(cos(a2) * (R - 0.08), hy, sin(a2) * (R - 0.08))
				pairs.append([q + Vector3(0, 1.0, 0), q2 + Vector3(0, 1.0, 0)])
				var cs: = CollisionShape3D.new()
				var bs: = BoxShape3D.new()
				bs.size = Vector3(q.distance_to(q2) + 0.05, 1.0, 0.1)
				cs.shape = bs
				cs.position = (q + q2) * 0.5 + Vector3(0, 0.5, 0)
				cs.basis = Basis(Vector3.UP, atan2( - (q2.z - q.z), q2.x - q.x))
				body.add_child(cs)
		_beam_mesh(body, pairs, 0.06, "rocket_red")

	var bh: = 14.0
	_cyl(body, 1.5, bh, Vector3(0, - hy - bh * 0.5, 0), "rocket_white", 32, 1.7, true)
	for k in [0.25, 0.7]:
		_cyl(body, 1.53 + 0.2 * k, 0.6, Vector3(0, - hy - bh * k, 0), "rocket_red", 32)

	for i in 3:
		var a: = TAU * i / 3.0
		var w: = _cyl(body, 0.32, 0.1, Vector3(cos(a) * 1.58, - hy - 3.5, sin(a) * 1.58), "glass", 16)
		w.basis = Basis(Vector3.UP, - a) * Basis(Vector3.BACK, PI * 0.5)

	for i in 4:
		var a: = TAU * i / 4.0 + PI * 0.25
		var fin: = _box(body, Vector3(1.6, 3.2, 0.16), Vector3(cos(a) * 2.2, - hy - bh + 1.4, sin(a) * 2.2), "rocket_red")
		fin.basis = Basis(Vector3.UP, - a) * Basis(Vector3.BACK, -0.25)

	var bell: = _cyl(body, 1.0, 1.2, Vector3(0, - hy - bh - 0.6, 0), "engine_glow", 24, 0.6)
	bell.name = "Bell"
	var fl: = _light(body, Vector3(0, - hy - bh - 2.0, 0), Color(1.0, 0.55, 0.2), 0.0, 16.0)
	fl.name = "FlameLight"
	B._merge_meshes(body)
	var fire: = GPUParticles3D.new()
	fire.name = "Fire"
	fire.amount = 90
	fire.lifetime = 1.0
	fire.emitting = false
	fire.position = Vector3(0, - hy - bh - 1.2, 0)
	var pm: = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 13.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	pm.damping_min = 4.0
	pm.damping_max = 6.0
	var grad: = Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	grad.add_point(0.3, Color(1.0, 0.45, 0.15, 0.9))
	grad.set_color(grad.get_point_count() - 1, Color(0.5, 0.5, 0.55, 0.0))
	var gt: = GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	fire.process_material = pm
	var qm: = QuadMesh.new()
	qm.size = Vector2(1.2, 1.2)
	var fm: = StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.vertex_color_use_as_albedo = true
	fm.albedo_texture = _soft_dot()
	qm.material = fm
	fire.draw_pass_1 = qm
	fire.visibility_aabb = AABB(Vector3(-6, -20, -6), Vector3(12, 22, 12))
	body.add_child(fire)
	var snd = Sfx.make_3d("rocket", body, -2.0, 14.0, 120.0)
	if snd:
		snd.name = "Snd"
		snd.autoplay = false

static var _dot_tex: Texture2D
func _soft_dot() -> Texture2D:
	if _dot_tex:
		return _dot_tex
	var img: = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d: = Vector2(x - 31.5, y - 31.5).length() / 31.5
			var a: = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_dot_tex = ImageTexture.create_from_image(img)
	return _dot_tex


func room(p: Dictionary) -> Node3D:
	var d: = _v3(p.d)
	var body: = StaticBody3D.new()
	body.position = _v3(p.p)
	body.rotation.y = p.get("r", 0.0)
	_box(body, d, Vector3.ZERO, "floor_wood", true)
	var hy: = d.y * 0.5

	var rug: = _box(body, Vector3(d.x * 0.55, 0.03, d.z * 0.45), Vector3(0, hy + 0.015, 0), "carpet")
	B._decorate_carpet(rug, Vector3(d.x * 0.55, 0.03, d.z * 0.45))

	var rng: = RandomNumberGenerator.new()
	rng.seed = int(absf(float(p.p[0])) * 13.0)

	for i in 16:
		var r: = rng.randf_range(2.2, 3.8)
		var sm: = SphereMesh.new()
		sm.radius = r
		sm.height = r * 1.2
		sm.radial_segments = 14
		sm.rings = 7
		var mi: = MeshInstance3D.new()
		mi.mesh = sm
		var a: = rng.randf() * TAU
		var rr: = rng.randf_range(0.0, 0.5) * d.x
		mi.position = Vector3(cos(a) * rr, - hy - 0.25 - r * 0.62 - rng.randf_range(0.0, 1.5), sin(a) * rr)
		mi.material_override = B.cloud_mat()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mi)

	_box(body, Vector3(d.x + 0.12, 0.3, d.z + 0.12), Vector3(0, - hy + 0.15, 0), "olive_trunk")
	B._merge_meshes(body)
	return body

func wall(p: Dictionary) -> Node3D:
	var d: = _v3(p.d)
	var body: = StaticBody3D.new()
	body.position = _v3(p.p)
	body.rotation.y = p.get("r", 0.0)
	var cs: = CollisionShape3D.new()
	var bs: = BoxShape3D.new()
	bs.size = d
	cs.shape = bs
	body.add_child(cs)
	var L: = d.x
	var H: = d.y
	var T: = d.z
	var hy: = H * 0.5

	var ww: = 2.2
	var wh: = 1.5
	var wy: = 0.35
	var side: = (L - ww) * 0.5
	_box(body, Vector3(side, H, T), Vector3( - L * 0.5 + side * 0.5, 0, 0), "plaster")
	_box(body, Vector3(side, H, T), Vector3(L * 0.5 - side * 0.5, 0, 0), "plaster")
	_box(body, Vector3(ww, hy + wy - wh * 0.5, T), Vector3(0, - hy + (hy + wy - wh * 0.5) * 0.5, 0), "plaster")
	var top_h: = H - (hy + wy + wh * 0.5)
	_box(body, Vector3(ww, top_h, T), Vector3(0, hy - top_h * 0.5, 0), "plaster")

	_box(body, Vector3(ww + 0.2, 0.12, T + 0.1), Vector3(0, wy - wh * 0.5, 0), "door")
	_box(body, Vector3(ww + 0.2, 0.12, T + 0.1), Vector3(0, wy + wh * 0.5, 0), "door")
	_box(body, Vector3(0.1, wh, T + 0.1), Vector3(0, wy, 0), "door")
	for sx in [-1.0, 1.0]:
		_box(body, Vector3(0.1, wh + 0.1, T + 0.1), Vector3(sx * ww * 0.5, wy, 0), "door")

	_box(body, Vector3(L, 0.18, T + 0.08), Vector3(0, - hy + 0.09, 0), "olive_trunk")
	_box(body, Vector3(L, 0.14, T + 0.12), Vector3(0, hy - 0.07, 0), "limestone")

	for sz in [-1.0, 1.0]:
		for fx in [ - L * 0.3, L * 0.3]:
			_box(body, Vector3(0.9, 1.1, 0.06), Vector3(fx, 0.4, sz * (T * 0.5 + 0.03)), "door")
			_box(body, Vector3(0.7, 0.9, 0.07), Vector3(fx, 0.4, sz * (T * 0.5 + 0.035)), "train_cream")
	B._merge_meshes(body)
	return body


func _zone_style(z: int) -> Dictionary:
	match z:
		1:
			return {"surf": "cobble", "edge": "limestone", "rail": "wood", "lamp": "wood", "curb": "limestone"}
		2:
			return {"surf": "asphalt", "edge": "sidewalk", "rail": "pole", "lamp": "pole", "curb": "concrete"}
		3:
			return {"surf": "steel_deck", "edge": "ibeam", "rail": "ibeam", "lamp": "rail", "curb": "ibeam"}
		4:
			return {"surf": "cloud", "edge": "cloud", "rail": "plank_white", "lamp": "plank_white", "curb": "plank_white"}
		5:
			return {"surf": "stone_bridge", "edge": "limestone", "rail": "limestone", "lamp": "olive_trunk", "curb": "limestone"}
	return {"surf": "metal_panel", "edge": "metal_panel", "rail": "neon_blue", "lamp": "rail", "curb": "rail"}

func boulevard(p: Dictionary) -> Node3D:
	var d: = _v3(p.d)
	var z: = int(p.get("z", 2))
	var st: = _zone_style(z)
	var body: = StaticBody3D.new()
	body.position = _v3(p.p)
	body.basis = Basis(Vector3.UP, p.r) * Basis(Vector3.BACK, p.pitch)
	var L: = d.x
	var t: = d.y
	var W: = d.z
	var hw: = W * 0.5
	var top: = t * 0.5
	var rng: = RandomNumberGenerator.new()
	rng.seed = int(absf(float(p.p[0]) * 31.0 + float(p.p[2]) * 17.0))

	var slab: = _box(body, d, Vector3.ZERO, st.surf, true)
	if st.surf == "cloud":
		slab.material_override = B.cloud_mat()
	_box(body, Vector3(L, 0.5, W * 0.8), Vector3(0, - top - 0.25, 0), "concrete" if z != 4 else "plank_white")

	var side_w: = minf(1.3, W * 0.14)
	for sz in [-1.0, 1.0]:
		var sw: = _box(body, Vector3(L, 0.12, side_w), Vector3(0, top + 0.06, sz * (hw - side_w * 0.5)), st.edge)
		if st.edge == "cloud":
			sw.material_override = B.cloud_mat()
		var cs: = CollisionShape3D.new()
		var bs: = BoxShape3D.new()
		bs.size = Vector3(L, 0.12, side_w)
		cs.shape = bs
		cs.position = Vector3(0, top + 0.06, sz * (hw - side_w * 0.5))
		body.add_child(cs)

	for sz in [-1.0, 1.0]:
		var bz: float = sz * (hw - 0.08)
		match z:
			1, 5:

				_box(body, Vector3(L, 0.75, 0.3), Vector3(0, top + 0.12 + 0.37, bz), st.rail)
				_box(body, Vector3(L, 0.1, 0.4), Vector3(0, top + 0.12 + 0.78, bz), "concrete")
			2:

				var n: = int(L / 2.5) + 1
				for k in n:
					var x: = - L * 0.5 + 0.2 + (L - 0.4) * k / maxf(n - 1, 1)
					_box(body, Vector3(0.1, 0.8, 0.1), Vector3(x, top + 0.12 + 0.4, bz), "pole")
				_box(body, Vector3(L, 0.3, 0.06), Vector3(0, top + 0.12 + 0.62, bz - sz * 0.06), "pipe_metal")
			3:
				var n3: = int(L / 2.0) + 1
				for k in n3:
					var x3: = - L * 0.5 + 0.2 + (L - 0.4) * k / maxf(n3 - 1, 1)
					_box(body, Vector3(0.08, 1.0, 0.08), Vector3(x3, top + 0.12 + 0.5, bz), "ibeam")
				_box(body, Vector3(L, 0.08, 0.08), Vector3(0, top + 0.12 + 1.0, bz), "ibeam")
				_box(body, Vector3(L, 0.06, 0.06), Vector3(0, top + 0.12 + 0.55, bz), "ibeam")
			4:

				var prng: = RandomNumberGenerator.new()
				prng.seed = int(absf(bz) * 31.0 + L * 7.0)
				for k in int(L / 1.6):
					var x4: = - L * 0.5 + 0.8 + k * 1.6
					var r0: = rng.randf_range(0.45, 0.7)
					for q in 3:
						var puff: = MeshInstance3D.new()
						var sm: = SphereMesh.new()
						sm.radius = r0 * [1.0, 0.8, 0.62][q] * prng.randf_range(0.9, 1.15)
						sm.height = sm.radius * [1.35, 1.2, 1.1][q]
						sm.radial_segments = 16
						sm.rings = 8
						puff.mesh = sm
						puff.position = Vector3(x4 + [0.0, 0.75, -0.55][q] * prng.randf_range(0.8, 1.1), top + 0.45 + [0.0, -0.12, 0.18][q], bz + prng.randf_range(-0.12, 0.12))
						puff.material_override = B.cloud_mat()
						puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if q > 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
						body.add_child(puff)
			_:
				_box(body, Vector3(L, 0.9, 0.06), Vector3(0, top + 0.12 + 0.45, bz), "glass")
				_box(body, Vector3(L, 0.06, 0.1), Vector3(0, top + 0.12 + 0.92, bz), "neon_blue")
		var bcs: = CollisionShape3D.new()
		var bbs: = BoxShape3D.new()
		bbs.size = Vector3(L, 1.0, 0.3)
		bcs.shape = bbs
		bcs.position = Vector3(0, top + 0.12 + 0.5, bz)
		body.add_child(bcs)

	if z == 2:
		var nd: = int(L / 3.0)
		for k in nd:
			_box(body, Vector3(1.5, 0.02, 0.16), Vector3( - L * 0.5 + 1.5 + k * 3.0, top + 0.011, 0), "paint_white")
		for sz in [-1.0, 1.0]:
			_box(body, Vector3(L, 0.02, 0.12), Vector3(0, top + 0.011, sz * (hw - side_w - 0.2)), "paint_yellow")
	elif z == 6:
		for sz in [-1.0, 1.0]:
			_box(body, Vector3(L, 0.03, 0.14), Vector3(0, top + 0.015, sz * (hw - side_w - 0.3)), "neon_blue")
	elif z == 3:
		for sz in [-1.0, 1.0]:
			var hz: = _box(body, Vector3(L, 0.03, 0.35), Vector3(0, top + 0.015, sz * (hw - side_w - 0.25)), "ibeam")
			var hm: = (B.mat("ibeam") as ShaderMaterial).duplicate()
			hm.set_shader_parameter("hazard", 1.0)
			hz.material_override = hm

	var nl: = maxi(2, int(L / 8.0))
	for k in nl:
		var x: = - L * 0.5 + (k + 0.5) * L / nl
		var sz: float = 1.0 if k % 2 == 0 else -1.0
		var lz: float = sz * (hw - side_w * 0.5)
		var lamp_m: String = st.lamp
		_box(body, Vector3(0.14, 3.6, 0.14), Vector3(x, top + 1.8, lz), lamp_m)
		_box(body, Vector3(0.1, 0.1, 0.9), Vector3(x, top + 3.55, lz - sz * 0.4), lamp_m)
		var bulb: = MeshInstance3D.new()
		var bm: = SphereMesh.new()
		bm.radius = 0.2
		bm.height = 0.34
		bulb.mesh = bm
		bulb.position = Vector3(x, top + 3.4, lz - sz * 0.8)
		bulb.material_override = B.mat("lamp_glow")
		body.add_child(bulb)
		var pcs: = CollisionShape3D.new()
		var pbs: = BoxShape3D.new()
		pbs.size = Vector3(0.18, 3.6, 0.18)
		pcs.shape = pbs
		pcs.position = Vector3(x, top + 1.8, lz)
		body.add_child(pcs)
		if k == nl / 2:
			_light(body, Vector3(x, top + 3.2, lz - sz * 0.8), Color(1.0, 0.85, 0.6), 0.9, 10.0)

	var props: = []
	match z:
		1:
			props = [["planter", 1.2], ["bench", 1.0]]
		2:
			props = [["car", 1.0], ["bench", 1.0], ["cone", 1.0]]
		3:
			props = [["container", 1.0], ["drum", 1.0]]
		4:
			props = [["sofa", 1.0], ["planter", 1.0]]
		5:
			props = [["planter", 1.0], ["bench", 1.0]]
		_:
			props = [["crate", 1.0], ["bench", 1.0]]
	var np: = rng.randi_range(2, 3)
	for k in np:
		var pk: Array = props[rng.randi() % props.size()]
		var x: = - L * 0.5 + 3.0 + rng.randf() * (L - 6.0)
		var sz: float = 1.0 if rng.randf() < 0.5 else -1.0
		_side_prop(body, String(pk[0]), x, top, sz * (hw - side_w - 0.9), sz, z)
	B._merge_meshes(body)
	return body

func _side_prop(body: Node3D, kind: String, x: float, top: float, zz: float, sz: float, z: int) -> void :
	var y: = top
	match kind:
		"planter":
			_box(body, Vector3(1.6, 0.6, 0.8), Vector3(x, y + 0.3, zz), "planter", true)
			var tree: = MeshInstance3D.new()
			var sm: = SphereMesh.new()
			sm.radius = 0.6
			sm.height = 0.9
			tree.mesh = sm
			tree.position = Vector3(x, y + 1.3, zz)
			tree.material_override = B.mat("olive_leaf")
			body.add_child(tree)
			_box(body, Vector3(0.12, 0.7, 0.12), Vector3(x, y + 0.85, zz), "olive_trunk")
		"bench":
			_box(body, Vector3(1.8, 0.1, 0.5), Vector3(x, y + 0.45, zz), "wood", true)
			_box(body, Vector3(1.8, 0.45, 0.08), Vector3(x, y + 0.75, zz + sz * 0.22), "wood")
			for sx in [-0.75, 0.75]:
				_box(body, Vector3(0.08, 0.45, 0.45), Vector3(x + sx, y + 0.22, zz), "rail")
		"car":

			var cols: = ["train_red", "tank_band", "paint_white", "drum"]
			var c: String = cols[int(absf(x) * 7.0) % cols.size()]
			_box(body, Vector3(3.8, 0.8, 1.7), Vector3(x, y + 0.6, zz), c, true)
			_box(body, Vector3(2.2, 0.65, 1.55), Vector3(x - 0.2, y + 1.3, zz), c, true)
			_box(body, Vector3(2.25, 0.4, 1.58), Vector3(x - 0.2, y + 1.33, zz), "glass")
			for wx in [-1.2, 1.2]:
				for wz in [-0.8, 0.8]:
					var wh: = _cyl(body, 0.36, 0.25, Vector3(x + wx, y + 0.36, zz + wz), "rubber", 12)
					wh.rotation.x = PI * 0.5
		"cone":
			for k in 3:
				_cyl(body, 0.22, 0.7, Vector3(x + k * 0.8, y + 0.35, zz), "pipe_orange", 10, 0.04, true)
		"container":
			var cc: = ["container_red", "container_blue", "container_green", "container_orange"]
			var cm: String = cc[int(absf(x) * 3.0) % 4]
			var box: = _box(body, Vector3(5.0, 2.4, 1.6), Vector3(x, y + 1.2, zz + sz * 0.05), cm, true)
		"drum":
			for k in 2:
				_cyl(body, 0.4, 1.0, Vector3(x + k * 0.9, y + 0.5, zz), "drum", 14, -1.0, true)
		"sofa":
			_box(body, Vector3(2.2, 0.5, 0.9), Vector3(x, y + 0.25, zz), "carpet", true)
			_box(body, Vector3(2.2, 0.7, 0.25), Vector3(x, y + 0.75, zz + sz * 0.33), "carpet")
		"crate":
			_box(body, Vector3(1.4, 1.4, 1.4), Vector3(x, y + 0.7, zz), "metal_panel", true)

func plaza_dress(body: Node3D, p: Dictionary) -> void :
	var rad: float = p.rad
	var h: float = p.h
	var z: = int(p.get("z", 2))
	var st: = _zone_style(z)
	var mi: MeshInstance3D = null
	for c in body.get_children():
		if c is MeshInstance3D:
			mi = c
			break
	if mi:
		mi.material_override = B.cloud_mat() if st.surf == "cloud" else B.mat(st.surf)

	var ring: = _cyl(body, rad * 0.45, 0.02, Vector3(0, h * 0.5 + 0.011, 0), "paint_white" if z in [2, 6] else "stone_bridge", 32)
	var ring2: = _cyl(body, rad * 0.38, 0.025, Vector3(0, h * 0.5 + 0.013, 0), st.surf if st.surf != "cloud" else "plank_white", 32)

	var gaps: Array = p.get("gaps", [])
	var placed: = 0
	for i in 12:
		if placed >= 4:
			break
		var a: = TAU * i / 12.0 + 0.2
		var blocked: = false
		for g in gaps:

			if absf(wrapf(a - float(g), - PI, PI)) < 0.75:
				blocked = true
		if blocked or (placed > 0 and i % 3 != 0):
			continue
		placed += 1
		var pos: = Vector3(cos(a) * (rad - 0.5), h * 0.5, sin(a) * (rad - 0.5))
		_box(body, Vector3(0.12, 3.2, 0.12), pos + Vector3(0, 1.6, 0), st.lamp, true)
		var bulb: = MeshInstance3D.new()
		var bm: = SphereMesh.new()
		bm.radius = 0.22
		bm.height = 0.38
		bulb.mesh = bm
		bulb.position = pos + Vector3(0, 3.3, 0)
		bulb.material_override = B.mat("lamp_glow")
		body.add_child(bulb)
	_light(body, Vector3(0, h * 0.5 + 3.5, 0), Color(1.0, 0.85, 0.62), 0.7, rad * 1.8)


func moment_cyl(p: Dictionary) -> Node3D:
	var t: String = p.t
	var rad: float = p.rad
	var h: float = p.h
	var body: = StaticBody3D.new()
	body.position = _v3(p.p)
	var cs: = CollisionShape3D.new()
	var shp: = CylinderShape3D.new()
	shp.radius = rad
	shp.height = h
	cs.shape = shp
	body.add_child(cs)
	var top: = h * 0.5
	var rng: = RandomNumberGenerator.new()
	rng.seed = int(absf(float(p.p[0]) * 13.0 + float(p.p[1]) * 7.0))
	match t:
		"taboon":

			_cyl(body, rad * 1.02, h * 0.7, Vector3(0, - h * 0.15, 0), "clay", 24, rad * 1.08)
			_cyl(body, rad * 1.08, h * 0.3, Vector3(0, top - h * 0.15 - 0.06, 0), "clay", 24, rad * 0.98)
			var loaf: = _cyl(body, rad * 0.97, 0.12, Vector3(0, top + 0.0, 0), "bread", 28)
			for i in 9:
				var a: = rng.randf() * TAU
				var r: = rng.randf_range(0.1, rad * 0.8)
				_cyl(body, 0.12, 0.04, Vector3(cos(a) * r, top + 0.05, sin(a) * r), "olive_trunk", 8)
			var mouth: = _cyl(body, rad * 0.42, 0.1, Vector3(0, - h * 0.05, rad * 0.98), "flame", 14)
			mouth.rotation.x = PI * 0.5
			_light(body, Vector3(0, - h * 0.05, rad + 0.6), Color(1.0, 0.55, 0.2), 1.2, 6.0)
			_smoke(body, Vector3(rad * 0.5, top + 0.2, - rad * 0.3))

			for k in 3:
				var lg: = _cyl(body, 0.12, 1.2, Vector3( - rad - 0.25, - h * 0.4 + k * 0.22, 0.3 - k * 0.1), "olive_trunk", 8)
				lg.rotation.x = PI * 0.5
		"gas":
			var col: = "gas" if int(absf(float(p.p[2]) * 10.0)) % 3 != 0 else "gas_grey"
			_cyl(body, rad, h * 0.8, Vector3(0, - h * 0.1, 0), col, 24)
			_cyl(body, rad * 0.98, h * 0.12, Vector3(0, top - h * 0.14, 0), col, 24, rad * 0.8)
			_cyl(body, rad * 0.8, 0.06, Vector3(0, top, 0), col, 24)
			_cyl(body, rad * 1.02, 0.12, Vector3(0, - h * 0.5 + 0.06, 0), "rail", 24)
			_cyl(body, rad * 1.01, 0.14, Vector3(0, 0.0, 0), "paint_white", 24)
			var collar: = MeshInstance3D.new()
			var tm: = TorusMesh.new()
			tm.inner_radius = rad * 0.5
			tm.outer_radius = rad * 0.6
			tm.rings = 24
			collar.mesh = tm
			collar.position = Vector3(0, top + 0.1, 0)
			collar.material_override = B.mat(col)
			body.add_child(collar)
			_cyl(body, 0.1, 0.22, Vector3(0, top + 0.11, 0), "copper", 10)
			var lb: = _label(body, "غاز", Vector3(0, - h * 0.15, rad + 0.02), 150, Color(1, 1, 1))
			lb.shaded = false
		"finjan":

			_cyl(body, rad * 0.62, h, Vector3.ZERO, "porcelain", 28, rad * 1.02)
			_cyl(body, rad * 0.96, 0.05, Vector3(0, top - 0.02, 0), "coffee", 28)
			var rim: = MeshInstance3D.new()
			var tm2: = TorusMesh.new()
			tm2.inner_radius = rad * 0.97
			tm2.outer_radius = rad * 1.05
			tm2.rings = 32
			rim.mesh = tm2
			rim.position = Vector3(0, top + 0.01, 0)
			rim.material_override = B.mat("gold")
			body.add_child(rim)
			_cyl(body, rad * 0.86, 0.12, Vector3(0, - top * 0.2, 0), "tank_band", 28, rad * 0.9)
			_steam(body, Vector3(0, top + 0.2, 0))
		"bead":

			_cyl(body, rad * 0.72, h * 0.3, Vector3(0, - h * 0.35, 0), "bead", 20, rad * 0.98)
			_cyl(body, rad * 1.0, h * 0.4, Vector3.ZERO, "bead", 20)
			_cyl(body, rad * 0.98, h * 0.3, Vector3(0, h * 0.35, 0), "bead", 20, rad * 0.86)
			_cyl(body, rad * 0.2, 0.04, Vector3(0, top + 0.005, 0), "iron", 12)
	B._merge_meshes(body)
	return body

func _smoke(body: Node3D, pos: Vector3) -> void :
	var ps: = GPUParticles3D.new()
	ps.amount = 16
	ps.lifetime = 4.0
	ps.position = pos
	var pm: = ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 15.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0.2, 0.15, 0)
	pm.scale_min = 1.0
	pm.scale_max = 2.4
	var g: = Gradient.new()
	g.set_color(0, Color(0.9, 0.9, 0.9, 0.0))
	g.add_point(0.2, Color(0.85, 0.85, 0.85, 0.45))
	g.set_color(g.get_point_count() - 1, Color(0.8, 0.8, 0.8, 0.0))
	var gt: = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	ps.process_material = pm
	var qm: = QuadMesh.new()
	qm.size = Vector2(0.9, 0.9)
	var sm: = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.vertex_color_use_as_albedo = true
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_texture = _soft_dot()
	qm.material = sm
	ps.draw_pass_1 = qm
	ps.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 16, 8))
	body.add_child(ps)

func _steam(body: Node3D, pos: Vector3) -> void :
	_smoke(body, pos)
	var ps: GPUParticles3D = body.get_child(body.get_child_count() - 1)
	ps.amount = 8
	(ps.process_material as ParticleProcessMaterial).initial_velocity_max = 0.6
	(ps.draw_pass_1 as QuadMesh).size = Vector2(0.6, 0.6)

func bead_cords(pieces: Array, nodes: Array) -> void :

	var groups: = {}
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		if p.t == "bead" and p.has("grp") and nodes[i] != null:
			var g: = int(p.grp)
			if not groups.has(g):
				groups[g] = []
			groups[g].append(nodes[i])
	for g in groups.keys():
		var arr: Array = groups[g]
		if arr.size() < 2:
			continue
		var host: Node3D = arr[0]
		var pairs: = []
		for k in range(arr.size() - 1):
			var a: Vector3 = (arr[k] as Node3D).position
			var b: Vector3 = (arr[k + 1] as Node3D).position
			pairs.append([a - host.position, b - host.position])
		var mi: = _beam_mesh(host, pairs, 0.09, "carpet")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var last: Node3D = arr[arr.size() - 1]
		var lp: Vector3 = last.position - host.position
		var tassel: = []
		for k in 7:
			var ang: = TAU * k / 7.0
			tassel.append([lp + Vector3(0, -0.6, 0), lp + Vector3(cos(ang) * 0.35, -3.4, sin(ang) * 0.35)])
		_beam_mesh(host, tassel, 0.07, "carpet")

		var s: = MeshInstance3D.new()
		var sm: = SphereMesh.new()
		sm.radius = 0.55
		sm.height = 1.0
		s.mesh = sm
		s.position = lp + Vector3(0, -0.9, 0)
		s.material_override = B.mat("gold")
		host.add_child(s)

func bus(p: Dictionary) -> Node3D:
	var d: = _v3(p.d)
	var body: = StaticBody3D.new()
	body.position = _v3(p.p)
	body.basis = Basis(Vector3.UP, p.r) * Basis(Vector3.BACK, p.pitch)
	var L: = d.x
	var H: = d.y
	var W: = d.z
	var top: = H * 0.5
	var cs: = CollisionShape3D.new()
	var bs: = BoxShape3D.new()
	bs.size = d
	cs.shape = bs
	body.add_child(cs)

	_box(body, Vector3(L, H * 0.85, W), Vector3(0, - H * 0.075, 0), "bus")
	_box(body, Vector3(L - 0.1, 0.18, W - 0.2), Vector3(0, top - 0.09, 0), "chassis")

	for sz in [-1.0, 1.0]:
		_box(body, Vector3(L - 1.8, H * 0.28, 0.04), Vector3(0.2, - H * 0.22, sz * W * 0.5), "glass")
		_box(body, Vector3(L, 0.08, 0.05), Vector3(0, H * 0.05, sz * W * 0.5), "chassis")
		_box(body, Vector3(L, 0.08, 0.05), Vector3(0, H * 0.18, sz * W * 0.5), "chassis")

	_box(body, Vector3(0.05, 0.5, W - 0.5), Vector3(L * 0.5, H * 0.15, 0), "chassis")
	for sz in [-0.8, 0.8]:
		var hl: = _cyl(body, 0.16, 0.06, Vector3(L * 0.5 + 0.02, H * 0.25, sz), "lamp_glow", 12)
		hl.rotation.z = PI * 0.5

	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var wp: = Vector3(sx * (L * 0.5 - 1.6), top + 0.25, sz * (W * 0.5 - 0.25))
			var wh: = _cyl(body, 0.55, 0.35, wp, "rubber", 16)
			wh.rotation.x = PI * 0.5
			var wcs: = CollisionShape3D.new()
			var wsh: = CylinderShape3D.new()
			wsh.radius = 0.55
			wsh.height = 0.35
			wcs.shape = wsh
			wcs.position = wp
			wcs.rotation.x = PI * 0.5
			body.add_child(wcs)
		_box(body, Vector3(0.14, 0.14, W - 0.4), Vector3(sx * (L * 0.5 - 1.6), top + 0.12, 0), "rail")

	for sz in [-1.0, 1.0]:
		var lb: = _label(body, "باص المدرسة", Vector3(0, H * 0.02, sz * (W * 0.5 + 0.03)), 110, Color(0.1, 0.1, 0.1))
		lb.rotation = Vector3(0, 0 if sz > 0 else PI, PI)
	B._merge_meshes(body)
	return body

func key(p: Dictionary) -> Node3D:
	var d: = _v3(p.d)
	var body: = StaticBody3D.new()
	body.position = _v3(p.p)
	body.basis = Basis(Vector3.UP, p.r) * Basis(Vector3.BACK, p.pitch)
	var L: = d.x
	var t: = d.y
	var W: = d.z
	var top: = t * 0.5
	_box(body, d, Vector3.ZERO, "iron", true)

	for k in 4:
		var x: = - L * 0.5 + 1.2 + k * (L - 2.4) / 3.0
		_box(body, Vector3(0.25, t + 0.06, W + 0.12), Vector3(x, -0.03, 0), "iron")

	var bow: = MeshInstance3D.new()
	var tm: = TorusMesh.new()
	tm.inner_radius = 1.0
	tm.outer_radius = 1.7
	tm.rings = 36
	tm.ring_segments = 10
	bow.mesh = tm
	bow.position = Vector3( - L * 0.5 - 1.25, -0.1, 0)
	bow.scale = Vector3(1, 0.6, 1)
	bow.material_override = B.mat("iron")
	body.add_child(bow)

	_box(body, Vector3(1.6, t, 1.9), Vector3(L * 0.5 - 0.8, 0, W * 0.5 + 0.95), "iron")
	_box(body, Vector3(0.45, t, 0.7), Vector3(L * 0.5 - 1.2, 0, W * 0.5 + 2.2), "iron")
	_box(body, Vector3(0.45, t, 0.5), Vector3(L * 0.5 - 0.35, 0, W * 0.5 + 2.1), "iron")
	var bcs: = CollisionShape3D.new()
	var bbs: = BoxShape3D.new()
	bbs.size = Vector3(1.6, t, 1.9)
	bcs.shape = bbs
	bcs.position = Vector3(L * 0.5 - 0.8, 0, W * 0.5 + 0.95)
	body.add_child(bcs)

	_box(body, Vector3(0.1, 1.6, 0.3), Vector3( - L * 0.5 - 0.3, -0.9, 0.3), "carpet")
	B._merge_meshes(body)
	return body

func dallah(p: Dictionary) -> Node3D:

	var root: = Node3D.new()
	root.position = _v3(p.p)
	root.rotation.y = float(p.get("r", 0.0))
	var H: float = p.h
	var bulb: = MeshInstance3D.new()
	var sm: = SphereMesh.new()
	sm.radius = H * 0.3
	sm.height = H * 0.42
	sm.radial_segments = 32
	sm.rings = 16
	bulb.mesh = sm
	bulb.position = Vector3(0, H * 0.21, 0)
	bulb.material_override = B.mat("copper")
	root.add_child(bulb)
	_cyl(root, H * 0.24, H * 0.06, Vector3(0, H * 0.02, 0), "copper", 32, H * 0.28)
	_cyl(root, H * 0.13, H * 0.16, Vector3(0, H * 0.46, 0), "gold", 32, H * 0.1)
	_cyl(root, H * 0.1, H * 0.16, Vector3(0, H * 0.62, 0), "copper", 32, H * 0.2)
	var lid: = MeshInstance3D.new()
	var lm: = SphereMesh.new()
	lm.radius = H * 0.2
	lm.height = H * 0.2
	lm.is_hemisphere = true
	lm.radial_segments = 32
	lid.mesh = lm
	lid.position = Vector3(0, H * 0.7, 0)
	lid.material_override = B.mat("gold")
	root.add_child(lid)
	_cyl(root, H * 0.02, H * 0.1, Vector3(0, H * 0.84, 0), "gold", 10)
	var fin: = MeshInstance3D.new()
	var fm: = SphereMesh.new()
	fm.radius = H * 0.035
	fm.height = H * 0.07
	fin.mesh = fm
	fin.position = Vector3(0, H * 0.9, 0)
	fin.material_override = B.mat("gold")
	root.add_child(fin)

	var pairs: = []
	var a: = Vector3(H * 0.1, H * 0.52, 0)
	var b: = Vector3(H * 0.28, H * 0.66, 0)
	var c: = Vector3(H * 0.42, H * 0.78, 0)
	_beam_mesh(root, [[a, b]], H * 0.07, "copper")
	_beam_mesh(root, [[b, c]], H * 0.045, "copper")

	var hpairs: = [[Vector3( - H * 0.12, H * 0.66, 0), Vector3( - H * 0.3, H * 0.6, 0)], [Vector3( - H * 0.3, H * 0.6, 0), Vector3( - H * 0.28, H * 0.35, 0)], 
		[Vector3( - H * 0.28, H * 0.35, 0), Vector3( - H * 0.2, H * 0.3, 0)]]
	_beam_mesh(root, hpairs, H * 0.035, "gold")
	_smoke(root, c + Vector3(H * 0.03, H * 0.02, 0))
	for gi in root.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).visibility_range_end = 1100.0
	return root
