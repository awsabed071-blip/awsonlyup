extends Node3D









var level
var main
var _flies: GPUParticles3D
var _flocks: Array = []
var _falls: Array[MeshInstance3D] = []
var _star: MeshInstance3D
var _star_mat: StandardMaterial3D
var _star_t: = 3.0
var _star_from: = Vector3.ZERO
var _star_to: = Vector3.ZERO
var _star_life: = 0.0
var _city: Node3D
var _dome_mat: StandardMaterial3D
var _t: = 0.0
var _center: = Vector3.ZERO

func setup(main_ref) -> void :
	main = main_ref
	level = main.level
	for n in level.nodes:
		_center += Vector3(float(n.p[0]), 0, float(n.p[2]))
	_center /= maxf(level.nodes.size(), 1)
	_build_lanterns()
	_build_fireflies()
	_build_birds()
	_build_waterfalls()
	_build_shooting_star()
	_build_house_lights()
	_build_city()

func _zone_y(i: int) -> float:
	var zs: Array = level.zones
	return float(zs[clampi(i, 0, zs.size() - 1)].y0)


func _lantern_tex() -> Texture2D:
	if main.story and main.story.has_method("_lantern_sprite"):
		return main.story._lantern_sprite()
	return load("res://assets/particle.png")

const LAN_CELL: = 45.0
var _lan_mm: MultiMesh
var _lan_mmi: MultiMeshInstance3D
var _lan_k: = 0.0

func _build_lanterns() -> void :


	_lan_mm = MultiMesh.new()
	_lan_mm.transform_format = MultiMesh.TRANSFORM_3D
	_lan_mm.use_colors = true
	var qm: = QuadMesh.new()
	qm.size = Vector2(1.0, 1.32)
	_lan_mm.mesh = qm
	_lan_mm.instance_count = 5 * 5 * 3 * 2
	var mat: = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _lantern_tex()
	_lan_mmi = MultiMeshInstance3D.new()
	_lan_mmi.multimesh = _lan_mm
	_lan_mmi.material_override = mat
	_lan_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lan_mmi.extra_cull_margin = 300.0
	_lan_mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_lan_mmi)

func _h3(x: int, y: int, z: int, s: int) -> float:
	var v: = sin(float(x) * 127.1 + float(y) * 311.7 + float(z) * 74.7 + float(s) * 19.19) * 43758.5453
	return v - floor(v)

func _update_lanterns(delta: float, cam: Vector3, on: bool) -> void :
	_lan_k = move_toward(_lan_k, 1.0 if on else 0.0, delta * 0.3)
	_lan_mmi.visible = _lan_k > 0.01
	if not _lan_mmi.visible:
		return
	var cx: = int(floor(cam.x / LAN_CELL))
	var cy: = int(floor(cam.y / LAN_CELL))
	var cz: = int(floor(cam.z / LAN_CELL))
	var idx: = 0
	for i in range(-2, 3):
		for j in range(-2, 3):
			for kk in range(-2, 4):
				var k: = kk >> 1 if kk >= 0 else -1
				var sd: = (kk + 2) % 2
				var gx: = cx + i
				var gy: = cy + k
				var gz: = cz + j
				var r1: = _h3(gx, gy, gz, 1 + sd * 7)
				var r2: = _h3(gx, gy, gz, 2 + sd * 7)
				var r3: = _h3(gx, gy, gz, 3 + sd * 7)
				var y: = fposmod(_t * (0.9 + r3 * 1.3) + r3 * 97.0, LAN_CELL)
				var p: = Vector3((gx + r1) * LAN_CELL + sin(_t * 0.07 + r3 * 6.0) * 4.0, gy * LAN_CELL + y, (gz + r2) * LAN_CELL + cos(_t * 0.05 + r1 * 6.0) * 4.0)
				var d: = p.distance_to(cam)

				var a: = smoothstep(0.0, 8.0, y) * (1.0 - smoothstep(LAN_CELL - 10.0, LAN_CELL, y)) * (1.0 - smoothstep(80.0, 110.0, d)) * _lan_k
				if d < 6.0:
					a *= d / 6.0
				var s: = 2.0 + r2 * 1.4
				_lan_mm.set_instance_transform(idx, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), p))
				_lan_mm.set_instance_color(idx, Color(2.0, 1.45, 1.0, a))
				idx += 1


func _build_fireflies() -> void :
	_flies = GPUParticles3D.new()
	_flies.amount = 40 if Game.mobile else 90
	_flies.lifetime = 7.0
	_flies.preprocess = 4.0
	_flies.local_coords = false
	_flies.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
	var pm: = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(26, 7, 26)
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.6
	pm.turbulence_noise_scale = 3.0
	pm.turbulence_influence_min = 0.2
	pm.turbulence_influence_max = 0.4
	var ramp: = Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	for k in 6:
		ramp.add_point(0.1 + k * 0.15, Color(1, 1, 1, 1.0 if k % 2 == 0 else 0.15))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	var gt: = GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	_flies.process_material = pm
	var qm: = QuadMesh.new()
	qm.size = Vector2(0.22, 0.22)
	var mat: = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = load("res://assets/particle.png")
	mat.albedo_color = Color(1.5, 2.1, 0.45)
	qm.material = mat
	_flies.draw_pass_1 = qm
	_flies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flies)


func _bird_mesh() -> ArrayMesh:

	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris: = [
		[Vector3(0, 0, 0.35), Vector3(-0.08, 0, -0.3), Vector3(0.08, 0, -0.3), 0.0], 
		[Vector3(0, 0, 0.12), Vector3(-0.85, 0, -0.1), Vector3(0, 0, -0.18), 1.0], 
		[Vector3(0, 0, 0.12), Vector3(0, 0, -0.18), Vector3(0.85, 0, -0.1), 1.0], 
	]
	for t in tris:
		for k in 3:
			var v: Vector3 = t[k]
			var w: float = t[3] * clampf(absf(v.x) / 0.85, 0.0, 1.0)
			st.set_color(Color(w, 0, 0))
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
		for k in [2, 1, 0]:
			var v2: Vector3 = t[k]
			var w2: float = t[3] * clampf(absf(v2.x) / 0.85, 0.0, 1.0)
			st.set_color(Color(w2, 0, 0))
			st.set_normal(Vector3.DOWN)
			st.add_vertex(v2)
	return st.commit()

func _build_birds() -> void :
	var sh: = Shader.new()
	sh.code = "\nshader_type spatial;\nrender_mode unshaded, cull_disabled;\nuniform vec3 tint : source_color = vec3(0.08, 0.07, 0.09);\nvoid vertex() {\n\tfloat ph = float(INSTANCE_ID) * 1.7;\n\tVERTEX.y += COLOR.r * sin(TIME * 9.0 + ph) * 0.55;\n}\nvoid fragment() {\n\tALBEDO = tint;\n}\n"











	var mat: = ShaderMaterial.new()
	mat.shader = sh
	var mesh: = _bird_mesh()
	var rng: = RandomNumberGenerator.new()
	rng.seed = 77
	var nflock: = 3 if Game.mobile else 5
	for f in nflock:
		var mm: = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		var n: = rng.randi_range(7, 11)
		mm.instance_count = n
		var mmi: = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.extra_cull_margin = 400.0
		mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(mmi)
		var offs: = []
		for i in n:

			var row: = (i + 1) / 2
			var side: = -1.0 if i % 2 == 1 else 1.0
			offs.append(Vector3(side * row * 1.4 + rng.randf_range(-0.3, 0.3), rng.randf_range(-0.4, 0.4), - row * 1.6))
		_flocks.append({"mmi": mmi, "radius": rng.randf_range(70.0, 190.0), "h": rng.randf_range(25.0, 190.0), 
			"speed": rng.randf_range(0.05, 0.1) * (1.0 if f % 2 == 0 else -1.0), "phase": rng.randf() * TAU, "offs": offs, 
			"scale": rng.randf_range(1.3, 2.0)})

func _update_birds(delta: float, cam: Vector3) -> void :
	var dusk: = clampf(1.0 - (cam.y - _zone_y(2)) / 120.0, 0.0, 1.0)
	for fl in _flocks:
		var mmi: MultiMeshInstance3D = fl.mmi
		mmi.visible = dusk > 0.02
		if not mmi.visible:
			continue
		var a: float = fl.phase + _t * float(fl.speed)
		var c: = _center + Vector3(cos(a) * float(fl.radius), float(fl.h) + sin(_t * 0.3 + float(fl.phase)) * 8.0, sin(a) * float(fl.radius))
		var fwd: = Vector3( - sin(a), 0, cos(a)) * signf(float(fl.speed))
		var b: = Basis.looking_at( - fwd).scaled(Vector3.ONE * float(fl.scale))
		var offs: Array = fl.offs
		for i in offs.size():
			var o: Vector3 = offs[i]
			mmi.multimesh.set_instance_transform(i, Transform3D(b, c + b * o))


func _build_waterfalls() -> void :
	var sh: = Shader.new()
	sh.code = "\nshader_type spatial;\nrender_mode unshaded, cull_disabled, depth_draw_never, blend_mix;\nuniform vec3 col : source_color = vec3(0.78, 0.88, 1.0);\nfloat h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }\nfloat n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);\n\treturn mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }\nvoid fragment() {\n\tvec2 uv = UV;\n\tfloat streak = n(vec2(uv.x * 14.0, uv.y * 3.0 - TIME * 2.4)) * 0.6 + n(vec2(uv.x * 30.0, uv.y * 7.0 - TIME * 3.3)) * 0.4;\n\tfloat widen = mix(0.28, 0.02, uv.y);\n\tfloat edge = smoothstep(0.0, widen, uv.x) * smoothstep(1.0, 1.0 - widen, uv.x);\n\tfloat fade = smoothstep(1.0, 0.35, uv.y) * smoothstep(0.0, 0.03, uv.y);\n\tALBEDO = col * (0.75 + streak * 0.6);\n\tALPHA = clamp((0.35 + streak * 0.55) * edge * fade, 0.0, 1.0);\n}\n"
















	var mat: = ShaderMaterial.new()
	mat.shader = sh
	var isles: = []
	var ylo: = _zone_y(4) - 20.0
	var yhi: = _zone_y(5) - 10.0
	for p in level.route.pieces:
		if p.t in ["isle_big", "island"] and p.has("rad") and float(p.rad) >= 3.0 and float(p.p[1]) > ylo and float(p.p[1]) < yhi:
			isles.append(p)
	isles.sort_custom( func(a, b): return float(a.rad) > float(b.rad))
	var maxn: = 5 if Game.mobile else 10
	var rng: = RandomNumberGenerator.new()
	rng.seed = 9
	for p in isles.slice(0, maxn):
		var pos: = Vector3(float(p.p[0]), float(p.p[1]), float(p.p[2]))
		var rad: = float(p.rad)
		var a: = rng.randf() * TAU
		var dir: = Vector3(cos(a), 0, sin(a))
		var w: = clampf(rad * 0.5, 3.0, 9.0)
		var h: = 26.0 + rad * 2.5
		var mi: = MeshInstance3D.new()
		var qm: = QuadMesh.new()
		qm.size = Vector2(w, h)
		mi.mesh = qm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var at: = pos + dir * rad * 1.02 + Vector3(0, -0.4 - h * 0.5, 0)
		mi.global_transform = Transform3D(Basis.looking_at(dir), at)
		if Game.mobile:
			mi.visibility_range_end = 700.0
		_falls.append(mi)


func _build_shooting_star() -> void :
	_star = MeshInstance3D.new()
	var qm: = QuadMesh.new()
	qm.size = Vector2(1, 1)
	_star.mesh = qm
	_star_mat = StandardMaterial3D.new()
	_star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_star_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_star_mat.disable_fog = true
	var g: = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1.6, 1.5, 1.2, 1))
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.5)
	gt.fill_to = Vector2(1, 0.5)
	_star_mat.albedo_texture = gt
	_star.material_override = _star_mat
	_star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_star.visible = false
	add_child(_star)

func _update_star(delta: float, cam: Vector3, camb: Basis) -> void :
	var night: = clampf((cam.y - (_zone_y(3) - 30.0)) / 60.0, 0.0, 1.0)
	if _star_life > 0.0:
		_star_life -= delta
		var k: = 1.0 - _star_life / 0.9
		var head: = _star_from.lerp(_star_to, k)
		var tail: = _star_from.lerp(_star_to, maxf(k - 0.3, 0.0))
		var mid: = (head + tail) * 0.5
		var along: = (head - tail)
		var to_cam: = (cam - mid).normalized()
		var x: = along.normalized() if along.length() > 0.01 else Vector3.RIGHT
		var y: = to_cam.cross(x).normalized() * 1.4
		_star.global_transform = Transform3D(Basis(x * along.length(), y, to_cam), mid)
		_star_mat.albedo_color = Color(1, 1, 1, sin(k * PI))
		if _star_life <= 0.0:
			_star.visible = false
		return
	_star_t -= delta
	if _star_t <= 0.0:
		_star_t = randf_range(5.0, 11.0)
		if night < 0.3:
			return

		var f: = - camb.z
		f.y = 0
		f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
		var side: = Vector3.UP.cross(f)
		var base: = cam + f * 700.0 + side * randf_range(-500.0, 500.0) + Vector3(0, randf_range(250.0, 450.0), 0)
		var dir: = (side * randf_range(-1.0, 1.0) + Vector3(0, -0.45, 0)).normalized()
		_star_from = base
		_star_to = base + dir * randf_range(180.0, 300.0)
		_star_life = 0.9
		_star.visible = true


func _build_house_lights() -> void :
	var houses: = []
	for p in level.route.pieces:
		if p.t == "house" and p.get("float", false):
			var d: Array = p.d
			houses.append(Vector3(float(p.p[0]), float(p.p[1]) + float(d[1]) * 0.5 + 0.4, float(p.p[2])))
	if houses.size() < 2:
		return
	var cols: = [Color(2.2, 1.5, 0.5), Color(0.6, 2.0, 0.8), Color(2.2, 0.6, 0.6), Color(0.7, 1.2, 2.4), Color(2.2, 2.0, 1.4)]
	var bulbs: = []
	var used: = {}
	for i in houses.size():
		var best: = -1
		var bd: = 1000000000.0
		for j in houses.size():
			if j == i or used.has(Vector2i(mini(i, j), maxi(i, j))):
				continue
			var dd: float = houses[i].distance_to(houses[j])
			if dd > 12.0 and dd < 42.0 and dd < bd:
				bd = dd
				best = j
		if best < 0:
			continue
		used[Vector2i(mini(i, best), maxi(i, best))] = true
		var a: Vector3 = houses[i]
		var b: Vector3 = houses[best]
		var cnt: = int(bd / 1.1)
		for k in range(1, cnt):
			var u: = float(k) / cnt
			bulbs.append([a.lerp(b, u) + Vector3(0, - bd * 0.09 * 4.0 * u * (1.0 - u), 0), cols[(i + k) % cols.size()]])
		if bulbs.size() > (700 if Game.mobile else 1600):
			break
	var mm: = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sp: = SphereMesh.new()
	sp.radius = 0.11
	sp.height = 0.22
	sp.radial_segments = 6
	sp.rings = 3
	mm.mesh = sp
	mm.instance_count = bulbs.size()
	for i in bulbs.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, bulbs[i][0]))
		mm.set_instance_color(i, bulbs[i][1])
	var mat: = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	var mmi: = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _build_city() -> void :
	_city = Node3D.new()
	add_child(_city)

	var az: = deg_to_rad(95.0)
	var dir: = Vector3(sin(az), 0, cos(az))
	var side: = Vector3.UP.cross(dir)
	var at: = _center + dir * 1250.0
	_city.position = Vector3(at.x, 0, at.z)
	_city.rotation.y = atan2( - dir.x, - dir.z)
	var stone: Material = level.mat("limestone")
	var hillm: Material = level.mat("ground")

	var hill: = MeshInstance3D.new()
	var sm: = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 24
	sm.rings = 12
	hill.mesh = sm
	hill.scale = Vector3(420, 70, 260)
	hill.material_override = hillm
	_city.add_child(hill)
	var rng: = RandomNumberGenerator.new()
	rng.seed = 1948

	var houses: = Node3D.new()
	_city.add_child(houses)
	for i in 160:
		var x: = rng.randf_range(-330.0, 330.0)
		var z: = rng.randf_range(-170.0, 170.0)
		var hy: = 70.0 * sqrt(maxf(0.0, 1.0 - (x / 420.0) * (x / 420.0) - (z / 260.0) * (z / 260.0)))
		var w: = rng.randf_range(12.0, 26.0)
		var hh: = rng.randf_range(10.0, 22.0)
		var mi: = MeshInstance3D.new()
		var bm: = BoxMesh.new()
		bm.size = Vector3(w, hh, rng.randf_range(12.0, 24.0))
		mi.mesh = bm
		mi.position = Vector3(x, hy + hh * 0.3, z)
		mi.rotation.y = rng.randf_range(-0.2, 0.2)
		mi.material_override = stone
		houses.add_child(mi)
		if rng.randf() < 0.35:
			var dm: = MeshInstance3D.new()
			var ds: = SphereMesh.new()
			ds.radius = w * 0.3
			ds.height = w * 0.3
			ds.is_hemisphere = true
			dm.mesh = ds
			dm.position = mi.position + Vector3(0, hh * 0.5, 0)
			dm.material_override = stone
			houses.add_child(dm)
	level._merge_meshes(houses)

	var green: = StandardMaterial3D.new()
	green.albedo_color = Color(0.4, 1.0, 0.55)
	green.emission_enabled = true
	green.emission = Color(0.35, 1.0, 0.5)
	green.emission_energy_multiplier = 3.0
	for i in 6:
		var x: = -260.0 + i * 104.0 + rng.randf_range(-20.0, 20.0)
		var z: = rng.randf_range(-60.0, 40.0)
		var hy: = 70.0 * sqrt(maxf(0.0, 1.0 - (x / 420.0) * (x / 420.0) - (z / 260.0) * (z / 260.0)))
		var h: = rng.randf_range(80.0, 120.0)
		var m: = MeshInstance3D.new()
		var cm: = CylinderMesh.new()
		cm.top_radius = 4.0
		cm.bottom_radius = 5.5
		cm.height = h
		cm.radial_segments = 10
		m.mesh = cm
		m.position = Vector3(x, hy + h * 0.5, z)
		m.material_override = stone
		_city.add_child(m)
		var ring: = MeshInstance3D.new()
		var tm: = TorusMesh.new()
		tm.inner_radius = 5.2
		tm.outer_radius = 6.4
		tm.rings = 16
		tm.ring_segments = 4
		ring.mesh = tm
		ring.position = Vector3(x, hy + h * 0.82, z)
		ring.material_override = green
		_city.add_child(ring)
		var cap: = MeshInstance3D.new()
		var cc: = CylinderMesh.new()
		cc.top_radius = 0.0
		cc.bottom_radius = 4.5
		cc.height = 12.0
		cc.radial_segments = 10
		cap.mesh = cc
		cap.position = Vector3(x, hy + h + 6.0, z)
		cap.material_override = green
		_city.add_child(cap)

	var tiles: = StandardMaterial3D.new()
	tiles.albedo_color = Color(0.2, 0.42, 0.72)
	tiles.roughness = 0.5
	var oct: = MeshInstance3D.new()
	var om: = CylinderMesh.new()
	om.top_radius = 46.0
	om.bottom_radius = 46.0
	om.height = 34.0
	om.radial_segments = 8
	oct.mesh = om
	oct.position = Vector3(0, 70.0 + 17.0, 0)
	oct.rotation.y = PI / 8.0
	oct.material_override = tiles
	_city.add_child(oct)
	var drum: = MeshInstance3D.new()
	var dmm: = CylinderMesh.new()
	dmm.top_radius = 26.0
	dmm.bottom_radius = 26.0
	dmm.height = 16.0
	dmm.radial_segments = 16
	drum.mesh = dmm
	drum.position = Vector3(0, 70.0 + 34.0 + 8.0, 0)
	drum.material_override = tiles
	_city.add_child(drum)
	_dome_mat = StandardMaterial3D.new()
	_dome_mat.albedo_color = Color(1.0, 0.78, 0.3)
	_dome_mat.metallic = 0.9
	_dome_mat.roughness = 0.25
	_dome_mat.emission_enabled = true
	_dome_mat.emission = Color(1.0, 0.7, 0.3)
	_dome_mat.emission_energy_multiplier = 0.3
	var dome: = MeshInstance3D.new()
	var dsm: = SphereMesh.new()
	dsm.radius = 27.0
	dsm.height = 60.0
	dsm.is_hemisphere = true
	dsm.radial_segments = 24
	dsm.rings = 10
	dome.mesh = dsm
	dome.position = Vector3(0, 70.0 + 50.0, 0)
	dome.material_override = _dome_mat
	_city.add_child(dome)
	var spire: = MeshInstance3D.new()
	var spm: = CylinderMesh.new()
	spm.top_radius = 0.5
	spm.bottom_radius = 1.2
	spm.height = 14.0
	spire.mesh = spm
	spire.position = Vector3(0, 70.0 + 50.0 + 34.0, 0)
	spire.material_override = _dome_mat
	_city.add_child(spire)
	for gi in _city.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(gi as GeometryInstance3D).extra_cull_margin = 100.0


func update(delta: float, cam: Vector3, camb: Basis) -> void :
	_t += delta
	var night: = 1.0
	if main.envm and main.envm._cur_look.has("win"):
		night = float(main.envm._cur_look.win)

	var in_night: = cam.y > _zone_y(1) - 20.0 and cam.y < _zone_y(5) + 60.0
	_update_lanterns(delta, cam, in_night and night > 0.5)

	_flies.global_position = cam + Vector3(0, -2.0, 0)
	var low: = cam.y < _zone_y(2) + 20.0
	_flies.emitting = low
	_flies.visible = low or _flies.emitting
	_update_birds(delta, cam)
	_update_star(delta, cam, camb)
	for f in _falls:
		f.visible = absf(f.global_position.y - cam.y) < 420.0

	var dawn: = clampf((cam.y - _zone_y(5)) / maxf(float(level.nodes[-1].p[1]) - _zone_y(5), 1.0), 0.0, 1.0)
	_dome_mat.emission_energy_multiplier = 0.3 + 2.2 * dawn * dawn
