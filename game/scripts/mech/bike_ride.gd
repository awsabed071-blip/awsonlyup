extends Node3D






var path: Array = []
var center: = Vector3.ZERO
var to: = Vector3.ZERO
var height: = 20.0
var radius: = 1.9
var builder: Node = null

const ROAD_W: = 3.0
const CURB: = 0.25
const RAIL_H: = 1.0
const PARK_S: = 1.6
const MIN_V: = 2.4
const CRUISE_V: = 5.6
const FAST_V: = 8.6

var state: = "park"
var _t: = 0.0
var _s: = PARK_S
var _v: = 0.0
var _crank: = 0.0
var _wheel_a: = 0.0
var _pts: = PackedVector3Array()
var _cum: = PackedFloat32Array()
var _L: = 0.0
var _player: CharacterBody3D = null
var _bike: Node3D
var _wheels: Array[Node3D] = []
var _crank_n: Node3D
var _pedals: Array[Node3D] = []
var _basket: Node3D
var _radio: Node3D
var _crate: Node3D
var _crate_top: = Vector3.ZERO
var _song: AudioStreamPlayer3D
var _idle: AudioStreamPlayer3D
var _roll: AudioStreamPlayer3D
var _groove_t: = 0.0
var _hand_t: = 0.0
var _hand: = 0.0
var _off_from: = Vector3.ZERO
var _off_to: = Vector3.ZERO
var _yaw: = 0.0
var _mount_from: = Vector3.ZERO
var _pick_from: = Vector3.ZERO
var _pick_to: = Vector3.ZERO
var _radio_on: = false
var rides: = 0

static var _mats: = {}

func _mat(key: String, c: Color, rough: = 0.6, metal: = 0.0, emit: = Color.BLACK, e: = 0.0) -> StandardMaterial3D:
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

func _bmat(n: String) -> Material:
	if builder and builder.has_method("mat"):
		return builder.mat(n)
	return _mat("fb_" + n, Color(0.8, 0.75, 0.65))

func _ready() -> void :
	add_to_group("live_radio")
	for p in path:
		_pts.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	_resample(0.5)
	_build_road()
	_build_minaret()
	_build_lights()
	_bike = Node3D.new()
	_bike.name = "BikeModel"
	_bike.top_level = true
	add_child(_bike)
	_build_bike()
	_crate = Node3D.new()
	_crate.top_level = true
	add_child(_crate)
	_build_crate()
	_roll = Sfx.make_3d("bike_roll", _bike, -60.0, 4.0, 25.0)
	_bike.global_transform = _bike_xf(PARK_S)

	_init_radio.call_deferred()

func _init_radio() -> void :
	_radio = _make_radio()
	_idle = Sfx.make_3d("radio_loop", _radio, -12.0, 3.0, 22.0)
	_song = Sfx.make_3d("song_ride", _radio, -1.0, 7.0, 52.0)
	if _song:
		_song.autoplay = false
		_song.stream = _song.stream.duplicate()
		(_song.stream as AudioStreamOggVorbis).loop = false
		_song.stop()
	_reset_to_start()


func _resample(step: float) -> void :

	var src: = _pts
	var acc: = PackedFloat32Array([0.0])
	for i in range(1, src.size()):
		acc.append(acc[i - 1] + src[i].distance_to(src[i - 1]))
	var total: = acc[acc.size() - 1]
	var out: = PackedVector3Array()
	var cum: = PackedFloat32Array()
	var j: = 0
	var s: = 0.0
	while s <= total + 0.001:
		while j < src.size() - 2 and acc[j + 1] < s:
			j += 1
		var seg: = maxf(acc[j + 1] - acc[j], 0.0001)
		out.append(src[j].lerp(src[j + 1], clampf((s - acc[j]) / seg, 0.0, 1.0)))
		cum.append(s)
		s += step
	if out[out.size() - 1].distance_to(src[src.size() - 1]) > 0.05:
		out.append(src[src.size() - 1])
		cum.append(total)
	_pts = out
	_cum = cum
	_L = total

func point_at(s: float) -> Vector3:
	s = clampf(s, 0.0, _L)
	var i: = clampi(int(s / 0.5), 0, _pts.size() - 2)
	while i < _pts.size() - 2 and _cum[i + 1] < s:
		i += 1
	var seg: = maxf(_cum[i + 1] - _cum[i], 0.0001)
	return _pts[i].lerp(_pts[i + 1], clampf((s - _cum[i]) / seg, 0.0, 1.0))

func tangent_at(s: float) -> Vector3:
	var a: = point_at(s - 1.2)
	var b: = point_at(s + 1.2)
	var d: = b - a
	return d.normalized() if d.length() > 0.001 else Vector3.FORWARD

func length() -> float:
	return _L


func _side(t: Vector3) -> Vector3:
	var h: = Vector3(t.x, 0, t.z)
	return Vector3.UP.cross(h.normalized()).normalized() if h.length() > 0.001 else Vector3.RIGHT

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void :

	if (b - a).cross(c - a).dot(n) > 0.0:
		var tmp: = b
		b = c
		c = tmp
	for v in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void :
	_tri(st, a, b, c, n)
	_tri(st, a, c, d, n)

func _build_road() -> void :
	var root: = Node3D.new()
	root.name = "Road"
	root.top_level = true
	add_child(root)
	root.global_transform = Transform3D.IDENTITY
	var top: = SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: = SurfaceTool.new()
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rails: = SurfaceTool.new()
	rails.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: = PackedVector3Array()
	var hw: = ROAD_W * 0.5

	var prof: = [
		[Vector2( - hw, 0.0), Vector2(hw, 0.0), Vector2(0, 1), 0], 
		[Vector2(hw, 0.0), Vector2(hw, 0.14), Vector2(-1, 0), 1], 
		[Vector2(hw, 0.14), Vector2(hw + CURB, 0.14), Vector2(0, 1), 1], 
		[Vector2(hw + CURB, 0.14), Vector2(hw + CURB, -0.5), Vector2(1, 0), 1], 
		[Vector2(hw + CURB, -0.5), Vector2( - hw - CURB, -0.5), Vector2(0, -1), 1], 
		[Vector2( - hw - CURB, -0.5), Vector2( - hw - CURB, 0.14), Vector2(-1, 0), 1], 
		[Vector2( - hw - CURB, 0.14), Vector2( - hw, 0.14), Vector2(0, 1), 1], 
		[Vector2( - hw, 0.14), Vector2( - hw, 0.0), Vector2(1, 0), 1], 
	]
	var n: = _pts.size()
	var frames: = []
	for i in n:
		var t: = tangent_at(_cum[i])
		frames.append([_pts[i], _side(t)])

	var i0: = 0
	while i0 < n - 1 and _cum[i0] < 2.2:
		i0 += 1
	for i in range(i0, n - 1):
		var p0: Vector3 = frames[i][0]
		var s0: Vector3 = frames[i][1]
		var p1: Vector3 = frames[i + 1][0]
		var s1: Vector3 = frames[i + 1][1]
		for seg in prof:
			var a: Vector2 = seg[0]
			var b: Vector2 = seg[1]
			var nn: Vector2 = seg[2]
			var A0: = p0 + s0 * a.x + Vector3.UP * a.y
			var B0: = p0 + s0 * b.x + Vector3.UP * b.y
			var A1: = p1 + s1 * a.x + Vector3.UP * a.y
			var B1: = p1 + s1 * b.x + Vector3.UP * b.y
			var nrm: = ((s0 + s1) * 0.5 * nn.x + Vector3.UP * nn.y).normalized()
			_quad(top if int(seg[3]) == 0 else sides, A0, B0, B1, A1, nrm)
			faces.append_array(PackedVector3Array([A0, B0, B1, A0, B1, A1]))

		for sd: float in [-1.0, 1.0]:
			var o: float = sd * (hw + CURB * 0.5)
			for rh: float in [RAIL_H, 0.58]:
				var sz: float = 0.045 if rh > 0.8 else 0.03
				var c0: Vector3 = p0 + s0 * o + Vector3.UP * rh
				var c1: Vector3 = p1 + s1 * o + Vector3.UP * rh
				_quad(rails, c0 + Vector3.UP * sz - s0 * sz, c0 + Vector3.UP * sz + s0 * sz, c1 + Vector3.UP * sz + s1 * sz, c1 + Vector3.UP * sz - s1 * sz, Vector3.UP)
				_quad(rails, c0 - Vector3.UP * sz - s0 * sz, c0 - Vector3.UP * sz + s0 * sz, c1 - Vector3.UP * sz + s1 * sz, c1 - Vector3.UP * sz - s1 * sz, Vector3.DOWN)
				_quad(rails, c0 + s0 * sz + Vector3.UP * sz, c0 + s0 * sz - Vector3.UP * sz, c1 + s1 * sz - Vector3.UP * sz, c1 + s1 * sz + Vector3.UP * sz, s0)
				_quad(rails, c0 - s0 * sz + Vector3.UP * sz, c0 - s0 * sz - Vector3.UP * sz, c1 - s1 * sz - Vector3.UP * sz, c1 - s1 * sz + Vector3.UP * sz, - s0)
			var w0: Vector3 = p0 + s0 * o
			var w1: Vector3 = p1 + s1 * o
			var wq: = PackedVector3Array([w0 + Vector3.UP * 0.1, w1 + Vector3.UP * 0.1, w1 + Vector3.UP * (RAIL_H + 0.1), w0 + Vector3.UP * (RAIL_H + 0.1)])
			faces.append_array(PackedVector3Array([wq[0], wq[1], wq[2], wq[0], wq[2], wq[3]]))
			faces.append_array(PackedVector3Array([wq[0], wq[2], wq[1], wq[0], wq[3], wq[2]]))

	var posts: = MultiMesh.new()
	posts.transform_format = MultiMesh.TRANSFORM_3D
	var pm: = BoxMesh.new()
	pm.size = Vector3(0.07, RAIL_H, 0.07)
	posts.mesh = pm
	var xs: = []
	var s: = 2.4
	while s < _L - 0.5:
		var p: = point_at(s)
		var sd2: = _side(tangent_at(s))
		for sd in [-1.0, 1.0]:
			var xf: = Transform3D(Basis.looking_at(sd2), p + sd2 * sd * (hw + CURB * 0.5) + Vector3.UP * (RAIL_H * 0.5 + 0.07))
			xs.append(xf)
		s += 2.5
	posts.instance_count = xs.size()
	for k in xs.size():
		posts.set_instance_transform(k, xs[k])
	var am: = ArrayMesh.new()
	top.commit(am)
	am.surface_set_material(0, _bmat("cobble"))
	sides.commit(am)
	am.surface_set_material(1, _bmat("stone_bridge"))
	rails.commit(am)
	am.surface_set_material(2, _bmat("iron"))
	var mi: = MeshInstance3D.new()
	mi.mesh = am
	root.add_child(mi)
	var pmi: = MultiMeshInstance3D.new()
	pmi.multimesh = posts
	pmi.material_override = _bmat("iron")
	root.add_child(pmi)
	_vis(mi, 620.0)
	_vis(pmi, 260.0)
	var body: = StaticBody3D.new()
	root.add_child(body)
	var cs: = CollisionShape3D.new()
	var sh: = ConcavePolygonShape3D.new()
	sh.set_faces(faces)
	sh.backface_collision = true
	cs.shape = sh
	body.add_child(cs)

	var piers: = Node3D.new()
	root.add_child(piers)
	s = 6.0
	while s < _L - 4.0:
		var p: = point_at(s)
		var dc: = Vector2(p.x - center.x, p.z - center.z).length()
		if dc > 12.5:
			var h: = 26.0
			if builder:
				builder._mesh_cyl(piers, 0.55, h, p + Vector3(0, -0.5 - h * 0.5, 0), "stone_bridge", 10, 0.42)
		s += 11.0
	if builder:
		builder._merge_meshes(piers)
	for gi in piers.get_children():
		if gi is GeometryInstance3D:
			_vis(gi, 420.0)

func _vis(gi: GeometryInstance3D, far: float) -> void :
	if Game.mobile:
		gi.visibility_range_end = far
		gi.visibility_range_end_margin = 40.0


func _build_minaret() -> void :
	if builder == null:
		return
	var root: = Node3D.new()
	root.name = "Minaret"
	root.top_level = true
	add_child(root)
	root.global_transform = Transform3D(Basis.IDENTITY, Vector3(center.x, 0, center.z))
	var lo: = INF
	var hi: = - INF
	for p in _pts:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var base: = lo - 70.0
	var r: = 3.4
	var shaft_h: = hi + 6.0 - base
	builder._mesh_cyl(root, r, shaft_h, Vector3(0, base + shaft_h * 0.5, 0), "limestone", 16, r * 0.92)

	var y: = base + 20.0
	while y < hi + 5.0:
		builder._mesh_cyl(root, r * 0.97 + 0.12, 0.35, Vector3(0, y, 0), "stone_bridge", 16)
		y += 7.0
	var wm: = _mat("minaret_win", Color(1.0, 0.8, 0.45), 0.5, 0.0, Color(1.0, 0.72, 0.35), 2.2)
	for k in 14:
		var a: = k * 1.37
		var wy: = lo - 4.0 + k * (hi - lo + 10.0) / 14.0
		var w: = MeshInstance3D.new()
		var bm: = BoxMesh.new()
		bm.size = Vector3(0.5, 0.9, 0.2)
		w.mesh = bm
		w.material_override = wm
		w.position = Vector3(cos(a) * r * 0.93, wy, sin(a) * r * 0.93)
		w.rotation.y = - a + PI * 0.5
		root.add_child(w)

	var by: = hi + 6.0
	builder._mesh_cyl(root, r + 1.1, 0.5, Vector3(0, by, 0), "stone_bridge", 20)
	for k in 16:
		var a2: = TAU * k / 16.0
		builder._mesh_box(root, Vector3(0.14, 1.0, 0.14), Vector3(cos(a2) * (r + 0.9), by + 0.75, sin(a2) * (r + 0.9)), "limestone")
	builder._mesh_cyl(root, r + 1.1, 0.18, Vector3(0, by + 1.3, 0), "stone_bridge", 20)
	var ring: = MeshInstance3D.new()
	var tm: = TorusMesh.new()
	tm.inner_radius = r + 0.95
	tm.outer_radius = r + 1.05
	tm.rings = 32
	ring.mesh = tm
	ring.position = Vector3(0, by + 1.45, 0)
	ring.material_override = _mat("minaret_ring", Color(0.5, 1.0, 0.6), 0.4, 0.0, Color(0.4, 1.0, 0.55), 2.6)
	root.add_child(ring)
	builder._mesh_cyl(root, r * 0.72, 9.0, Vector3(0, by + 5.5, 0), "limestone", 14)
	var dome: = MeshInstance3D.new()
	var sm: = SphereMesh.new()
	sm.radius = r * 0.8
	sm.height = r * 1.9
	dome.mesh = sm
	dome.position = Vector3(0, by + 10.3, 0)
	dome.material_override = builder.mat("dome")
	root.add_child(dome)
	builder._mesh_cyl(root, 0.1, 2.4, Vector3(0, by + 13.6, 0), "gold", 6)
	var cres: = MeshInstance3D.new()
	cres.mesh = builder.crescent_mesh(1.1, 0.28, 0.2)
	cres.material_override = builder.mat("gold")
	cres.position = Vector3(0, by + 15.4, 0)
	cres.rotation_degrees = Vector3(0, 0, 90)
	root.add_child(cres)

	var s: = 3.0
	while s < _L - 2.0:
		var p: = point_at(s)
		var d: = Vector2(p.x - center.x, p.z - center.z)
		if d.length() < 12.5 and d.length() > r + 1.0:
			var dir: = Vector3(d.x, 0, d.y).normalized()
			var inner: = p - dir * (ROAD_W * 0.5 + CURB)
			var a0: = Vector3(center.x, p.y - 0.8, center.z) + dir * (r - 0.2)
			var mid: = (a0 + inner + Vector3(0, -0.45, 0)) * 0.5
			var ln: = a0.distance_to(inner)
			var beam: = MeshInstance3D.new()
			var bm2: = BoxMesh.new()
			bm2.size = Vector3(0.35, 0.45, ln)
			beam.mesh = bm2
			beam.material_override = builder.mat("stone_bridge")
			root.add_child(beam)
			beam.global_transform = Transform3D(Basis.looking_at((inner - a0).normalized()), mid)
		s += 4.0
	builder._merge_meshes(root)
	for gi in root.find_children("*", "GeometryInstance3D", true, false):
		_vis(gi, 1000.0)

	var body: = StaticBody3D.new()
	root.add_child(body)
	var cs: = CollisionShape3D.new()
	var cyl: = CylinderShape3D.new()
	cyl.radius = r
	cyl.height = shaft_h + 16.0
	cs.shape = cyl
	cs.position = Vector3(0, base + (shaft_h + 16.0) * 0.5, 0)
	body.add_child(cs)


func _build_lights() -> void :
	var root: = Node3D.new()
	root.name = "Lights"
	root.top_level = true
	add_child(root)
	root.global_transform = Transform3D.IDENTITY
	var hw: = ROAD_W * 0.5 + CURB * 0.5
	var lamp_tops: Array[Vector3] = []
	var s: = 7.0
	var k: = 0
	var post_m: = _bmat("iron")
	var glass: = [
		_mat("fanous_a", Color(1.0, 0.75, 0.35), 0.4, 0.0, Color(1.0, 0.65, 0.25), 3.0), 
		_mat("fanous_b", Color(0.5, 1.0, 0.6), 0.4, 0.0, Color(0.35, 1.0, 0.5), 2.6), 
		_mat("fanous_c", Color(1.0, 0.45, 0.5), 0.4, 0.0, Color(1.0, 0.35, 0.45), 2.6), 
	]
	var n_lights: = 0
	while s < _L - 3.0:
		var p: = point_at(s)
		var t: = tangent_at(s)
		var sd: = _side(t)

		var out: = 1.0
		if Vector2(p.x - center.x, p.z - center.z).dot(Vector2(sd.x, sd.z)) < 0.0:
			out = -1.0
		var base: = p + sd * out * hw
		var post: = MeshInstance3D.new()
		var cm: = CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.08
		cm.height = 2.9
		cm.radial_segments = 6
		post.mesh = cm
		post.material_override = post_m
		post.position = base + Vector3(0, 1.45 + 0.14, 0)
		root.add_child(post)
		var arm: = MeshInstance3D.new()
		var ab: = BoxMesh.new()
		ab.size = Vector3(0.05, 0.05, 0.7)
		arm.mesh = ab
		arm.material_override = post_m
		root.add_child(arm)
		arm.global_transform = Transform3D(Basis.looking_at( - sd * out), base + Vector3(0, 2.95, 0) - sd * out * 0.3)

		var lp: = base + Vector3(0, 2.55, 0) - sd * out * 0.6
		var fan: = MeshInstance3D.new()
		var fm: = CylinderMesh.new()
		fm.top_radius = 0.16
		fm.bottom_radius = 0.12
		fm.height = 0.42
		fm.radial_segments = 6
		fan.mesh = fm
		fan.material_override = glass[k % 3]
		fan.position = lp
		root.add_child(fan)
		var cap: = MeshInstance3D.new()
		var cp: = CylinderMesh.new()
		cp.top_radius = 0.0
		cp.bottom_radius = 0.2
		cp.height = 0.22
		cp.radial_segments = 6
		cap.mesh = cp
		cap.material_override = _bmat("copper")
		cap.position = lp + Vector3(0, 0.32, 0)
		root.add_child(cap)
		lamp_tops.append(base + Vector3(0, 2.95, 0))

		if not Game.mobile and k % 2 == 0 and n_lights < 7:
			var ol: = OmniLight3D.new()
			ol.light_color = (glass[k % 3] as StandardMaterial3D).emission
			ol.light_energy = 1.4
			ol.omni_range = 7.0
			ol.shadow_enabled = false
			ol.position = lp
			ol.distance_fade_enabled = true
			ol.distance_fade_begin = 60.0
			ol.distance_fade_length = 20.0
			root.add_child(ol)
			n_lights += 1
		k += 1
		s += 13.0

	var mm: = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sp: = SphereMesh.new()
	sp.radius = 0.07
	sp.height = 0.14
	sp.radial_segments = 6
	sp.rings = 3
	mm.mesh = sp
	var bulbs: = []
	var cols: = [Color(2.2, 1.5, 0.5), Color(0.6, 2.0, 0.8), Color(2.2, 0.6, 0.6), Color(0.7, 1.2, 2.4), Color(2.2, 2.0, 1.4)]
	for i in range(lamp_tops.size() - 1):
		var a: = lamp_tops[i]
		var b: = lamp_tops[i + 1]
		var cnt: = int(a.distance_to(b) / 0.8)
		for j in range(1, cnt):
			var u: = float(j) / cnt
			var q: = a.lerp(b, u) + Vector3(0, -1.1 * 4.0 * u * (1.0 - u), 0)
			bulbs.append([q, cols[(i * 7 + j) % cols.size()]])
	mm.instance_count = bulbs.size()
	for i in bulbs.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, bulbs[i][0]))
		mm.set_instance_color(i, bulbs[i][1])
	var bm: = StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.vertex_color_use_as_albedo = true
	var bmi: = MultiMeshInstance3D.new()
	bmi.multimesh = mm
	bmi.material_override = bm
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bmi)
	_vis(bmi, 300.0)
	if builder:
		builder._merge_meshes(root)
	for gi in root.find_children("*", "GeometryInstance3D", true, false):
		if gi != bmi:
			_vis(gi, 300.0)


func _part(parent: Node3D, m: Mesh, pos: Vector3, mat: Material, rot: = Vector3.ZERO) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _tube(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
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
	var side: = up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) * 0.5)
	return mi


const WHEEL_R: = 0.27
const REAR_Z: = -0.56
const FRONT_Z: = 0.5
const SEAT: = Vector3(0, 0.545, -0.33)
const CRANK: = Vector3(0, 0.34, -0.1)
const BAR: = Vector3(0, 0.84, 0.2)
const RIDER: = Vector3(0, 0.25, -0.09)

func _build_bike() -> void :
	var frame: = _mat("bike_frame", Color(0.08, 0.36, 0.34), 0.35, 0.3)
	var chrome: = _mat("bike_chrome", Color(0.82, 0.83, 0.86), 0.2, 0.9)
	var tyre: = _mat("bike_tyre", Color(0.07, 0.07, 0.08), 0.9)
	var leather: = _mat("bike_leather", Color(0.36, 0.2, 0.1), 0.6)
	var wick: = _bmat("wicker")
	for z in [REAR_Z, FRONT_Z]:
		var w: = Node3D.new()
		w.position = Vector3(0, WHEEL_R, z)
		_bike.add_child(w)
		var tm: = TorusMesh.new()
		tm.inner_radius = WHEEL_R - 0.045
		tm.outer_radius = WHEEL_R
		tm.rings = 24
		tm.ring_segments = 6
		_part(w, tm, Vector3.ZERO, tyre, Vector3(0, 0, PI * 0.5))
		var rim: = TorusMesh.new()
		rim.inner_radius = WHEEL_R - 0.07
		rim.outer_radius = WHEEL_R - 0.045
		rim.rings = 24
		rim.ring_segments = 4
		_part(w, rim, Vector3.ZERO, chrome, Vector3(0, 0, PI * 0.5))
		for k in 6:
			var a: = TAU * k / 6.0
			_tube(w, Vector3.ZERO, Vector3(0, cos(a), sin(a)) * (WHEEL_R - 0.06), 0.006, chrome)
		_part(w, _cyl(0.03, 0.06), Vector3.ZERO, chrome, Vector3(0, 0, PI * 0.5))
		_wheels.append(w)
	var rear: = Vector3(0, WHEEL_R, REAR_Z)
	var front: = Vector3(0, WHEEL_R, FRONT_Z)
	var head_lo: = Vector3(0, 0.5, 0.36)
	var head_hi: = Vector3(0, 0.68, 0.32)
	var seat_post: = SEAT + Vector3(0, -0.06, 0)
	_tube(_bike, CRANK, seat_post, 0.026, frame)
	_tube(_bike, CRANK, head_lo, 0.028, frame)
	_tube(_bike, head_lo, head_hi, 0.03, frame)
	_tube(_bike, CRANK, rear, 0.018, frame)
	_tube(_bike, seat_post + Vector3(0, -0.05, 0), rear, 0.016, frame)
	_tube(_bike, head_lo, front, 0.018, chrome)
	_tube(_bike, head_hi, BAR + Vector3(0, -0.02, -0.04), 0.018, chrome)

	for sx in [-1.0, 1.0]:
		var g: = BAR + Vector3(sx * 0.25, 0.04, -0.28)
		_tube(_bike, BAR + Vector3(0, 0, -0.02), g, 0.016, chrome)
		_part(_bike, _cyl(0.024, 0.1), g + Vector3(sx * 0.04, 0, 0), leather, Vector3(0, 0, PI * 0.5))

	for z in [REAR_Z, FRONT_Z]:
		var gd: = MeshInstance3D.new()
		var tm2: = TorusMesh.new()
		tm2.inner_radius = WHEEL_R + 0.02
		tm2.outer_radius = WHEEL_R + 0.05
		tm2.rings = 16
		tm2.ring_segments = 4
		gd.mesh = tm2
		gd.material_override = frame
		gd.position = Vector3(0, WHEEL_R, z)
		gd.rotation = Vector3(0, 0, PI * 0.5)
		gd.scale = Vector3(1.0, 1.0, 0.45)
		_bike.add_child(gd)

	var sb: = BoxMesh.new()
	sb.size = Vector3(0.22, 0.07, 0.26)
	_part(_bike, sb, SEAT, leather)

	_crank_n = Node3D.new()
	_crank_n.position = CRANK
	_bike.add_child(_crank_n)
	_part(_crank_n, _cyl(0.09, 0.02), Vector3(0.06, 0, 0), chrome, Vector3(0, 0, PI * 0.5))
	for sd in [-1.0, 1.0]:
		var arm: = Node3D.new()
		arm.position = Vector3(sd * 0.09, 0, 0)
		arm.rotation.x = 0.0 if sd > 0.0 else PI
		_crank_n.add_child(arm)
		var ab: = BoxMesh.new()
		ab.size = Vector3(0.02, 0.03, 0.15)
		_part(arm, ab, Vector3(0, 0, 0.075), chrome)
		var ped: = Node3D.new()
		ped.position = Vector3(sd * 0.05, 0, 0.15)
		arm.add_child(ped)
		var pb: = BoxMesh.new()
		pb.size = Vector3(0.1, 0.02, 0.06)
		_part(ped, pb, Vector3.ZERO, tyre)
		_pedals.append(ped)

	_basket = Node3D.new()
	_basket.position = Vector3(0, 0.64, 0.56)
	_bike.add_child(_basket)
	var bb: = BoxMesh.new()
	bb.size = Vector3(0.4, 0.04, 0.3)
	_part(_basket, bb, Vector3.ZERO, wick)
	for sx in [-1.0, 1.0]:
		var sw: = BoxMesh.new()
		sw.size = Vector3(0.03, 0.2, 0.3)
		_part(_basket, sw, Vector3(sx * 0.2, 0.1, 0), wick)
	for sz in [-1.0, 1.0]:
		var fw: = BoxMesh.new()
		fw.size = Vector3(0.4, 0.2, 0.03)
		_part(_basket, fw, Vector3(0, 0.1, sz * 0.15), wick)
	_part(_bike, _cyl(0.035, 0.03), BAR + Vector3(0.15, 0.06, -0.17), chrome)
	var lamp: = _cyl(0.05, 0.08)
	_part(_bike, lamp, Vector3(0, 0.56, 0.44), _mat("bike_lamp", Color(1, 0.95, 0.8), 0.3, 0.0, Color(1.0, 0.9, 0.6), 2.0), Vector3(PI * 0.5, 0, 0))
	for mi in _bike.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	if builder:
		builder._merge_meshes(_bike)

func _cyl(r: float, h: float) -> CylinderMesh:
	var cm: = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	return cm

func _build_crate() -> void :
	var wood: = _bmat("wood")
	var bm: = BoxMesh.new()
	bm.size = Vector3(0.55, 0.42, 0.45)
	_part(_crate, bm, Vector3(0, 0.21, 0), wood)
	_crate_top = Vector3(0, 0.42, 0)

func _make_radio() -> Node3D:
	var story: Node = Game.main.story if Game.main and "story" in Game.main else null
	var r: Node3D
	if story and story.has_method("make_radio"):
		r = story.make_radio(self)
	else:
		r = Node3D.new()
		add_child(r)
		var bm: = BoxMesh.new()
		bm.size = Vector3(0.62, 0.4, 0.26)
		_part(r, bm, Vector3(0, 0.2, 0), _mat("radio_fb", Color(0.42, 0.24, 0.13)))
	r.top_level = true
	r.scale = Vector3.ONE * 0.62
	return r


func _bike_xf(s: float) -> Transform3D:
	var p: = point_at(s)
	var t: = tangent_at(s)
	var h: = Vector3(t.x, 0, t.z).normalized()
	var pitch: = atan2(t.y, Vector2(t.x, t.z).length())
	var b: = Basis.looking_at( - h)
	b = b * Basis(Vector3.RIGHT, - pitch)
	return Transform3D(b, p)

func _reset_to_start() -> void :
	state = "park"
	_t = 0.0
	_s = PARK_S
	_v = 0.0
	var xf: = _bike_xf(_s)

	_bike.global_transform = xf * Transform3D(Basis(Vector3.FORWARD, 0.12), Vector3.ZERO)
	var sd: = _side(tangent_at(_s))
	var cp: = point_at(_s) + sd * 0.95 + (point_at(_s + 0.5) - point_at(_s)).normalized() * 0.15
	_crate.global_position = cp
	_crate.rotation.y = xf.basis.get_euler().y + 0.25
	_put_radio_on_crate()
	_radio_on = false
	if _song:
		_song.stop()
	if _idle:
		_idle.play()
	if _roll:
		_roll.volume_db = -60.0

func _put_radio_on_crate() -> void :
	if _radio.get_parent() != self:
		_radio.get_parent().remove_child(_radio)
		add_child(_radio)
	_radio.top_level = true
	_radio.scale = Vector3.ONE * 0.62
	_radio.global_transform = Transform3D(Basis(Vector3.UP, _crate.rotation.y + PI).scaled(Vector3.ONE * 0.62), _crate.global_position + _crate_top)

func _attach_radio(to_node: Node3D, local: Transform3D) -> void :
	_radio.get_parent().remove_child(_radio)
	to_node.add_child(_radio)
	_radio.top_level = false
	_radio.transform = local

func is_on() -> bool:
	return _radio_on and _song != null and _song.playing

func radio_position() -> Vector3:
	return _radio.global_position


func carry_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, _yaw), _body_pos)

var _body_pos: = Vector3.ZERO

func _physics_process(delta: float) -> void :
	if _radio == null:
		return
	_t += delta
	match state:
		"park":
			var pl: = _find_player()
			if pl and pl.state == pl.State.NORMAL and pl.is_on_floor():
				var bp: = _bike.global_position
				var rel: = pl.global_position - bp
				if Vector2(rel.x, rel.z).length() < 1.9 and absf(rel.y) < 1.2:
					_begin(pl)
		"pickup":
			_do_pickup(delta)
		"ride":
			_do_ride(delta)
		"off":
			_do_off(delta)
		"top":
			var pl2: = _find_player()
			if pl2 and (pl2.global_position.y < to.y - 8.0 or pl2.global_position.distance_to(_bike.global_position) > 160.0):
				if pl2.global_position.distance_to(_crate.global_position) > 14.0:
					_reset_to_start()
	if _roll:
		var want: = -60.0 if absf(_v) < 0.2 else lerpf(-18.0, -8.0, clampf(absf(_v) / FAST_V, 0.0, 1.0))
		_roll.volume_db = move_toward(_roll.volume_db, want, delta * 40.0)
		_roll.pitch_scale = 0.8 + clampf(absf(_v) / FAST_V, 0.0, 1.0) * 0.5

func _find_player() -> CharacterBody3D:
	if _player and is_instance_valid(_player):
		return _player
	if Game.main and Game.main.player:
		return Game.main.player
	for n in get_tree().get_nodes_in_group("player"):
		return n
	var root: = get_tree().current_scene
	if root:
		var pl: = root.find_child("Player", true, false)
		if pl is CharacterBody3D:
			return pl
	return null

func _begin(pl: CharacterBody3D) -> void :
	if not pl.start_carry(self, "free"):
		return
	_player = pl
	state = "pickup"
	_t = 0.0
	_body_pos = pl.global_position
	_pick_from = pl.global_position
	var to_c: = _crate.global_position - pl.global_position
	to_c.y = 0.0

	_pick_to = _crate.global_position - to_c.normalized() * 0.62
	_pick_to.y = point_at(_s).y
	_yaw = atan2(to_c.x, to_c.z)
	pl.play_anim("Walking_A", 0.15, 1.2)

func _do_pickup(delta: float) -> void :
	var pl: = _player
	if pl == null or not is_instance_valid(pl):
		_reset_to_start()
		return
	var t: = _t
	var bike_xf: = _bike_xf(_s)
	var seat: = bike_xf * RIDER
	if t < 0.45:
		_body_pos = _pick_from.lerp(_pick_to, smoothstep(0.0, 0.45, t))
	elif t < 1.55:
		if pl._cur_anim != "PickUp":
			pl.play_anim("PickUp", 0.12, 1.25)

		if t > 0.95 and _radio.get_parent() == self:
			_attach_radio(pl.hand_anchor(), Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * 0.62 / 0.8), Vector3(0.0, 0.02, 0.0)))
		if t > 1.15 and not _radio_on:
			_radio_on = true
			Sfx.play("radio_click", -2.0)
			if _idle:
				_idle.stop()
			if _song:
				_song.play(0.0)
			_groove_t = 0.0
	elif t < 2.15:

		if pl._cur_anim != "Walking_A":
			pl.play_anim("Walking_A", 0.15, 1.1)
		var k: = smoothstep(1.55, 2.15, t)
		var side_spot: = bike_xf * Vector3(-0.55, 0.0, SEAT.z + 0.1)
		_body_pos = _pick_to.lerp(side_spot, k)
		var dir: = side_spot - _pick_to
		if dir.length() > 0.05:
			_yaw = lerp_angle(_yaw, atan2(dir.x, dir.z), 1.0 - exp(-10.0 * delta))
		if t > 1.95 and _radio.get_parent() != _basket:
			_attach_radio(_basket, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.62), Vector3(0, 0.03, -0.02)))
			Sfx.play("grab", -10.0, 0.1)
	elif t < 2.6:

		var k2: = smoothstep(2.15, 2.6, t)
		var side_spot2: = bike_xf * Vector3(-0.55, 0.0, SEAT.z + 0.1)
		_body_pos = side_spot2.lerp(seat, k2) + Vector3(0, sin(k2 * PI) * 0.25, 0)
		var fwd: = bike_xf.basis.z
		_yaw = lerp_angle(_yaw, atan2(fwd.x, fwd.z), 1.0 - exp(-14.0 * delta))
		if pl._cur_anim != "Sit_Chair_Idle":
			pl.play_anim("Sit_Chair_Idle", 0.25, 1.0)
			pl.carry_pose = "ride"

		_bike.global_transform = bike_xf * Transform3D(Basis(Vector3.FORWARD, 0.12 * (1.0 - k2)), Vector3.ZERO)
	else:
		state = "ride"
		_t = 0.0
		_v = 1.0
		rides += 1
		Sfx.play("bike_bell", -8.0)
		if Game.main and Game.main.rig:
			Game.main.rig.ride_follow = true

func _input_fwd() -> float:
	var pl: = _player
	if pl and pl.bot_enabled:
		return 0.6
	if Game.input_blocked:
		return 0.0
	var f: = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	if Input.is_action_pressed("sprint"):
		f = maxf(f, 0.0) + 0.5
	return clampf(f, -1.0, 1.5)

func _do_ride(delta: float) -> void :
	var pl: = _player
	if pl == null or not is_instance_valid(pl) or pl.state != pl.State.CARRY:
		state = "top"
		return
	var f: = _input_fwd()
	var t: = tangent_at(_s)
	var slope: = t.y / maxf(Vector2(t.x, t.z).length(), 0.1)
	var want: = CRUISE_V + (FAST_V - CRUISE_V) * clampf(f, 0.0, 1.5) / 1.5 * 1.0
	if f < 0.0:
		want = lerpf(CRUISE_V, MIN_V, - f)
	want -= slope * 9.0
	want = clampf(want, MIN_V, FAST_V + 1.0)

	var left: = _L - _s
	if left < 9.0:
		want = minf(want, lerpf(1.2, CRUISE_V, left / 9.0))
	_v = move_toward(_v, want, (2.2 if want > _v else 4.0) * delta)
	_s += _v * delta
	var xf: = _bike_xf(_s)

	var t2: = tangent_at(_s + 2.0)
	var turn: = wrapf(atan2(t2.x, t2.z) - atan2(t.x, t.z), - PI, PI)
	var lean: = clampf( - turn * 0.9 * clampf(_v / CRUISE_V, 0.0, 1.4), -0.22, 0.22)
	_bike.global_transform = xf * Transform3D(Basis(Vector3.FORWARD, lean), Vector3.ZERO)
	_body_pos = _bike.global_transform * RIDER
	var fwd: = xf.basis.z
	_yaw = atan2(fwd.x, fwd.z)

	_wheel_a += _v / WHEEL_R * delta
	for w in _wheels:
		w.rotation.x = _wheel_a
	_crank += _v / WHEEL_R * delta * 0.55
	_crank_n.rotation.x = _crank
	for p in _pedals:
		p.global_rotation = Vector3(0, _bike.global_rotation.y, 0)

	_groove_t += delta
	_hand_t += delta
	var groove: = clampf((_groove_t - 1.5) / 3.0, 0.0, 1.0)

	var cyc: = fmod(_hand_t, 11.0)
	var want_hand: = 1.0 if (cyc > 6.5 and cyc < 9.8 and absf(turn) < 0.25) else 0.0
	_hand = move_toward(_hand, want_hand, delta * 1.6)
	pl.ride_crank = _crank
	pl.ride_groove = groove
	pl.ride_hand = _hand
	pl.ride_pitch = atan(slope)
	pl.ride_lean = lean
	pl.ride_time = _groove_t

	var bell: bool = pl.bot_jump_pressed if pl.bot_enabled else (Input.is_action_just_pressed("jump") and not Game.input_blocked)
	if bell:
		Sfx.play("bike_bell", -4.0, 0.05)
	if _s >= _L - 1.7 or (_v < 1.3 and left < 2.5):
		state = "off"
		_t = 0.0
		_off_from = _body_pos
		_off_to = to + Vector3(0, 0.05, 0)
		pl.carry_pose = "free"
		pl.play_anim("Idle", 0.25)
		if Game.main and Game.main.rig:
			Game.main.rig.ride_follow = false

func _do_off(delta: float) -> void :
	var pl: = _player
	_v = move_toward(_v, 0.0, 6.0 * delta)
	var k: = smoothstep(0.0, 0.5, _t)
	_body_pos = _off_from.lerp(_off_to, k) + Vector3(0, sin(k * PI) * 0.3, 0)
	if _t >= 0.5:
		state = "top"
		_t = 0.0
		_v = 0.0
		if pl and is_instance_valid(pl):
			pl.end_carry(Vector3.ZERO)
		_player = null

		_bike.global_transform = _bike_xf(_s) * Transform3D(Basis(Vector3.FORWARD, 0.12), Vector3.ZERO)
