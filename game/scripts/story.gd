extends Node3D




const ACTOR: = preload("res://scripts/actor.gd")
const LANTERN: = preload("res://scripts/lantern.gd")

var main
var level
var cs
var house: Dictionary
var radio_points: Array[Vector3] = []
var roof_xf: = Transform3D.IDENTITY
var set_root: Node3D
var grandma
var child
var hero
var stool: Node3D
var roof_lantern: Node3D
var sky_moon: Node3D
var memories: = {}
var _mats: = {}


func setup(main_ref) -> void :
	main = main_ref
	level = main.level
	cs = load("res://scripts/cutscene.gd").new()
	cs.name = "Cutscene"
	add_child(cs)
	for p in level.route.pieces:
		if p.get("tag", "") == "grandma":
			house = p
			break
	if not house.is_empty():
		var c: Vector3 = level._v3(house.p)
		var d: Vector3 = level._v3(house.d)
		roof_xf = Transform3D(Basis(Vector3.UP, float(house.get("r", 0.0))), Vector3(c.x, c.y + d.y * 0.5, c.z))
		_build_rooftop()
	_build_memories()

func R(v: Vector3) -> Vector3:
	return roof_xf * v

func RY(local_yaw: float) -> float:
	return roof_xf.basis.get_euler().y + local_yaw


func _m(key: String, col: Color, rough: = 0.8, metal: = 0.0, em: = Color.BLACK, ems: = 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m: = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if ems > 0.0:
		m.emission_enabled = true
		m.emission = em
		m.emission_energy_multiplier = ems
	_mats[key] = m
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot: = Vector3.ZERO) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	var bm: = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation = rot
	mi.material_override = m
	parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, m: Material, segs: = 16, rt: = -1.0) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	var cm: = CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = r if rt < 0.0 else rt
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.position = pos
	mi.material_override = m
	parent.add_child(mi)
	return mi

func _prop(parent: Node3D, key: String, pos: Vector3, yaw: = 0.0, s: = 0.8) -> Node3D:
	# every prop is built procedurally inside the measured footprint of the old kit piece
	var n: Node3D = level.PR.build(key, 4, int(absf(pos.x * 31.0 + pos.z * 7.0)) + key.hash() % 97)
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * s
	parent.add_child(n)
	return n

func _solid(parent: Node3D, size: Vector3, pos: Vector3, yaw: = 0.0) -> void :
	var sb: = StaticBody3D.new()
	sb.position = pos
	sb.rotation.y = yaw
	var cs2: = CollisionShape3D.new()
	var bs: = BoxShape3D.new()
	bs.size = size
	cs2.shape = bs
	sb.add_child(cs2)
	parent.add_child(sb)


func make_stool(parent: Node3D) -> Node3D:
	var n: = Node3D.new()
	parent.add_child(n)
	var wood: = _m("stool_wood", Color(0.5, 0.33, 0.2))
	var straw: = _m("straw", Color(0.83, 0.68, 0.38), 0.95)
	_box(n, Vector3(0.46, 0.06, 0.46), Vector3(0, 0.42, 0), straw)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(n, Vector3(0.05, 0.42, 0.05), Vector3(sx * 0.19, 0.21, sz * 0.19), wood)
	_box(n, Vector3(0.42, 0.03, 0.03), Vector3(0, 0.14, 0.19), wood)
	_box(n, Vector3(0.42, 0.03, 0.03), Vector3(0, 0.14, -0.19), wood)
	return n

func make_cushion(parent: Node3D, col: Color) -> Node3D:
	var n: = Node3D.new()
	parent.add_child(n)
	var m: = _m("cushion_%s" % col.to_html(), col, 0.95)
	var c: = _box(n, Vector3(0.62, 0.12, 0.62), Vector3(0, 0.06, 0), m)
	var tr: = _m("cushion_trim", Color(0.85, 0.2, 0.2), 0.9)
	_box(n, Vector3(0.64, 0.03, 0.08), Vector3(0, 0.1, 0.24), tr)
	_box(n, Vector3(0.64, 0.03, 0.08), Vector3(0, 0.1, -0.24), tr)
	return n

func make_tea_tray(parent: Node3D) -> Node3D:
	var n: = Node3D.new()
	parent.add_child(n)
	var wood: = _m("tray_wood", Color(0.45, 0.28, 0.16))
	var brass: = _m("brass", Color(0.86, 0.64, 0.28), 0.3, 0.85)
	_cyl(n, 0.32, 0.26, Vector3(0, 0.13, 0), wood, 16)
	_cyl(n, 0.3, 0.025, Vector3(0, 0.27, 0), brass, 24)
	var glass: = _m("tea", Color(0.62, 0.2, 0.08, 0.85), 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 3:
		var a: = TAU * i / 3.0 + 0.4
		_cyl(n, 0.035, 0.09, Vector3(cos(a) * 0.14, 0.33, sin(a) * 0.14), glass, 10, 0.045)

	_cyl(n, 0.07, 0.1, Vector3(-0.04, 0.34, -0.02), brass, 12, 0.05)
	_cyl(n, 0.012, 0.09, Vector3(0.05, 0.36, -0.02), brass, 6).rotation.z = -0.9
	return n

func make_radio(parent: Node3D) -> Node3D:
	var n: = Node3D.new()
	parent.add_child(n)
	var wood: = _m("radio_wood", Color(0.42, 0.24, 0.13), 0.55)
	var cloth: = _m("radio_cloth", Color(0.82, 0.74, 0.58), 0.95)
	var brass: = _m("brass", Color(0.86, 0.64, 0.28), 0.3, 0.85)
	var dial: = _m("radio_dial", Color(1.0, 0.9, 0.6), 0.4, 0.0, Color(1.0, 0.75, 0.35), 1.5)
	_box(n, Vector3(0.62, 0.4, 0.26), Vector3(0, 0.2, 0), wood)
	_box(n, Vector3(0.3, 0.26, 0.02), Vector3(-0.12, 0.22, 0.131), cloth)
	_box(n, Vector3(0.18, 0.06, 0.02), Vector3(0.17, 0.3, 0.131), dial)
	for k in 2:
		_cyl(n, 0.03, 0.03, Vector3(0.12 + k * 0.1, 0.13, 0.14), brass, 10).rotation.x = PI * 0.5
	_cyl(n, 0.006, 0.55, Vector3(0.24, 0.62, -0.08), brass, 4).rotation.z = -0.35
	return n

func make_embroidery(parent: Node3D) -> Node3D:

	var n: = Node3D.new()
	parent.add_child(n)
	var wood: = _m("hoop_wood", Color(0.6, 0.42, 0.25))
	var cloth: = _m("hoop_cloth", Color(0.95, 0.92, 0.84), 0.95)
	var red: = _m("thread_red", Color(0.78, 0.08, 0.12), 0.8)
	var green: = _m("thread_green", Color(0.1, 0.45, 0.25), 0.8)
	var blk: = _m("thread_black", Color(0.08, 0.08, 0.09), 0.8)
	_box(n, Vector3(0.06, 0.9, 0.06), Vector3(0, 0.45, 0), wood)
	_box(n, Vector3(0.5, 0.05, 0.3), Vector3(0, 0.02, 0), wood)
	var hoop: = MeshInstance3D.new()
	var tm: = TorusMesh.new()
	tm.inner_radius = 0.3
	tm.outer_radius = 0.34
	tm.rings = 24
	tm.ring_segments = 6
	hoop.mesh = tm
	hoop.rotation.x = PI * 0.5
	hoop.position = Vector3(0, 1.05, 0)
	hoop.material_override = wood
	n.add_child(hoop)
	var disc: = _cyl(n, 0.3, 0.01, Vector3(0, 1.05, 0), cloth, 24)
	disc.rotation.x = PI * 0.5

	for i in range(-3, 4):
		for j in range(-3, 4):
			if absi(i) + absi(j) == 3 or (i == 0 and j == 0):
				var st: = _box(n, Vector3(0.035, 0.035, 0.012), Vector3(i * 0.05, 1.05 + j * 0.05, 0.012), red)
			elif absi(i) + absi(j) == 1:
				_box(n, Vector3(0.035, 0.035, 0.012), Vector3(i * 0.05, 1.05 + j * 0.05, 0.012), green)

	for k in 3:
		var sp: = _cyl(n, 0.05, 0.09, Vector3(-0.15 + k * 0.15, 0.09, 0.05), [red, green, blk][k], 12)
	return n

func make_threads(parent: Node3D, a: Vector3, b: Vector3) -> void :

	var cols: = [Color(0.78, 0.08, 0.12), Color(0.1, 0.45, 0.25), Color(0.08, 0.08, 0.09)]
	for k in 3:
		var m: = _m("thread_%d" % k, cols[k], 0.8, 0.0, cols[k], 0.15)
		var st: = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n: = 20
		var prev: = a
		for i in range(1, n + 1):
			var t: = float(i) / n
			var p: = a.lerp(b, t) + Vector3(0, - sin(t * PI) * (1.2 + k * 0.4), 0) + Vector3(0, k * 0.25, 0)
			level._st_beam(st, prev, p, 0.03)
			prev = p
		st.generate_normals()
		var mi: = MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = m
		parent.add_child(mi)

func make_watering_can(parent: Node3D) -> Node3D:
	var n: = Node3D.new()
	parent.add_child(n)
	var tin: = _m("tin", Color(0.55, 0.62, 0.6), 0.4, 0.7)
	_cyl(n, 0.13, 0.24, Vector3(0, 0.12, 0), tin, 14)
	var sp: = _cyl(n, 0.02, 0.3, Vector3(0.18, 0.22, 0), tin, 8, 0.03)
	sp.rotation.z = -0.9
	var h: = MeshInstance3D.new()
	var tm: = TorusMesh.new()
	tm.inner_radius = 0.07
	tm.outer_radius = 0.09
	h.mesh = tm
	h.rotation.x = PI * 0.5
	h.position = Vector3(-0.02, 0.28, 0)
	h.material_override = tin
	n.add_child(h)
	return n

func make_planter(parent: Node3D, pos: Vector3, s: = 1.0) -> void :
	var tin: = _m("planter_tin", Color(0.62, 0.64, 0.6), 0.5, 0.6)
	var leaf: = _m("basil", Color(0.25, 0.55, 0.22), 0.9)
	_cyl(parent, 0.16 * s, 0.3 * s, pos + Vector3(0, 0.15 * s, 0), tin, 12)
	var sph: = MeshInstance3D.new()
	var sm: = SphereMesh.new()
	sm.radius = 0.22 * s
	sm.height = 0.34 * s
	sm.radial_segments = 10
	sm.rings = 5
	sph.mesh = sm
	sph.position = pos + Vector3(0, 0.38 * s, 0)
	sph.material_override = leaf
	parent.add_child(sph)

func make_sky_moon() -> Node3D:
	var n: = Node3D.new()
	var mi: = MeshInstance3D.new()
	mi.mesh = level.crescent_mesh(58.0, 6.0, 4.0)
	var m: = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.93, 0.72)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.86, 0.55)
	m.emission_energy_multiplier = 2.2
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation_degrees = Vector3(0, 0, -30)
	n.add_child(mi)
	return n


func _build_rooftop() -> void :
	set_root = Node3D.new()
	set_root.name = "Rooftop"
	add_child(set_root)
	set_root.transform = roof_xf

	var rug: = _prop(set_root, "furniture/rug_rectangle_stripes_A.gltf", Vector3(-0.4, 0.01, -0.2), 0.0, 1.1)
	stool = make_stool(set_root)
	stool.position = Vector3(-1.1, 0, -0.7)
	var cush: = make_cushion(set_root, Color(0.2, 0.36, 0.55))
	cush.position = Vector3(0.25, 0, -0.45)
	var tray: = make_tea_tray(set_root)
	tray.position = Vector3(-0.45, 0, 0.35)

	var rad: = make_radio(set_root)
	rad.position = Vector3(1.35, 0.0, -0.95)
	rad.rotation.y = -0.6
	Sfx.make_3d("song_radio", rad, -4.0, 4.0, 48.0)
	radio_points.append(roof_xf * Vector3(1.35, 0.3, -0.95))
	for p in [Vector3(3.9, 0, 3.4), Vector3(3.3, 0, 3.5), Vector3(-3.9, 0, 3.4), Vector3(3.9, 0, -3.3), Vector3(-2.2, 0, 3.5)]:
		make_planter(set_root, p, randf_range(0.9, 1.3))

	var pole: = _m("pole_dark", Color(0.25, 0.24, 0.23), 0.6, 0.4)
	for sx in [-1.0, 1.0]:
		_cyl(set_root, 0.04, 1.9, Vector3(sx * 3.6, 0.95, -3.3), pole, 8)
	_box(set_root, Vector3(7.2, 0.012, 0.012), Vector3(0, 1.85, -3.3), pole)
	var cloth_cols: = [Color(0.9, 0.9, 0.86), Color(0.72, 0.16, 0.18), Color(0.25, 0.45, 0.7), Color(0.95, 0.85, 0.5)]
	for i in 5:
		var cm: = _m("laundry_%d" % i, cloth_cols[i % 4], 0.95)
		var w: = randf_range(0.5, 0.9)
		_box(set_root, Vector3(w, randf_range(0.5, 0.8), 0.02), Vector3(-2.8 + i * 1.3, 1.5, -3.3), cm)

	var tank: = _m("tank_black", Color(0.08, 0.08, 0.09), 0.5)
	_cyl(set_root, 0.6, 1.3, Vector3(3.1, 0.9, -2.2), tank, 18)
	_box(set_root, Vector3(1.2, 0.25, 1.2), Vector3(3.1, 0.12, -2.2), pole)
	_solid(set_root, Vector3(1.3, 1.6, 1.3), Vector3(3.1, 0.8, -2.2))

	roof_lantern = LANTERN.new()
	roof_lantern.set("glow_range", 6.0)
	roof_lantern.set("glow_energy", 1.8)
	set_root.add_child(roof_lantern)
	roof_lantern.position = Vector3(-0.45, 0.285, 0.35)
	roof_lantern.scale = Vector3.ONE * 1.15
	roof_lantern.visible = false

	sky_moon = make_sky_moon()
	add_child(sky_moon)
	sky_moon.visible = false

func _place_sky_moon() -> void :

	var fwd: Vector3 = (roof_xf.basis * Vector3(0, 0, 1)).normalized()
	var space: = get_world_3d().direct_space_state
	var from: Vector3 = roof_xf.origin + Vector3(0, 1.2, 0)
	var best: = fwd
	var best_score: = -1000000000.0
	for i in 25:
		var az: = (i - 12) * deg_to_rad(8.0)
		var dh: = Basis(Vector3.UP, az) * fwd
		var ok: = true
		for el in [34.0, 38.0, 42.0]:
			var d: = (dh * cos(deg_to_rad(el)) + Vector3.UP * sin(deg_to_rad(el))).normalized()
			var q: = PhysicsRayQueryParameters3D.create(from, from + d * 700.0)
			if not space.intersect_ray(q).is_empty():
				ok = false
				break
		var score: = - absf(az) + (100.0 if ok else 0.0)
		if score > best_score:
			best_score = score
			best = dh
	var el_r: = deg_to_rad(38.0)
	var dirm: = (best * cos(el_r) + Vector3.UP * sin(el_r)).normalized()
	sky_moon.global_position = roof_xf.origin + dirm * 620.0
	sky_moon.look_at(roof_xf.origin, Vector3.UP)

func sit_on(a: Node3D, seat: Vector3, yaw: float, seat_h: float, clip: = "Sit_Chair") -> void :
	# place the actor so the hips of its sitting pose rest on the seat, whatever its height
	a.play(clip, 0.0)
	if a.anim:
		a.anim.advance(0.0)
	var hips_y: = 0.5
	if a.skel:
		var hb: int = a.skel.find_bone("Hips")
		if hb >= 0:
			hips_y = a.skel.get_bone_global_pose(hb).origin.y * a.model.scale.y * a.scale.y
	var fwd: = Vector3(sin(yaw), 0, cos(yaw))
	a.position = seat - fwd * 0.04 + Vector3(0, seat_h + 0.07 - hips_y, 0)
	a.rotation.y = yaw

func lie_on(a: Node3D, pos: Vector3, yaw: float, surface_h: float) -> void :
	a.play("Lie", 0.0)
	if a.anim:
		a.anim.advance(0.0)
	var hips_y: = 0.2
	if a.skel:
		var hb: int = a.skel.find_bone("Hips")
		if hb >= 0:
			hips_y = a.skel.get_bone_global_pose(hb).origin.y * a.model.scale.y * a.scale.y
	a.position = pos + Vector3(0, surface_h + 0.1 - hips_y, 0)
	a.rotation.y = yaw

func _spawn_actors() -> void :
	grandma = ACTOR.new()
	grandma.name = "Grandma"
	set_root.add_child(grandma)
	grandma.setup("grandma")
	sit_on(grandma, Vector3(-1.1, 0.0, -0.7), 0.35, 0.47)
	child = ACTOR.new()
	child.name = "Child"
	set_root.add_child(child)
	child.setup("child")
	sit_on(child, Vector3(0.25, 0.0, -0.45), -0.15, 0.12, "Sit_Floor")
	hero = ACTOR.new()
	hero.name = "Hero"
	set_root.add_child(hero)
	hero.setup("salim")
	hero.position = Vector3(1.6, 0.0, 1.9)
	hero.visible = false

func _free_actors() -> void :
	for a in [grandma, child, hero]:
		if is_instance_valid(a):
			a.queue_free()
	grandma = null
	child = null
	hero = null


func play_prologue(on_done: Callable) -> void :
	if house.is_empty():
		on_done.call()
		return
	_spawn_actors()
	roof_lantern.visible = true
	roof_lantern.position = Vector3(-0.45, 0.285, 0.35)
	roof_lantern.set_lit(true, 0.0)
	_place_sky_moon()
	sky_moon.visible = true
	main.envm.set_override(main.envm.LOOK_NIGHT, 1.0)
	main.player.visible = false
	Sfx.play_music("music_story", 2.5)
	Sfx.loop_on("night_loop", -4.0, 2.0)
	var moon: Vector3 = sky_moon.global_position
	var shots: = []

	shots.append({"dur": 10.0, "fade_in": 2.5, 
		"from": [R(Vector3(-2.8, 3.2, -7.5)), moon], 
		"to": [R(Vector3(-2.2, 2.6, -5.2)), R(Vector3(-0.4, 0.6, -0.2))], "fov": [58.0, 50.0], 
		"lines": [[1.8, "", "أول ليلة برمضان، كل سنة، كانت ستّي تطلع عالسطح قبل المغرب بساعة. تقول: الهلال ما بيستنّى حدا.", 6.4]]})

	shots.append({"dur": 8.0, 
		"from": [R(Vector3(2.9, 1.5, 2.9)), R(Vector3(-0.6, 0.7, -0.5))], 
		"to": [R(Vector3(2.2, 1.25, 2.1)), R(Vector3(-0.6, 0.7, -0.5))], "fov": 42.0, 
		"lines": [[0.7, "grandma", "هيّو! شايفه يا سليم؟ فوق المادنة… رفيع، زي قصاصة ضفر."]]})

	shots.append({"dur": 11.0, 
		"from": [R(Vector3(0.6, 0.78, 1.0)), R(Vector3(0.22, 0.62, -0.5))], 
		"to": [R(Vector3(0.48, 0.74, 0.82)), R(Vector3(0.22, 0.64, -0.5))], "fov": 38.0, 
		"ev": [[0.1, func(): child.face_yaw(-0.1)]], 
		"lines": [[0.5, "child", "ستّي… ليش كل سنة بتضوّي الفانوس وبتحطّيه هون؟ ما حدا بيشوفه."], 
			[4.6, "grandma", "سيدك كان يشوفه. من شبّاك المستشفى. كنت أضوّيه عشان يعرف إني هون، وإني مش خايفة."]]})

	shots.append({"dur": 11.5, 
		"from": [R(Vector3(0.45, 1.5, 0.85)), R(Vector3(-1.1, 1.28, -0.7))], 
		"to": [R(Vector3(0.25, 1.42, 0.65)), R(Vector3(-1.1, 1.3, -0.7))], "fov": 36.0, 
		"lines": [[0.6, "grandma", "ولما أروح أنا… بتضوّيه إنت. مش لحدا. لحالك… عشان تتذكّر إنه في حدا كان بيحبّك هالقد."], 
			[6.0, "child", "إنتِ ما رح تروحي. إنتِ ستّي."], [8.8, "grandma", "يا حبيبي… كل الناس ستّات حدا."]]})

	shots.append({"dur": 6.0, "fade_out": 2.0, 
		"from": [R(Vector3(0.2, 1.3, -2.8)), R(Vector3(-0.3, 0.9, 1.0))], 
		"to": [R(Vector3(0.2, 1.1, -3.2)), moon], "fov": [45.0, 55.0], "ease": "in"})

	shots.append({"dur": 4.2, "from": [R(Vector3(3.5, 2.2, 3.5)), R(Vector3(-1.0, 0.5, -0.6))], 
		"ev": [[0.1, _to_present], [0.3, func(): cs.show_title("", "بعد اثنعش سنة…", 2.4), "fx"]]})

	shots.append({"dur": 9.5, "fade_in": 1.8, 
		"from": [R(Vector3(3.0, 2.2, -2.8)), R(Vector3(-0.5, 0.6, -0.3))], 
		"to": [R(Vector3(2.5, 1.8, -2.3)), R(Vector3(-0.5, 0.6, -0.3))], "fov": 45.0, 
		"lines": [[1.4, "", "كنت برّا، بامتحانات آخر سنة. اتّصلت عليّ يوم الخميس… ما ردّيت. قلت: بردّ بكرا.", 6.2]]})

	shots.append({"dur": 9.5, 
		"from": [R(Vector3(-2.6, 1.35, 1.5)), R(Vector3(-0.3, 0.7, -0.2))], 
		"to": [R(Vector3(-2.35, 1.3, -1.95)), R(Vector3(-0.55, 0.9, -0.05))], "fov": 42.0, 
		"ev": [[0.0, _hero_walk_to_stool], [3.4, func(): hero.play("PickUp", 0.2)], 
			[4.1, _hero_takes_lantern], [5.6, _lantern_lights, "fx"]], 
		"lines": [[0.8, "", "رجعت بعد أربعين يوم. البيت كان مرتّب… وفانوسها على الكرسي، مطفّى.", 4.6]]})

	shots.append({"dur": 11.0, 
		"from": [R(Vector3(-1.4, 0.55, -1.9)), R(Vector3(0.0, 2.5, 6.0))], 
		"to": [R(Vector3(-1.6, 0.5, -2.4)), moon], "fov": [42.0, 58.0], 
		"ev": [[0.3, func(): Sfx.play("gust", -3.0), "fx"], [0.2, _hero_looks_up]], 
		"lines": [[0.8, "hero", "… ستّي؟"], [3.0, "", "ما بعرف إذا كان الكهربا. ولا الريح. ولا هيّ.", 3.6], 
			[7.0, "hero", "ماشي. طالع. بس لا تضحكي عليّ إذا وقعت."]]})

	shots.append({"dur": 6.5, "fade_out": 1.4, 
		"from": [R(Vector3(1.8, 1.6, 3.2)), R(Vector3(1.0, 1.2, 1.2))], 
		"to": [R(Vector3(3.5, 5.0, 7.5)), R(Vector3(1.0, 1.5, 1.2))], "fov": 50.0, "ease": "inout", 
		"ev": [[0.2, func(): hero.hold_lantern(true)]], 
		"title": [0.8, "طَلعة", "حكاية فانوس", 3.4]})
	cs.play(shots, func(skipped: bool):
		_end_prologue(on_done), true)

func _to_present() -> void :

	main.envm.set_override(main.envm.LOOK_DUSK, 1.0)
	sky_moon.visible = false
	Sfx.loop_off("night_loop", 1.0)
	if is_instance_valid(grandma):
		grandma.visible = false
	if is_instance_valid(child):
		child.visible = false
	roof_lantern.position = Vector3(-1.1, 0.48, -0.7)
	roof_lantern.set_lit(false, 0.0)
	if is_instance_valid(hero):
		hero.visible = true
		hero.position = Vector3(1.3, 0.0, 1.0)
		hero.face_point(R(Vector3(-1.1, 0, -0.7)))
		hero.play("Grief", 0.0)
	Sfx.play_music("music_story", 3.0)

func _hero_walk_to_stool() -> void :
	if not is_instance_valid(hero):
		return
	hero.visible = true
	hero.play("Walking_A", 0.2)
	var target: = Vector3(-0.55, 0.0, -0.05)
	hero.face_point(R(target))
	var tw: = create_tween()
	tw.tween_property(hero, "position", target, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback( func():
		hero.play("Grief", 0.4)
		hero.face_point(R(Vector3(-1.1, 0, -0.7))))

func _hero_looks_up() -> void :
	if is_instance_valid(hero):
		hero.play("LookUp", 0.6)
		hero.face_yaw(0.0)

func _hero_takes_lantern() -> void :
	if not is_instance_valid(hero):
		return
	hero.position = Vector3(-0.55, 0.0, -0.05)
	roof_lantern.visible = false
	var l: Node3D = hero.hold_lantern(false)
	l.call("set_lit", false, 0.0)

func _lantern_lights() -> void :
	if is_instance_valid(hero) and hero.lantern:
		hero.lantern.call("set_lit", true, 1.4)
	Sfx.play("lantern_on", -2.0)

func _end_prologue(on_done: Callable) -> void :

	Sfx.loop_off("night_loop", 0.5)
	main.envm.set_override({}, 0.0)
	sky_moon.visible = false
	roof_lantern.visible = false
	_free_actors()

	main.player.visible = true
	Game.story["prologue"] = true
	on_done.call()


const MEMORY: = {

	2: {"prop": "radio", "g_anim": "Idle", "c_anim": "Idle", 
		"lines": [["grandma", "اطلع يا سليم. السلّم ثابت، أنا ماسكته."], 
			["child", "بيهزّ!"], 
			["grandma", "اللي بيهزّ ركبك، مش السلّم. طلّع قدّامك… لا تطلّع تحت."], 
			["child", "وإذا وقعت؟"], 
			["grandma", "بتوقع. وبتقوم. وبنصلّح الهوائي، لأني بدّي أسمع فيروز قبل الإفطار."]]}, 

	3: {"prop": "embroidery", "g_anim": "Sit_Floor", "c_anim": "Sit_Floor", 
		"lines": [["child", "ليش فكّيتيها كلّها؟ كانت زي بعض!"], 
			["grandma", "غرزة وحدة عوجة. بس اللي بعدها كلّه بيروح عوج."], 
			["child", "وشو يعني؟ ما حدا بيلاحظ."], 
			["grandma", "أنا بلاحظ. ولما تكبر… بتلاحظ إنت كمان. خد، شدّ الخيط معي."]]}, 

	4: {"prop": "bed", "g_anim": "Sit_Chair", "c_anim": "Lie", 
		"lines": [["child", "ستّي… إنتِ بتخافي من إشي؟"], 
			["grandma", "آه. من الشبابيك المسكّرة."], 
			["child", "ليش؟"], 
			["grandma", "لأنه البيت اللي ما بيدخله هوا… بتصير ريحته ريحة انتظار. نام يلّا."]]}, 

	5: {"prop": "olive", "g_anim": "Idle", "c_anim": "Idle", 
		"lines": [["grandma", "هاي الزيتونة زرعناها يوم انولدت. سيدك حفر، وأنا حطّيتها."], 
			["child", "وهلّأ أطول مني!"], 
			["grandma", "لأنها ما بتحكي. بتشرب وبتسكت وبتطلع. ولما أروح أنا… زيتها إلك. لا تبيعها."], 
			["child", "ما بدّي أحكي عن لما تروحي."], 
			["grandma", "طيّب. بس الزيت إلك."]]}, 

	6: {"prop": "bench", "g_anim": "Sit_Chair", "c_anim": "Sit_Chair", 
		"lines": [["hero", "إجاني القبول. الجامعة برّا… بتبلّش بعد شهر."], 
			["grandma", "… روح."], 
			["hero", "هيك؟ بس روح؟"], 
			["grandma", "شو بدّي أقلّك، لا تروح؟ روح. بس ردّ عالتلفون. مش لازم تحكي كثير… بس خلّيني أسمع صوتك."], 
			["hero", "كل يوم."], 
			["grandma", "لا تحلف يا سليم."]]}, 
}

func _build_memories() -> void :
	var nodes: Array = level.nodes
	for i in nodes.size():
		var n: Dictionary = nodes[i]
		var z: = int(n.get("hub", 0))
		if z < 2 or not MEMORY.has(z) or memories.has(z):
			continue
		var c: Vector3 = level._v3(n.p)
		var nx: Dictionary = nodes[mini(i + 1, nodes.size() - 1)]
		var pv: Dictionary = nodes[maxi(i - 1, 0)]
		var u: = Vector3(float(nx.p[0]) - c.x, 0, float(nx.p[2]) - c.z)
		if u.length() < 0.1:
			u = Vector3(1, 0, 0)
		u = u.normalized()
		var v: = Vector3( - u.z, 0, u.x)
		var back: = Vector3(float(pv.p[0]) - c.x, 0, float(pv.p[2]) - c.z).normalized()
		var side: = 1.0 if back.dot(v) < 0.0 else -1.0
		var r: = float(n.r)
		var spot: Vector3
		if z == 4:

			var piece: Dictionary = level.route.pieces[int(n.piece)]
			var yaw: = float(piece.get("r", 0.0))
			var wz: = Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
			spot = c + wz * side * (r - 1.6)
			v = wz * side
		else:
			spot = c + v * side * clampf(r * 0.55, 2.2, 3.6)
		var root: = Node3D.new()
		root.name = "Memory%d" % z
		add_child(root)
		root.global_position = spot

		var to_c: = c - spot
		to_c.y = 0
		root.rotation.y = atan2(to_c.x, to_c.z)
		memories[z] = {"node": i, "center": c, "spot": spot, "root": root, "r": r}
		_memory_props(z, root)

func _memory_props(z: int, root: Node3D) -> void :
	match z:
		2:
			var rug: = _prop(root, "furniture/rug_oval_A.gltf", Vector3(0, 0.01, 0.6), 0.0, 1.0)
			var tbl: = _prop(root, "furniture/table_small.gltf", Vector3(-0.9, 0, -0.3), 0.0, 0.8)
			var chair: = _prop(root, "furniture/chair_A_wood.gltf", Vector3(-0.1, 0, -0.55), PI, 0.8)
			var radio: = make_radio(root)
			radio.position = Vector3(-0.9, 0.62, -0.3)
			radio.rotation.y = 0.3
			var snd = Sfx.make_3d("radio_loop", root, -6.0, 3.5, 30.0)
			radio_points.append(root.global_position if root.is_inside_tree() else root.position)
			_solid(root, Vector3(0.9, 0.8, 0.9), Vector3(-0.9, 0.4, -0.3))
		3:
			var hoop: = make_embroidery(root)
			hoop.position = Vector3(-0.5, 0, -0.4)
			var cush: = make_cushion(root, Color(0.55, 0.12, 0.16))
			cush.position = Vector3(0.1, 0, -0.1)
			var cush2: = make_cushion(root, Color(0.15, 0.3, 0.5))
			cush2.position = Vector3(0.95, 0, 0.1)
			make_threads(root, Vector3(-0.5, 1.1, -0.4), Vector3(-0.5, 7.0, -14.0))
		4:
			var bed: = _prop(root, "furniture/bed_single_A.gltf", Vector3(0, 0, -0.3), 0.0, 0.9)
			var pil: = _prop(root, "furniture/pillow_A.gltf", Vector3(0.0, 0.6, -1.0), 0.0, 0.9)
			var lamp: = _prop(root, "furniture/lamp_standing.gltf", Vector3(1.4, 0, -0.6), 0.0, 0.9)
			var ll: = OmniLight3D.new()
			ll.light_color = Color(1.0, 0.8, 0.55)
			ll.light_energy = 1.2
			ll.omni_range = 5.0
			ll.position = Vector3(1.4, 1.6, -0.6)
			root.add_child(ll)
			var chair: = _prop(root, "furniture/armchair.gltf", Vector3(-1.5, 0, 0.2), 0.6, 0.85)
			var frame: = _prop(root, "furniture/pictureframe_standing_A.gltf", Vector3(1.4, 0, 0.4), -0.4, 0.9)
			_solid(root, Vector3(1.3, 0.7, 2.3), Vector3(0, 0.35, -0.3))
		5:
			var olive: = Node3D.new()
			root.add_child(olive)
			olive.position = Vector3(0, 0, -0.9)
			var p: = {"p": [0, 2.3, 0], "rad": 2.6, "h": 4.6, "seed": 77}
			var ob: Node3D = level._olive_body(p)
			ob.position = Vector3.ZERO
			olive.add_child(ob)
			var can: = make_watering_can(root)
			can.position = Vector3(1.0, 0, 0.3)
		6:
			var bench: = _prop(root, "halloween/bench.gltf", Vector3(0, 0, -0.2), 0.0, 1.0)
			var l2: = LANTERN.new()
			l2.set("glow_range", 5.0)
			root.add_child(l2)
			l2.position = Vector3(1.1, 0, -0.1)
			_solid(root, Vector3(1.8, 0.5, 0.6), Vector3(0, 0.25, -0.2))

func _fade_ghosts(g, c) -> void :
	if g and is_instance_valid(g):
		g.set_ghost(false, 1.6)
	if c and is_instance_valid(c):
		c.set_ghost(false, 1.6)

func has_memory(z: int) -> bool:
	return memories.has(z) and not Game.story.get("m%d" % z, false)

func memory_at(p: Vector3) -> int:

	for z in memories.keys():
		if memory_trigger(z, p):
			return z
	return 0

func memory_trigger(z: int, p: Vector3) -> bool:
	if not has_memory(z):
		return false
	var m: Dictionary = memories[z]
	var c: Vector3 = m.center
	return absf(p.y - c.y) < 1.6 and Vector2(p.x - c.x, p.z - c.z).length() < float(m.r) + 0.3

func play_memory(z: int, on_done: Callable) -> void :
	var m: Dictionary = memories[z]
	var info: Dictionary = MEMORY[z]
	var root: Node3D = m.root
	var spot: Vector3 = m.spot
	var g = ACTOR.new()
	root.add_child(g)
	g.setup("grandma")
	var c = null
	if info.c_anim != "":
		c = ACTOR.new()
		root.add_child(c)
		c.setup("salim" if z == 6 else "child")

	match z:
		2:
			sit_on(g, Vector3(-0.1, 0.0, -0.55), 0.0, 0.42)
			c.position = Vector3(0.95, 0, 0.75)
			c.rotation.y = PI + 0.5
		3:
			sit_on(g, Vector3(0.1, 0.0, -0.1), -0.6, 0.12, "Sit_Floor")
			sit_on(c, Vector3(0.95, 0.0, 0.1), -1.9, 0.12, "Sit_Floor")
		4:
			sit_on(g, Vector3(-1.5, 0.0, 0.2), 0.6 + PI, 0.38)
			lie_on(c, Vector3(0.0, 0.0, 0.2), PI, 0.42)
		5:
			g.position = Vector3(-0.8, 0, 0.1)
			g.rotation.y = 0.5
			c.position = Vector3(0.1, 0, 0.35)
			c.rotation.y = -0.5
		6:
			sit_on(g, Vector3(-0.35, 0.0, -0.25), 0.0, 0.45)
			sit_on(c, Vector3(0.45, 0.0, -0.25), 0.0, 0.45)
	if z == 5 or z == 2:
		g.play(info.g_anim, 0.0)
	if c and (z == 5 or z == 2):
		c.play(info.c_anim, 0.0)
	g.set_ghost(true, 1.6)
	if c:
		c.set_ghost(true, 1.6, Color(0.75, 0.88, 1.0))

	var pl = main.player
	var to: Vector3 = spot - pl.global_position
	pl.get_node("Visual").rotation.y = atan2(to.x, to.z)
	Sfx.play("memory", -3.0)
	if z == 2:
		Sfx.music_stop(2.0)
	else:
		Sfx.play_music("music_story", 2.0)
	var fwd: Vector3 = root.global_transform.basis.z
	var right: Vector3 = root.global_transform.basis.x
	var look: = spot + Vector3(0, 0.9, 0)
	var plp: Vector3 = pl.global_position
	var sd: = 1.0

	if (plp - spot).dot(right) > 0.0:
		sd = -1.0
	var p0: = spot + fwd * 3.0 + right * sd * 3.2 + Vector3(0, 1.7, 0)
	var p1: = spot + fwd * 3.3 + right * sd * 1.6 + Vector3(0, 1.4, 0)
	if z == 5:
		look = spot + Vector3(0, 1.8, -0.5)
		p0 = spot + fwd * 4.5 + right * sd * 3.5 + Vector3(0, 2.0, 0)
		p1 = spot + fwd * 4.8 + right * sd * 1.8 + Vector3(0, 1.6, 0)
	var lines: Array = info.lines
	var shot_lines: = []
	var t: = 1.4
	for ln in lines:
		var txt: = String(ln[1])
		var d: = maxf(1.9 + txt.length() * 0.068, cs.voice.length(txt) + 0.6)
		shot_lines.append([t, ln[0], txt, d])
		t += d + 0.5
	var dur: = t + 1.4
	var shots: = [
		{"dur": dur, "from": [p0, look], "to": [p1, look], "fov": 42.0, "lines": shot_lines, 
			"ev": [[dur - 1.8, _fade_ghosts.bind(g, c)]]}, 
		{"dur": 3.4, "fade_out": 0.7, "from": [pl.global_position + (pl.global_position - spot).normalized() * 2.6 + Vector3(0, 1.7, 0), pl.global_position + Vector3(0, 1.3, 0)], 
			"to": [pl.global_position + (pl.global_position - spot).normalized() * 3.2 + Vector3(0, 2.0, 0), spot + Vector3(0, 1.0, 0)], "fov": 45.0}, 
	]
	shots[0]["fade_in"] = 0.9
	cs.play(shots, func(skipped: bool):
		cs.black(0.0, 0.8)
		if is_instance_valid(g):
			g.queue_free()
		if c and is_instance_valid(c):
			c.queue_free()
		Game.story["m%d" % z] = true
		on_done.call())


var _float_lantern: Node3D
var _ghost_g
var _lanterns_sky: GPUParticles3D

func play_ending(on_done: Callable) -> void :
	var pl = main.player
	var fin: Vector3 = level.finish_pos
	var body: Node3D = null
	for n in level.piece_nodes:
		if n and n.find_child("Crescent", false, false):
			body = n
			break
	var cres: Node3D = body.find_child("Crescent", false, false) if body else null
	var tip: = fin + Vector3(0, 7.0, 0)
	if cres:

		tip = cres.global_transform * Vector3(3.0, -4.45, 0.0)

	var n: = Vector3(0, 0, 1)
	if cres:
		n = cres.global_transform.basis.z
		n.y = 0
		n = n.normalized() if n.length() > 0.01 else Vector3(0, 0, 1)
	var hero_pos: Vector3 = Vector3(fin.x, pl.global_position.y, fin.z) + n * 1.6
	pl.teleport(hero_pos, 0.0)
	pl.freeze(true)
	var face: = - n
	pl.get_node("Visual").rotation.y = atan2(face.x, face.z)
	var side: = Vector3( - face.z, 0, face.x)
	Sfx.play_music("music_finale", 2.0, false)
	var shots: = []
	var g_pos: = hero_pos + side * 1.55
	var mid: = (hero_pos + g_pos) * 0.5

	shots.append({"dur": 8.0, "fade_in": 0.8, 
		"from": [hero_pos - face * 17.0 + side * 3.0 + Vector3(0, 2.5, 0), hero_pos + face * 1.5 + Vector3(0, 5.0, 0)], 
		"to": [hero_pos - face * 10.5 + side * 1.5 + Vector3(0, 1.8, 0), hero_pos + face * 1.5 + Vector3(0, 5.2, 0)], "fov": 55.0, 
		"lines": [[2.0, "", "وصلت. والهلال من قريب… أكبر من قصاصة ضفر بكثير.", 4.4]]})

	shots.append({"dur": 8.0, 
		"from": [hero_pos + face * 2.4 + side * 1.4 + Vector3(0, 1.3, 0), hero_pos + Vector3(0, 1.3, 0)], 
		"to": [hero_pos + face * 3.4 + side * 2.2 + Vector3(0, 0.9, 0), tip], "fov": [40.0, 52.0], 
		"ev": [[0.4, func(): _release_lantern(tip)]]})

	shots.append({"dur": 7.0, 
		"from": [mid + face * 3.6 + Vector3(0, 1.4, 0), mid + Vector3(0, 1.1, 0)], 
		"to": [mid + face * 3.1 + Vector3(0, 1.3, 0), mid + Vector3(0, 1.15, 0)], "fov": 42.0, 
		"ev": [[0.2, func(): _grandma_of_light(g_pos, hero_pos)]], 
		"lines": [[1.8, "grandma", "تأخّرت يا سليم."], [4.6, "hero", "… بعرف."]]})

	shots.append({"dur": 12.0, 
		"from": [hero_pos + side * 3.3 + face * 1.4 + Vector3(0, 1.55, 0), hero_pos + Vector3(0, 1.15, 0)], 
		"to": [hero_pos + side * 3.0 + face * 1.2 + Vector3(0, 1.5, 0), hero_pos + Vector3(0, 1.2, 0)], "fov": 38.0, 
		"lines": [[0.6, "hero", "ما ردّيت. ما ردّيت يا ستّي. كنت فاضي… وما ردّيت."], [5.2, "grandma", "بعرف. وبعرف إنك كنت ناوي. اسمعني هلّأ، ما في وقت."]]})

	shots.append({"dur": 15.0, 
		"from": [hero_pos - face * 5.0 + side * 4.0 + Vector3(0, 2.0, 0), hero_pos + Vector3(0, 2.5, 0)], 
		"to": [hero_pos - face * 30.0 + side * 20.0 + Vector3(0, 9.0, 0), hero_pos + Vector3(0, 4.0, 0)], "fov": [45.0, 62.0], 
		"ev": [[0.3, _grandma_rises], [1.0, _dawn], [0.5, _sky_lanterns], [2.4, func(): if main.soul: main.soul.rise_falls(hero_pos)]], 
		"lines": [[1.0, "grandma", "انزل. افتح الشبابيك كلّها. شغّل الراديو وعلّي الصوت. وردّ عالتلفون لما أمّك تتّصل."], 
			[7.4, "hero", "رمضان كريم يا ستّي."], [10.2, "grandma", "الله أكرم يا حبيبي… نزال بالسلامة."]]})
	shots[shots.size() - 1]["fade_out"] = 1.2
	cs.play(shots, func(skipped: bool):
		if _ghost_g and is_instance_valid(_ghost_g):
			_ghost_g.queue_free()
		if skipped:
			_dawn()
			if _lanterns_sky == null:
				_sky_lanterns()
		on_done.call()
		cs.black(0.0, 1.6))

func reset_after_ending() -> void :
	main.envm.set_override({}, 0.0)
	for n in [_float_lantern, _lanterns_sky, _ghost_g]:
		if n and is_instance_valid(n):
			n.queue_free()
	_float_lantern = null
	_lanterns_sky = null
	_ghost_g = null

func _release_lantern(tip: Vector3) -> void :
	var pl = main.player
	pl.call("set_lantern", false)
	_float_lantern = LANTERN.new()
	_float_lantern.set("glow_range", 9.0)
	_float_lantern.set("glow_energy", 2.2)
	add_child(_float_lantern)
	_float_lantern.global_position = pl.global_position + Vector3(0, 1.3, 0) + pl.get_node("Visual").global_transform.basis.z * 0.5
	_float_lantern.scale = Vector3.ONE * 1.3
	var tw: = create_tween()
	tw.tween_property(_float_lantern, "global_position", tip - Vector3(0, 1.12, 0), 6.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(_float_lantern, "scale", Vector3.ONE * 2.0, 6.5)
	tw.tween_callback( func():
		Sfx.play("lantern_on", 0.0)
		_float_lantern.set("glow_energy", 4.0)
		_float_lantern.set("glow_range", 18.0))
	Sfx.play("memory", -6.0)

func _grandma_of_light(pos: Vector3, look_at_pos: Vector3) -> void :
	_ghost_g = ACTOR.new()
	add_child(_ghost_g)
	_ghost_g.setup("grandma")
	_ghost_g.global_position = pos
	_ghost_g.face_point(look_at_pos)
	_ghost_g.play("Idle", 0.0)
	_ghost_g.set_ghost(true, 2.2, Color(1.0, 0.9, 0.7))
	var pl = main.player
	var to: Vector3 = pos - pl.global_position
	pl.get_node("Visual").rotation.y = atan2(to.x, to.z)

func _grandma_rises() -> void :
	if _ghost_g == null or not is_instance_valid(_ghost_g):
		return
	_ghost_g.play("Cheer", 0.6)
	var tw: = create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_ghost_g, "position", _ghost_g.position + Vector3(0, 9.0, 0), 7.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_callback( func(): _ghost_g.set_ghost(false, 6.0)).set_delay(1.0)

func _dawn() -> void :
	main.envm.set_override(main.envm.LOOK_DAWN, 1.0, 9.0)

	if ResourceLoader.exists("res://assets/audio/adhan_fajr.ogg"):
		Sfx.play_music("adhan_fajr", 3.0, false)
	else:
		Sfx.play_music("ney_fajr", 3.0, false)

func _sky_lanterns() -> void :

	var fin: Vector3 = level.finish_pos
	var p: = GPUParticles3D.new()
	p.amount = 420
	p.lifetime = 34.0
	p.preprocess = 20.0
	p.randomness = 0.6
	p.position = fin + Vector3(0, -90.0, 0)
	var pm: = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(170, 70, 170)
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3(0.4, 0.0, 0.2)
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 6.0
	p.process_material = pm
	var qm: = QuadMesh.new()
	qm.size = Vector2(2.6, 3.6)
	var sm: = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_texture = _lantern_sprite()
	sm.emission_enabled = true
	sm.emission_texture = sm.albedo_texture
	sm.emission = Color(1, 1, 1)
	sm.emission_energy_multiplier = 2.5
	qm.material = sm
	p.draw_pass_1 = qm
	p.visibility_aabb = AABB(Vector3(-300, -80, -300), Vector3(600, 600, 600))
	add_child(p)
	_lanterns_sky = p

func _lantern_sprite() -> Texture2D:
	var w: = 48
	var h: = 64
	var img: = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u: = (x - w * 0.5 + 0.5) / (w * 0.5)
			var v: = (y - h * 0.5 + 0.5) / (h * 0.5)
			var body: = 1.0 - smoothstep(0.55, 0.75, absf(u) + maxf(0.0, absf(v) - 0.55) * 0.9)
			body *= 1.0 - smoothstep(0.78, 0.92, absf(v))
			var glow: = clampf(1.0 - Vector2(u * 0.9, v * 0.7).length(), 0.0, 1.0)
			var col: = Color(1.0, 0.62 + 0.25 * glow, 0.28 + 0.3 * glow * glow)
			var frame: = 0.0
			if absf(v) > 0.7 and absf(v) < 0.82 and absf(u) < 0.62:
				frame = 1.0
			col = col.lerp(Color(0.35, 0.18, 0.08), frame * 0.85)
			var a: = maxf(body, glow * glow * 0.35)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
