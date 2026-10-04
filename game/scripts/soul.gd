extends Node3D











const ACTOR: = preload("res://scripts/actor.gd")

var main
var level
var ui
var letters: Array = []
var benches: Array = []
var _sit_bench: = -1
var _bench_block: = -1
var _still_t: = 0.0
var _bench_said: = {}
var _musah: Node3D
var _musah_a: = Vector3.ZERO
var _musah_b: = Vector3.ZERO
var _musah_u: = 0.0
var _musah_dir: = 1.0
var _musah_talked: = false
var _musah_pause: = 0.0
var _win_mats: Array = []
var _fall_mm: MultiMesh
var _fall_pts: Array = []
var _last_ground: = Vector3.ZERO
var _stars: MultiMeshInstance3D
var _stars_mat: StandardMaterial3D
var _stars_seen: = false
var _t: = 0.0

const LETTERS: = [
	[70, "سليم، وصلت؟ طمّني. ما تردّ هلّأ، بعرف إنك تعبان من الطيّارة. بس بكرا."], 
	[139, "اليوم زرعت الحبق عالسطح. الجارة قالت بيموت بالشتا. قلتلها: كل سنة بتقولي هيك، وكل سنة بيعيش."], 
	[200, "صوتك بالرسالة الصوتية مبحوح. لابس كنزة؟ أمّك بتقول إنك مش لابس كنزة."], 
	[307, "رحت عالدكتور. قال كله تمام. لا تتّصل عشان هيك… اتّصل عشان تحكيلي عن الجامعة."], 
	[401, "خلّصت الثوب. طلع أحلى من ثوب عرسي. كنت أطرّز وأحكي معك. ما تردّ… بس أنا بحكي."], 
	[505, "أول ليلة برمضان. طلعت عالسطح لحالي. الهلال طلع رفيع، زي كل سنة. ضوّيت الفانوس. اتّصل لما تفضى."], 
	[598, "يا سليم… لا تزعل على حالك. أنا بعرفك. بعرف إنك كنت ناوي تردّ. هاد بيكفّيني."], 
]
const BENCHES: = [
	[94, "الشمس بتغيب. من هون لسّا بشوف سطحها… الغسيل اللي نشرته لسّاته منشور. ما حدا جمعه."], 
	[154, "كنت أقول لحالي: بالصيف برجع. كل صيف."], 
	[271, "ركبي بتهزّ. هي كانت تقول: مش السلّم اللي بيهزّ… ركبك."], 
	[421, "فوق الغيم ساكت. أول مرة من أربعين يوم ما بسمع صوت بالبيت."], 
	[544, "صار وقت السحور. لو هون كانت سخّنتلي رغيف وقالت: كُل… إنت ما بتعرف توقع وإنت جوعان."], 
	[632, "قرّبت. ما بعرف شو بدّي أقلّها لما أوصل. يمكن ما في شي يُنحكى."], 
]

var ready_built: = false

func setup(main_ref) -> void :
	main = main_ref
	level = main.level

	await get_tree().physics_frame
	await get_tree().physics_frame
	_build_letters()
	_build_benches()
	_build_musaharati()
	_build_iftar_table(level.node_idx(88), level.node_idx(92))
	_build_olives()
	_build_laundry()
	_collect_window_mats()
	_build_fall_lights()
	_build_star_name()
	_add_tips()
	Surf.dress(self, level)
	ready_built = true
	print("SOUL placed: letters %d, benches %d, fall lights %d, misses %d" % [letters.size(), benches.size(), _fall_pts.size(), _misses])


func _v(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

func _dir_at(i: int) -> Vector3:
	var ns: Array = level.nodes
	var a: = _v(ns[maxi(i - 1, 0)].p)
	var b: = _v(ns[mini(i + 1, ns.size() - 1)].p)
	var d: = Vector3(b.x - a.x, 0, b.z - a.z)
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD

func _ground(p: Vector3, max_dy: = 1.2) -> Variant:

	var q: = PhysicsRayQueryParameters3D.create(p + Vector3(0, 2.0, 0), p + Vector3(0, -3.0, 0), 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or absf((hit.position as Vector3).y - p.y) > max_dy or (hit.normal as Vector3).y < 0.8:
		return null
	return hit.position

func _side_spot(i: int, lat: float) -> Array:

	var n: Dictionary = level.nodes[i]
	var p: = _v(n.p)
	var d: = _dir_at(i)
	var sd: = Vector3.UP.cross(d).normalized()
	var l: = lat
	while l > 0.6:
		for s in [1.0, -1.0]:
			var g = _ground(p + sd * s * l)
			if g != null:
				return [g, sd * s]
		l -= 0.5
	_misses += 1
	return [p, sd]

var _misses: = 0

func _m(key: String, c: Color, rough: = 0.8, metal: = 0.0, emit: = Color.BLACK, e: = 0.0) -> StandardMaterial3D:
	var m: = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if e > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = e
	m.resource_name = key
	return m

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
	var bm: = BoxMesh.new()
	bm.size = size
	return _mesh(parent, bm, pos, mat, rot)

func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material, segs: = 10, rt: = -1.0) -> MeshInstance3D:
	var cm: = CylinderMesh.new()
	cm.top_radius = r if rt < 0.0 else rt
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	return _mesh(parent, cm, pos, mat)

func _sphere(parent: Node3D, r: float, pos: Vector3, mat: Material, sc: = Vector3.ONE) -> MeshInstance3D:
	var sm: = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	return _mesh(parent, sm, pos, mat, Vector3.ZERO, sc)

func _vis(root: Node3D, far: float) -> void :
	if not Game.mobile:
		return
	for gi in root.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).visibility_range_end = far
		(gi as GeometryInstance3D).visibility_range_end_margin = 30.0

func _player() -> CharacterBody3D:
	return main.player if main else null


func _make_pigeon(parent: Node3D) -> Node3D:
	var n: = Node3D.new()
	parent.add_child(n)
	var grey: = _m("pigeon", Color(0.62, 0.66, 0.74), 0.7)
	var dark: = _m("pigeon_d", Color(0.36, 0.39, 0.46), 0.7)
	var neck: = _m("pigeon_n", Color(0.32, 0.55, 0.45), 0.35, 0.4)
	var beak: = _m("pigeon_b", Color(0.95, 0.8, 0.6), 0.6)
	var eye: = _m("pigeon_e", Color(0.9, 0.35, 0.1), 0.3)
	_sphere(n, 0.13, Vector3(0, 0.14, 0), grey, Vector3(1.0, 0.95, 1.45))
	_sphere(n, 0.085, Vector3(0, 0.29, 0.13), neck)
	_sphere(n, 0.075, Vector3(0, 0.34, 0.16), grey)
	_cyl(n, 0.0, 0.07, Vector3(0, 0.33, 0.25), beak, 6, 0.018).rotation.x = PI * 0.5
	for sx in [-1.0, 1.0]:
		_sphere(n, 0.014, Vector3(sx * 0.055, 0.36, 0.2), eye)
		var w: = _box(n, Vector3(0.05, 0.1, 0.26), Vector3(sx * 0.11, 0.16, -0.03), dark, Vector3(0.15, 0, sx * 0.25))
		w.name = "wing_l" if sx < 0 else "wing_r"
		_cyl(n, 0.012, 0.1, Vector3(sx * 0.04, 0.04, 0.02), beak, 5)
	_box(n, Vector3(0.12, 0.03, 0.18), Vector3(0, 0.15, -0.22), dark, Vector3(-0.3, 0, 0))

	var paper: = _m("paper", Color(0.96, 0.92, 0.8), 0.9)
	var red: = _m("thread", Color(0.8, 0.1, 0.1), 0.8)
	var roll: = _cyl(n, 0.022, 0.12, Vector3(0.07, 0.05, 0.03), paper, 8)
	roll.rotation.z = PI * 0.5
	_cyl(n, 0.025, 0.015, Vector3(0.07, 0.05, 0.03), red, 8).rotation.z = PI * 0.5
	return n

func _build_letters() -> void :
	var wood: = _m("post_wood", Color(0.5, 0.34, 0.2), 0.85)
	var glow: = _m("letter_glow", Color(1.0, 0.85, 0.5), 0.5, 0.0, Color(1.0, 0.8, 0.45), 1.6)
	for k in LETTERS.size():
		var ni: int = level.node_idx(LETTERS[k][0])
		if ni >= level.nodes.size():
			continue
		var spot: Array = _side_spot(ni, 2.2)
		var pos: Vector3 = spot[0]
		var root: = Node3D.new()
		add_child(root)
		root.global_position = pos
		root.rotation.y = atan2( - spot[1].x, - spot[1].z)
		_cyl(root, 0.06, 0.9, Vector3(0, 0.45, 0), wood, 6)
		_box(root, Vector3(0.36, 0.05, 0.26), Vector3(0, 0.92, 0), wood)

		var ring: = MeshInstance3D.new()
		var tm: = TorusMesh.new()
		tm.inner_radius = 0.55
		tm.outer_radius = 0.62
		tm.rings = 24
		tm.ring_segments = 4
		ring.mesh = tm
		ring.material_override = glow
		ring.position = Vector3(0, 0.03, 0)
		root.add_child(ring)
		var pg: = _make_pigeon(root)
		pg.position = Vector3(0, 0.95, 0)
		_vis(root, 160.0)
		var id: = k + 1
		var taken: bool = Game.story.get("L%d" % id, false)
		root.visible = not taken
		letters.append({"id": id, "pos": pos, "root": root, "pigeon": pg, "taken": taken, "text": LETTERS[k][1], "t": randf() * 5.0})

func _update_letters(delta: float, pp: Vector3) -> void :
	for L in letters:
		if L.taken:
			continue
		var pg: Node3D = L.pigeon
		L.t += delta

		pg.rotation.y = sin(L.t * 0.8) * 0.6
		pg.rotation.x = maxf(sin(L.t * 3.1), 0.0) * 0.35 if fmod(L.t, 6.0) < 1.2 else 0.0
		var rel: Vector3 = pp - (L.pos as Vector3)
		if Vector2(rel.x, rel.z).length() < 1.45 and absf(rel.y) < 1.6:
			_take_letter(L)
		elif Vector2(rel.x, rel.z).length() < 12.0 and fmod(L.t, 7.0) < delta:
			Sfx.play("pigeon_coo", -10.0, 0.1)

func _take_letter(L: Dictionary) -> void :
	L.taken = true
	Game.story["L%d" % L.id] = true
	Game.album_add("letters", str(L.id))
	Sfx.play("wings", -2.0, 0.05)
	Sfx.play("pigeon_coo", -6.0)
	Game.haptic(20, 0.4)

	var pg: Node3D = L.pigeon
	var root: Node3D = L.root
	var away: = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized() * 9.0 + Vector3(0, 7.0, 0)
	var tw: = create_tween()
	tw.tween_property(pg, "position", pg.position + away, 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method( func(k: float):
		for w in [pg.get_node_or_null("wing_l"), pg.get_node_or_null("wing_r")]:
			if w:
				(w as Node3D).rotation.z = sin(k * 60.0) * 0.9 * (1.0 if w.name == "wing_l" else -1.0), 0.0, 1.0, 2.4)
	tw.tween_callback( func(): root.visible = false)
	if ui:
		ui.show_letter(L.id, L.text, letters.size())

func letters_found() -> int:
	var c: = 0
	for L in letters:
		if L.taken:
			c += 1
	return c


func _build_benches() -> void :
	var wood: = _m("bench_wood", Color(0.55, 0.36, 0.2), 0.8)
	var iron: = _m("bench_iron", Color(0.16, 0.16, 0.17), 0.5, 0.6)
	for k in BENCHES.size():
		var ni: int = level.node_idx(BENCHES[k][0])
		if ni >= level.nodes.size():
			continue
		var n: Dictionary = level.nodes[ni]
		var w: float = float(n.get("w", 6.0))
		var spot: Array = _side_spot(ni, w * 0.38)
		var pos: Vector3 = spot[0]
		var out: Vector3 = spot[1]
		var root: = Node3D.new()
		add_child(root)
		root.global_position = pos

		var yaw: = atan2(out.x, out.z)
		root.rotation.y = yaw
		_box(root, Vector3(1.7, 0.07, 0.45), Vector3(0, 0.45, 0), wood)
		for j in 3:
			_box(root, Vector3(1.7, 0.1, 0.035), Vector3(0, 0.62 + j * 0.13, -0.24), wood, Vector3(-0.15, 0, 0))
		for sx in [-0.72, 0.72]:
			_box(root, Vector3(0.06, 0.45, 0.4), Vector3(sx, 0.22, 0), iron)
			_box(root, Vector3(0.06, 0.5, 0.05), Vector3(sx, 0.7, -0.26), iron, Vector3(-0.15, 0, 0))

		_cyl(root, 0.03, 1.5, Vector3(1.05, 0.75, -0.1), iron, 6)
		var lamp: = _cyl(root, 0.11, 0.26, Vector3(1.05, 1.35, 0.05), _m("bench_lamp", Color(1, 0.8, 0.45), 0.4, 0.0, Color(1.0, 0.72, 0.35), 2.4), 6, 0.13)
		lamp.name = "Lamp"
		var sb: = StaticBody3D.new()
		root.add_child(sb)
		var cs: = CollisionShape3D.new()
		var bs: = BoxShape3D.new()
		bs.size = Vector3(1.7, 0.48, 0.45)
		cs.shape = bs
		cs.position = Vector3(0, 0.24, 0)
		sb.add_child(cs)
		level._merge_meshes(root)
		_vis(root, 200.0)
		var seat: = pos + out * 0.05 + Vector3(0, 0.0, 0)
		benches.append({"pos": pos, "front": pos + out * 0.75, "yaw": yaw, "line": BENCHES[k][1], "root": root, "seat": seat})

func carry_transform() -> Transform3D:

	var b: Dictionary = benches[_sit_bench]
	var fwd: = Vector3(sin(b.yaw), 0, cos(b.yaw))
	return Transform3D(Basis(Vector3.UP, b.yaw), (b.pos as Vector3) + fwd * 0.02 + Vector3(0, -0.02, 0))

func _update_benches(delta: float, pl: CharacterBody3D) -> void :
	if _sit_bench >= 0:
		var mv: = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if (mv.length() > 0.35 or Input.is_action_just_pressed("jump")) and not Game.input_blocked:
			_stand_up(pl)
		return
	if pl.bot_enabled or pl.state != pl.State.NORMAL or not pl.is_on_floor():
		_still_t = 0.0
		return
	var hv: = Vector2(pl.velocity.x, pl.velocity.z).length()
	var near: = -1
	for k in benches.size():
		var f: Vector3 = benches[k].front
		var dh: = Vector2(pl.global_position.x - f.x, pl.global_position.z - f.z).length()
		if k == _bench_block and dh > 1.8:
			_bench_block = -1
		if dh < 1.1 and absf(pl.global_position.y - f.y) < 0.8 and k != _bench_block:
			near = k
	if near >= 0 and hv < 0.3:
		_still_t += delta
		if _still_t > 1.0:
			_sit(pl, near)
	else:
		_still_t = 0.0

func _sit(pl: CharacterBody3D, k: int) -> void :
	_sit_bench = k
	if not pl.start_carry(self, "free"):
		_sit_bench = -1
		return
	pl.play_anim("Sit_Chair_Idle", 0.35)
	Sfx.play("step", -8.0)
	if not _bench_said.has(k):
		_bench_said[k] = true
		if ui:
			ui.say("سليم", benches[k].line, 5.5)
	if ui:
		ui.show_hint_small("حرّك أو اقفز لتقوم")

func _stand_up(pl: CharacterBody3D) -> void :
	var k: = _sit_bench
	_sit_bench = -1
	_still_t = 0.0
	_bench_block = k
	var b: Dictionary = benches[k]

	var fwd: = Vector3(sin(b.yaw), 0, cos(b.yaw))
	var back = _ground((b.pos as Vector3) - fwd * 0.75)
	pl.global_position = (back as Vector3) + Vector3(0, 0.05, 0) if back != null else b.front
	pl.end_carry(Vector3.ZERO)

func is_sitting() -> bool:
	return _sit_bench >= 0


var _musah_path: Array = []
var _musah_cum: Array = []

func _build_musaharati() -> void :
	var ns: Array = level.nodes
	if ns.size() < 545:
		return

	for sgn in [1.0, -1.0]:
		var pts: Array = []
		for i in range(level.node_idx(539), level.node_idx(543) + 1):
			var p: = _v(ns[i].p)
			var d: = _dir_at(i)
			var sd: Vector3 = Vector3.UP.cross(d).normalized() * sgn
			var w: = float(ns[i].get("w", 8.0))
			var g = _ground(p + sd * w * 0.32)
			if g == null:
				g = _ground(p + sd * w * 0.2)
			if g != null:
				pts.append(g)
		if pts.size() >= 3:
			_musah_path = pts
			break
	if _musah_path.size() < 2:
		return
	_musah_cum = [0.0]
	for k in range(1, _musah_path.size()):
		_musah_cum.append(float(_musah_cum[k - 1]) + (_musah_path[k] as Vector3).distance_to(_musah_path[k - 1]))
	_musah_a = _musah_path[0]
	_musah_b = _musah_path[_musah_path.size() - 1]
	_musah = ACTOR.new()
	add_child(_musah)
	_musah.setup("musahhir")
	_musah.global_position = _musah_a

	var hide: = _m("drum_skin", Color(0.93, 0.87, 0.72), 0.8)
	var rim: = _m("drum_rim", Color(0.6, 0.3, 0.15), 0.6)
	var drum: = Node3D.new()
	_musah.add_child(drum)
	drum.position = Vector3(0.0, 0.95, 0.3)
	_cyl(drum, 0.24, 0.2, Vector3.ZERO, rim, 16).rotation.x = PI * 0.5
	_cyl(drum, 0.235, 0.21, Vector3.ZERO, hide, 16).rotation.x = PI * 0.5

	var lan: Node3D = load("res://scripts/lantern.gd").new()
	lan.set("glow_range", 5.0)
	lan.set("glow_energy", 1.2)
	_musah.add_child(lan)
	lan.position = Vector3(-0.38, 0.62, 0.12)
	var snd: = Sfx.make_3d("musahhar_drum", _musah, -2.0, 6.0, 55.0)
	if snd:
		snd.bus = "SFX"
	_musah.play("Walking_A", 0.0, 0.8)

func _update_musaharati(delta: float, pp: Vector3) -> void :
	if _musah == null:
		return
	var L: float = _musah_cum[_musah_cum.size() - 1] if not _musah_cum.is_empty() else 0.0
	if L < 0.5:
		return
	if _musah_pause > 0.0:
		_musah_pause -= delta
		if _musah_pause <= 0.0:
			_musah.play("Walking_A", 0.3, 0.8)
		return
	_musah_u += _musah_dir * delta * 0.9 / L
	if _musah_u >= 1.0 or _musah_u <= 0.0:
		_musah_u = clampf(_musah_u, 0.0, 1.0)
		_musah_dir = - _musah_dir
		_musah_pause = 2.5
		_musah.play("Idle", 0.3)
	var p: = _musah_at(_musah_u * L)
	_musah.global_position = p
	var d: = (_musah_at(_musah_u * L + 0.5 * _musah_dir) - p)
	_musah.rotation.y = lerp_angle(_musah.rotation.y, atan2(d.x, d.z), 1.0 - exp(-5.0 * delta))
	if not _musah_talked and p.distance_to(pp) < 8.0 and ui:
		_musah_talked = true
		_musah_pause = 7.0
		_musah.play("Idle", 0.3)
		var to: = pp - p
		_musah.rotation.y = atan2(to.x, to.z)
		ui.say("المسحّراتي", "اصحى يا نايم… وحّد الدايم! سحورك يا صايم!", 3.6)
		get_tree().create_timer(3.8).timeout.connect( func():
			if ui:
				ui.say("المسحّراتي", "سليم؟ ابن الحجّة أم سليمان؟… الله يرحمها. ثلاثين سنة بمرّ من هون، وكل ليلة بتفتحلي الشبّاك وبتعطيني كعكة للطريق.", 7.5)
			get_tree().create_timer(7.8).timeout.connect( func():
				if ui:
					ui.say("المسحّراتي", "روح يا ابني… والله معك. بس لا تطوّل فوق، الفجر ما بيستنّى.", 4.8)))

func _musah_at(dist: float) -> Vector3:
	dist = clampf(dist, 0.0, float(_musah_cum[_musah_cum.size() - 1]))
	for k in range(1, _musah_path.size()):
		if dist <= float(_musah_cum[k]) or k == _musah_path.size() - 1:
			var seg: float = maxf(float(_musah_cum[k]) - float(_musah_cum[k - 1]), 0.001)
			return (_musah_path[k - 1] as Vector3).lerp(_musah_path[k], clampf((dist - float(_musah_cum[k - 1])) / seg, 0.0, 1.0))
	return _musah_a


func _build_iftar_table(i0: int, i1: int) -> void :
	var ns: Array = level.nodes
	if ns.size() <= i1:
		return

	var spot = null
	var dn: = Vector3.FORWARD
	var Lt: = 5.5
	for i in range(i0, i1 + 1):
		var p: = _v(ns[i].p)
		var d: = _dir_at(i)
		var w: = float(ns[i].get("w", 8.0))
		for frac in [0.33, 0.26, 0.2]:
			for sgn in [1.0, -1.0]:
				var sd: Vector3 = Vector3.UP.cross(d).normalized() * sgn
				var c: Vector3 = p + sd * w * float(frac)
				var g0 = _ground(c)
				var g1 = _ground(c + d * (Lt * 0.5 + 0.4))
				var g2 = _ground(c - d * (Lt * 0.5 + 0.4))
				if g0 != null and g1 != null and g2 != null:
					spot = g0
					dn = d
					break
			if spot != null:
				break
		if spot != null:
			break
	if spot == null:
		_misses += 1
		return
	var root: = Node3D.new()
	root.name = "Iftar"
	add_child(root)
	root.global_position = spot
	root.rotation.y = atan2(dn.x, dn.z)
	var wood: = _m("iftar_wood", Color(0.45, 0.28, 0.16), 0.7)
	var cloth: = _m("iftar_cloth", Color(0.96, 0.93, 0.86), 0.9)
	var red: = _m("iftar_red", Color(0.72, 0.1, 0.12), 0.8)
	var green: = _m("iftar_green", Color(0.1, 0.42, 0.24), 0.8)
	var plate: = _m("iftar_plate", Color(0.95, 0.95, 0.92), 0.3)
	var dates: = _m("iftar_dates", Color(0.32, 0.14, 0.06), 0.4)
	var soup: = _m("iftar_soup", Color(0.9, 0.58, 0.2), 0.3)
	var jallab: = _m("iftar_jallab", Color(0.45, 0.05, 0.08), 0.1)
	var qamar: = _m("iftar_qamar", Color(1.0, 0.55, 0.12), 0.1)
	var bread: = _m("iftar_bread", Color(0.88, 0.66, 0.36), 0.9)
	var copper: = _m("iftar_copper", Color(0.85, 0.52, 0.26), 0.3, 0.8)

	_box(root, Vector3(1.1, 0.06, Lt), Vector3(0, 0.62, 0), wood)
	for sz in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			_box(root, Vector3(0.07, 0.6, 0.07), Vector3(sx * 0.45, 0.3, sz * (Lt * 0.5 - 0.15)), wood)
	_box(root, Vector3(1.26, 0.02, Lt + 0.1), Vector3(0, 0.66, 0), cloth)
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(0.02, 0.22, Lt + 0.1), Vector3(sx * 0.63, 0.56, 0), cloth)
		_box(root, Vector3(0.025, 0.05, Lt + 0.1), Vector3(sx * 0.635, 0.52, 0), red)
		_box(root, Vector3(0.025, 0.02, Lt + 0.1), Vector3(sx * 0.635, 0.48, 0), green)

	var n: = int(Lt / 0.9)
	for k in n:
		var z: = - Lt * 0.5 + (k + 0.5) * Lt / n
		for sx in [-1.0, 1.0]:
			_cyl(root, 0.17, 0.02, Vector3(sx * 0.32, 0.68, z), plate, 14)
			_cyl(root, 0.1, 0.05, Vector3(sx * 0.32, 0.71, z), soup, 12)
			var g: = _cyl(root, 0.035, 0.12, Vector3(sx * 0.46, 0.73, z + 0.18), jallab if (k + int(sx)) % 2 == 0 else qamar, 8)
			g.name = "glass"

			_box(root, Vector3(0.4, 0.12, 0.4), Vector3(sx * 0.95, 0.06, z), red if k % 2 == 0 else green)
		_cyl(root, 0.14, 0.02, Vector3(0, 0.68, z + 0.1), bread, 12)
		if k % 2 == 0:
			_cyl(root, 0.12, 0.03, Vector3(0, 0.69, z - 0.25), plate, 12)
			for j in 5:
				_sphere(root, 0.025, Vector3(randf_range(-0.07, 0.07), 0.715, z - 0.25 + randf_range(-0.07, 0.07)), dates, Vector3(1.0, 0.8, 1.6))
	_cyl(root, 0.1, 0.34, Vector3(0.05, 0.84, Lt * 0.5 - 0.35), copper, 12, 0.05)

	var lan: Node3D = load("res://scripts/lantern.gd").new()
	lan.set("glow_range", 5.0)
	lan.set("glow_energy", 1.5)
	root.add_child(lan)
	lan.position = Vector3(0, 0.69, 0)
	lan.scale = Vector3.ONE * 1.3
	for sz in [-1.0, 1.0]:
		_cyl(root, 0.04, 2.6, Vector3(0.75, 1.3, sz * (Lt * 0.5 + 0.2)), wood, 6)
	var bulb: = _m("iftar_bulb", Color(1, 0.85, 0.5), 0.5, 0.0, Color(1.0, 0.75, 0.4), 3.0)
	for k2 in 14:
		var u: = (k2 + 0.5) / 14.0
		var zz: = lerpf( - (Lt * 0.5 + 0.2), Lt * 0.5 + 0.2, u)
		_sphere(root, 0.05, Vector3(0.75, 2.55 - sin(u * PI) * 0.5, zz), bulb)
	var sb: = StaticBody3D.new()
	root.add_child(sb)
	var cs: = CollisionShape3D.new()
	var bs: = BoxShape3D.new()
	bs.size = Vector3(1.26, 0.68, Lt)
	cs.shape = bs
	cs.position = Vector3(0, 0.34, 0)
	sb.add_child(cs)
	level._merge_meshes(root)
	_vis(root, 220.0)


func _build_olives() -> void :
	var ns: Array = level.nodes
	var sites: = [[3, 0.45]]
	var sz: = 0.62
	for i in ns.size():
		if ns[i].has("hub") and int(ns[i].hub) >= 2:
			sites.append([i, sz])
			sz += 0.2
	var leaf: Material = level.mat("olive_leaf")
	var trunk: Material = level.mat("olive_trunk")
	var olive_m: = _m("olives", Color(0.2, 0.26, 0.12), 0.35)
	for s in sites:
		var i: int = s[0]
		var k: float = s[1]
		var p: = _v(ns[i].p)
		var best = null
		var best_d: = -1.0
		var r: float = float(ns[i].r)
		for j in 12:
			var a: = TAU * j / 12.0
			for rr in [r * 0.8, r * 0.6, 3.0]:
				var c: Vector3 = p + Vector3(cos(a), 0, sin(a)) * rr
				var g = _ground(c, 0.6)
				if g == null:
					continue

				var dmin: = 99.0
				for di in range(-3, 4):
					var q: = _v(ns[clampi(i + di, 0, ns.size() - 1)].p)
					dmin = minf(dmin, Vector2(q.x - c.x, q.z - c.z).length())
				if main.story and main.story.memories.has(int(ns[i].z)):
					var ms: Vector3 = main.story.memories[int(ns[i].z)].spot
					dmin = minf(dmin, Vector2(ms.x - c.x, ms.z - c.z).length() * 0.8)
				if dmin > best_d:
					best_d = dmin
					best = g
				break
		if best == null:
			continue
		var root: = Node3D.new()
		add_child(root)
		root.global_position = best
		root.scale = Vector3.ONE * k
		var rng: = RandomNumberGenerator.new()
		rng.seed = 77 + i
		var h: = 3.2
		var tr: = _cyl(root, 0.3, h * 0.55, Vector3(0, h * 0.27, 0), trunk, 7, 0.2)
		tr.rotation.z = rng.randf_range(-0.2, 0.2)
		for b in 3:
			var br: = _cyl(root, 0.14, h * 0.4, Vector3(rng.randf_range(-0.35, 0.35), h * 0.55, rng.randf_range(-0.35, 0.35)), trunk, 6, 0.08)
			br.rotation = Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		var blobs: = 4 + int(k * 4.0)
		for b in blobs:
			var a2: = rng.randf() * TAU
			var dd: = rng.randf_range(0.0, 0.9)
			var rr2: = rng.randf_range(0.6, 0.95)
			_sphere(root, rr2, Vector3(cos(a2) * dd, h * 0.74 + rng.randf_range(-0.3, 0.5), sin(a2) * dd), leaf, Vector3(1.0, 0.7, 1.0))
		if k > 1.0:

			for o in int((k - 0.9) * 40.0):
				var a3: = rng.randf() * TAU
				_sphere(root, 0.05, Vector3(cos(a3) * rng.randf_range(0.6, 1.3), h * 0.62 + rng.randf_range(-0.2, 0.5), sin(a3) * rng.randf_range(0.6, 1.3)), olive_m, Vector3(1.0, 1.3, 1.0))
		var sb: = StaticBody3D.new()
		root.add_child(sb)
		var cs: = CollisionShape3D.new()
		var cy: = CylinderShape3D.new()
		cy.radius = 0.3
		cy.height = h * 0.6
		cs.shape = cy
		cs.position = Vector3(0, h * 0.3, 0)
		sb.add_child(cs)
		level._merge_meshes(root)
		_vis(root, 300.0)


func _build_laundry() -> void :
	var cols: = [Color(0.85, 0.2, 0.2), Color(0.95, 0.95, 0.92), Color(0.2, 0.45, 0.8), Color(0.95, 0.75, 0.2), 
		Color(0.25, 0.6, 0.35), Color(0.9, 0.5, 0.65), Color(0.15, 0.15, 0.18)]
	var rope: = _m("rope", Color(0.85, 0.8, 0.68), 0.9)
	var peg: = _m("peg", Color(0.7, 0.5, 0.3), 0.8)
	var pole: = _m("laundry_pole", Color(0.35, 0.35, 0.38), 0.5, 0.5)
	var cloth_mats: = []
	for c in cols:
		var cm: = _m("cloth", c, 0.95)
		cm.cull_mode = BaseMaterial3D.CULL_DISABLED
		cloth_mats.append(cm)
	var rng: = RandomNumberGenerator.new()
	rng.seed = 12
	for pi in level.route.pieces.size():
		var p: Dictionary = level.route.pieces[pi]
		if p.t != "beam" or int(p.get("z", 0)) != 2 or p.role != "path":
			continue
		var body: Node3D = level.piece_nodes[pi]
		if body == null:
			continue
		var d: = _v(p.d)
		var root: = Node3D.new()
		body.add_child(root)
		var L: = d.x
		for sz in [-1.0, 1.0]:
			var z: float = sz * (d.z * 0.5 + 0.25)
			for sx in [-1.0, 1.0]:
				_cyl(root, 0.04, 1.6, Vector3(sx * (L * 0.5 - 0.1), d.y * 0.5 + 0.8, z), pole, 6)
			var r: = _cyl(root, 0.012, L - 0.2, Vector3(0, d.y * 0.5 + 1.45, z), rope, 4)
			r.rotation.z = PI * 0.5
			var x: = - L * 0.5 + 0.5
			while x < L * 0.5 - 0.5:
				var kind: = rng.randi_range(0, 3)
				var cm: Material = cloth_mats[rng.randi_range(0, cloth_mats.size() - 1)]
				var cw: = rng.randf_range(0.35, 0.7)
				var chh: = rng.randf_range(0.4, 0.75)
				var piece: = Node3D.new()
				root.add_child(piece)
				piece.position = Vector3(x + cw * 0.5, d.y * 0.5 + 1.45, z)
				piece.set_meta("sway", rng.randf() * TAU)
				if kind == 0:

					_box(piece, Vector3(cw, chh, 0.02), Vector3(0, - chh * 0.5, 0), cm)
					for s2 in [-1.0, 1.0]:
						_box(piece, Vector3(cw * 0.35, chh * 0.3, 0.02), Vector3(s2 * cw * 0.6, - chh * 0.18, 0), cm, Vector3(0, 0, s2 * 0.5))
				elif kind == 1:

					_box(piece, Vector3(cw, chh * 1.2, 0.02), Vector3(0, - chh * 0.6, 0), cm)
					_box(piece, Vector3(cw, 0.05, 0.025), Vector3(0, - chh * 1.05, 0), cloth_mats[0])
				elif kind == 2:

					_box(piece, Vector3(cw * 0.9, chh * 1.8, 0.02), Vector3(0, - chh * 0.9, 0), cloth_mats[6])
					_box(piece, Vector3(cw * 0.5, chh * 0.4, 0.025), Vector3(0, - chh * 0.35, 0), cloth_mats[0])
				else:

					for s3 in [-0.12, 0.12]:
						_box(piece, Vector3(0.1, 0.3, 0.02), Vector3(s3, -0.15, 0), cm)
				_box(piece, Vector3(0.03, 0.08, 0.04), Vector3( - cw * 0.3, 0.0, 0), peg)
				_box(piece, Vector3(0.03, 0.08, 0.04), Vector3(cw * 0.3, 0.0, 0), peg)
				x += cw + rng.randf_range(0.25, 0.6)
		root.set_meta("laundry", true)
		if Game.mobile:

			for piece in root.get_children():
				if piece.has_meta("sway"):
					for mi in piece.get_children():
						var xf: Transform3D = (piece as Node3D).transform * (mi as Node3D).transform
						piece.remove_child(mi)
						root.add_child(mi)
						(mi as Node3D).transform = xf
					piece.remove_meta("sway")
			level._merge_meshes(root)
		else:
			_laundry.append(root)
		_vis(root, 160.0)

var _laundry: Array = []

func _update_laundry(pp: Vector3) -> void :
	for root in _laundry:
		var r: = root as Node3D
		if r.global_position.distance_to(pp) > 70.0:
			continue
		for c in r.get_children():
			if c.has_meta("sway"):
				var ph: float = c.get_meta("sway")
				(c as Node3D).rotation.x = sin(_t * 1.7 + ph) * 0.18 + 0.08


func _collect_window_mats() -> void :
	for k in 5:
		var m = level.mat("window_lit%d" % k)
		if m:
			_win_mats.append(m)

func _update_windows() -> void :
	if _win_mats.is_empty():
		return

	var top: = maxf(float(level.nodes[-1].p[1]), 1.0)
	var prog: = clampf(maxf(Game.stats_max_height, _player().global_position.y) / top, 0.0, 1.0)
	var th: = [0.0, 0.06, 0.16, 0.32, 0.55]
	var night: = 1.0
	if main.envm and main.envm._cur_look.has("win"):
		night = float(main.envm._cur_look.win)
	for k in _win_mats.size():
		var e: = smoothstep(th[k], th[k] + 0.05, prog) * (0.6 + 0.4 * night)
		(_win_mats[k] as ShaderMaterial).set_shader_parameter("emission_strength", 2.4 * e)


func _build_fall_lights() -> void :
	_fall_mm = MultiMesh.new()
	_fall_mm.transform_format = MultiMesh.TRANSFORM_3D
	_fall_mm.use_colors = true
	var sm: = SphereMesh.new()
	sm.radius = 0.17
	sm.height = 0.34
	sm.radial_segments = 8
	sm.rings = 4
	_fall_mm.mesh = sm
	_fall_mm.instance_count = 80
	_fall_mm.visible_instance_count = 0
	var mat: = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	var mi: = MultiMeshInstance3D.new()
	mi.multimesh = _fall_mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	for q in Game.fall_marks:
		_fall_pts.append(Vector3(float(q[0]), float(q[1]), float(q[2])))

func on_big_fall(fall: float) -> void :

	var p: = _last_ground + Vector3(0, 1.3, 0)
	for q in _fall_pts:
		if (q as Vector3).distance_to(p) < 2.0:
			return
	_fall_pts.append(p)
	if _fall_pts.size() > 80:
		_fall_pts.pop_front()
	Game.fall_marks = []
	for q in _fall_pts:
		Game.fall_marks.append([snappedf(q.x, 0.01), snappedf(q.y, 0.01), snappedf(q.z, 0.01)])

func _update_fall_lights() -> void :
	_fall_mm.visible_instance_count = _fall_pts.size()
	for k in _fall_pts.size():
		var q: Vector3 = _fall_pts[k]
		var bob: = sin(_t * 1.3 + k * 1.7) * 0.12
		var s: = 0.85 + 0.25 * sin(_t * 2.3 + k)
		_fall_mm.set_instance_transform(k, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), q + Vector3(0, bob, 0)))
		_fall_mm.set_instance_color(k, Color(2.4, 1.3, 0.45))

func rise_falls(center: Vector3) -> int:

	var n: int = maxi(Game.stats_falls, _fall_pts.size())
	var count: = mini(n, 120)
	if count <= 0:
		return 0
	var mat: = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(2.4, 1.7, 0.8)
	var sm: = SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	sm.radial_segments = 8
	sm.rings = 4
	for k in count:
		var mi: = MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = mat
		add_child(mi)
		var a: = randf() * TAU
		var r: = randf_range(2.5, 16.0)
		var start: = center + Vector3(cos(a) * r, randf_range(-28.0, -6.0), sin(a) * r)
		mi.global_position = start
		mi.scale = Vector3.ONE * 0.01
		var tw: = create_tween()
		tw.tween_interval(k * 0.05)
		tw.tween_property(mi, "scale", Vector3.ONE * randf_range(0.7, 1.3), 0.6)
		tw.tween_property(mi, "global_position", start + Vector3(randf_range(-3, 3), randf_range(40.0, 70.0), randf_range(-3, 3)), randf_range(8.0, 12.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)
	Sfx.play("light_rise", -2.0)
	_fall_pts.clear()
	_fall_mm.visible_instance_count = 0
	return n


func _build_star_name() -> void :
	var f: = FileAccess.open("res://data/stars_salim.json", FileAccess.READ)
	if f == null:
		return
	var pts = JSON.parse_string(f.get_as_text())
	if typeof(pts) != TYPE_ARRAY:
		return
	var zs: Array = level.zones
	var z6: Dictionary = zs[zs.size() - 1]
	var fin: Vector3 = level.finish_pos

	var c: = Vector3.ZERO
	var nc: = 0
	for n in level.nodes:
		if int(n.z) == int(z6.id):
			c += _v(n.p)
			nc += 1
	c /= maxf(nc, 1)
	var out: = Vector3(fin.x - c.x, 0, fin.z - c.z)
	out = out.normalized() if out.length() > 1.0 else Vector3(0, 0, -1)
	var center: = fin + out * 420.0 + Vector3(0, 170.0, 0)
	var right: = Vector3.UP.cross( - out).normalized()
	var width: = 300.0
	var mm: = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var qm: = QuadMesh.new()
	qm.size = Vector2(1, 1)
	mm.mesh = qm
	mm.instance_count = pts.size()
	for k in pts.size():
		var q: Array = pts[k]
		var pos: = center + right * float(q[0]) * width + Vector3.UP * float(q[1]) * width
		var s: = 3.2 + float(q[2]) * 3.0
		mm.set_instance_transform(k, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), pos))
		mm.set_instance_color(k, Color(1.0, 0.95, 0.85, float(q[2])))
	_stars_mat = StandardMaterial3D.new()
	_stars_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_stars_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_stars_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_stars_mat.vertex_color_use_as_albedo = true
	_stars_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_stars_mat.billboard_keep_scale = true
	_stars_mat.albedo_texture = load("res://assets/particle.png")
	_stars_mat.albedo_color = Color(1, 1, 1, 0)
	_stars_mat.disable_fog = true
	_stars = MultiMeshInstance3D.new()
	_stars.multimesh = mm
	_stars.material_override = _stars_mat
	_stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stars.extra_cull_margin = 2000.0
	add_child(_stars)
	_stars.set_meta("y0", float(z6.y0))

func _update_stars(pp: Vector3) -> void :
	if _stars == null:
		return
	var y0: float = _stars.get_meta("y0")
	var k: = clampf((pp.y - (y0 - 40.0)) / 90.0, 0.0, 1.0)
	var tw: = 0.85 + 0.15 * sin(_t * 1.7)
	_stars_mat.albedo_color = Color(1.4, 1.3, 1.1, k * tw)
	_stars.visible = k > 0.001
	if k > 0.6 and not _stars_seen:
		_stars_seen = true
		Sfx.play("stars_chime", -4.0)
		if ui:
			ui.say("", "…النجوم كاتبة اسمه.", 4.0)

func _add_tips() -> void :

	var ns: Array = level.nodes
	var t: = Game.touch
	var add: = func(i: int, text: String):
		if i < ns.size():
			main._tips.append([_v(ns[i].p), text, false])
	add.call(level.node_idx(171), "بسكليت جدّك والراديو ع الصندوق… قرّب منهم." + ("  (العصا لقدّام أسرع • زر القفز الجرس)" if t else "  (W أسرع • Space الجرس)"))
	if not letters.is_empty():
		main._tips.append([(letters[0].pos as Vector3), "حمامة! معها رسالة… قرّب منها.", false])
	if not benches.is_empty():
		main._tips.append([(benches[0].front as Vector3), "وقّف جنب المقعد شوي… وارتاح.", false])
	add.call(level.node_idx(545), "اقعد على المرجيحة… وهي بتعلّيك.")

	var ch_tips: = {
		1: "أعمدة الكهربا عتيقة وبتنزل تحتك… امشِ بهدوء ولا توقف بالنص.", 
		2: "الصحون على عواميد رفيعة… كل قفزة لازم تكون محسوبة.", 
		3: "خشب السقالة بيوقع بعد ثانية… كمّل ولا توقف.", 
		4: "الغيمات الصغيرة بتذوب تحت إجريك… اقفز وانت ماشي.", 
		5: "الجسر مقطوع ونص خشبه راح… والغصن بيهتز.", 
		6: "سكة الضو ضيقة والصخر بيتشقق… الجاذبية خفيفة، خذ وقتك بالقفزة.", 
	}
	var seen: = {}
	for i in ns.size():
		var c: = int(ns[i].get("ch", 0))
		if c > 0 and not seen.has(c):
			seen[c] = true
			main._tips.append([_v(ns[maxi(i - 1, 0)].p), ch_tips.get(c, ""), false])
	add.call(level.node_idx(518), "امسك الطيّارة… الريح بتطلّعك لفوق.")


func update(delta: float) -> void :
	if not ready_built:
		return
	_t += delta
	var pl: = _player()
	if pl == null:
		return
	var pp: Vector3 = pl.global_position
	if pl.is_on_floor() and pl.state == pl.State.NORMAL:
		_last_ground = pp
	if main.mode == main.Mode.PLAYING:
		_update_letters(delta, pp)
		_update_benches(delta, pl)
		_update_musaharati(delta, pp)
	_update_laundry(pp)
	_update_windows()
	_update_fall_lights()
	_update_stars(pp)

func reset_run() -> void :
	for L in letters:
		L.taken = Game.story.get("L%d" % L.id, false)
		(L.root as Node3D).visible = not L.taken
		(L.pigeon as Node3D).position = Vector3(0, 0.95, 0)
	_musah_talked = false
	_bench_said.clear()
	_stars_seen = false
	_fall_pts.clear()
	for q in Game.fall_marks:
		_fall_pts.append(Vector3(float(q[0]), float(q[1]), float(q[2])))
