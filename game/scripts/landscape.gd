extends Node3D





const FLAT_R: = 320.0
const SIZE: = 9000.0

var level
var center: = Vector3.ZERO
var city_at: = Vector3.ZERO
var _hn: FastNoiseLite
var _rn: FastNoiseLite
var _tn: FastNoiseLite
var _grid: = {}

func build(level_ref) -> void :
	level = level_ref
	for n in level.nodes:
		center += Vector3(float(n.p[0]), 0, float(n.p[2]))
	center /= maxf(level.nodes.size(), 1)
	var az: = deg_to_rad(95.0)
	city_at = center + Vector3(sin(az), 0, cos(az)) * 1250.0
	_hn = FastNoiseLite.new()
	_hn.seed = 1917
	_hn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hn.frequency = 1.0 / 1500.0
	_hn.fractal_type = FastNoiseLite.FRACTAL_FBM
	_hn.fractal_octaves = 5
	_rn = FastNoiseLite.new()
	_rn.seed = 48
	_rn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_rn.frequency = 1.0 / 700.0
	_rn.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_rn.fractal_octaves = 4
	_tn = FastNoiseLite.new()
	_tn.seed = 67
	_tn.frequency = 1.0 / 260.0
	var rng: = RandomNumberGenerator.new()
	rng.seed = 1936
	_build_terrain()
	_build_trees(rng)
	_build_villages(rng)


func height(x: float, z: float) -> float:
	var d: = Vector2(x - center.x, z - center.z).length()
	var rise: = smoothstep(FLAT_R, FLAT_R + 520.0, d)
	if rise <= 0.0:
		return 0.0
	var b: = (_hn.get_noise_2d(x, z) + 1.0) * 0.5
	var r: = (_rn.get_noise_2d(x, z) + 1.0) * 0.5
	var h: = rise * (25.0 + 170.0 * pow(b, 1.6) + 70.0 * r * r)

	h += smoothstep(1900.0, 3600.0, d) * (160.0 + 220.0 * b)

	var dc: = Vector2(x - city_at.x, z - city_at.z).length()
	var to_city: = Vector2(city_at.x - center.x, city_at.z - center.z).normalized()
	var along: = Vector2(x - center.x, z - center.z).dot(to_city)
	var across: = absf(Vector2(x - center.x, z - center.z).cross(to_city))
	var corridor: = (1.0 - smoothstep(260.0, 520.0, across)) * (1.0 - smoothstep(1500.0, 1900.0, along)) * smoothstep(0.0, 200.0, along)
	var cap: = lerpf(h, minf(h, 8.0 + across * 0.02), maxf(corridor, 1.0 - smoothstep(480.0, 760.0, dc)))
	return cap


func _terraced(x: float, z: float, h: float) -> Vector2:
	if h < 2.0:
		return Vector2(h, 0.0)
	var region: = smoothstep(0.1, 0.35, _tn.get_noise_2d(x, z))
	if region <= 0.0:
		return Vector2(h, 0.0)
	var step: = 3.5
	var t: = h / step
	var f: = t - floorf(t)
	var stepped: = (floorf(t) + smoothstep(0.7, 0.95, f)) * step
	var wall: = smoothstep(0.7, 0.8, f) * (1.0 - smoothstep(0.92, 0.97, f))
	return Vector2(lerpf(h, stepped, region), wall * region)


func _build_terrain() -> void :
	var res: = 170 if Game.mobile else 280
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: = SIZE * 0.5
	var cell: = SIZE / float(res)
	var hs: = PackedFloat32Array()
	var ws: = PackedFloat32Array()
	hs.resize((res + 1) * (res + 1))
	ws.resize((res + 1) * (res + 1))
	for j in res + 1:
		for i in res + 1:
			var x: = center.x - half + i * cell
			var z: = center.z - half + j * cell
			var tv: = _terraced(x, z, height(x, z))
			hs[j * (res + 1) + i] = tv.x
			ws[j * (res + 1) + i] = tv.y
	for j in res + 1:
		for i in res + 1:
			var k: = j * (res + 1) + i
			st.set_color(Color(ws[k], 0, 0))
			st.set_uv(Vector2(i, j) / res)
			st.add_vertex(Vector3(center.x - half + i * cell, hs[k] - 0.05, center.z - half + j * cell))
	for j in res:
		for i in res:
			var a: = j * (res + 1) + i
			var b: = a + 1
			var c: = a + res + 1
			var d: = c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	var mesh: = st.commit()
	var mi: = MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	var m: = ShaderMaterial.new()
	m.shader = load("res://shaders/terrain.gdshader")
	var tx: = Surf.textures()
	m.set_shader_parameter("surf_a", tx[0])
	m.set_shader_parameter("surf_n", tx[1])
	m.set_shader_parameter("lite", 1.0 if Game.mobile else 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	var nrm: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	if nrm.size() > 0 and nrm[nrm.size() / 2].y < 0.0:
		st = SurfaceTool.new()
		st.create_from(mesh, 0)
		var arr: = mesh.surface_get_arrays(0)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for q in range(0, idx.size(), 3):
			var t: = idx[q + 1]
			idx[q + 1] = idx[q + 2]
			idx[q + 2] = t
		arr[Mesh.ARRAY_INDEX] = idx
		var fixed: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for q in fixed.size():
			fixed[q] = - fixed[q]
		arr[Mesh.ARRAY_NORMAL] = fixed
		var am: = ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mi.mesh = am

func ground_y(x: float, z: float) -> float:
	return _terraced(x, z, height(x, z)).x


func _blob(st: SurfaceTool, c: Vector3, r: Vector3, seg: int, rings: int, col: Color, rng: RandomNumberGenerator) -> void :
	var noise: = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 1.6
	var verts: = []
	for ri in rings + 1:
		var v: = float(ri) / rings
		var phi: = v * PI
		for si in seg + 1:
			var u: = float(si) / seg
			var th: = u * TAU
			var d: = Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var k: = 1.0 + noise.get_noise_3dv(d * 1.3) * 0.45
			verts.append(c + d * r * k)
	for ri in rings:
		for si in seg:
			var a: Vector3 = verts[ri * (seg + 1) + si]
			var b: Vector3 = verts[ri * (seg + 1) + si + 1]
			var cc: Vector3 = verts[(ri + 1) * (seg + 1) + si]
			var dd: Vector3 = verts[(ri + 1) * (seg + 1) + si + 1]
			_tri(st, a, cc, b, c, col)
			_tri(st, b, cc, dd, c, col)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, col: Color) -> void :
	var n: = (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	n = n.normalized()
	var mid: = (a + b + c) / 3.0
	if n.dot(mid - inside) < 0.0:
		var t: = b
		b = c
		c = t
		n = - n

	if Surf._front == 0.0:
		Surf._front = Surf._winding_sign()
	if Surf._front < 0.0:
		var t2: = b
		b = c
		c = t2
	for v in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)

func _trunk(st: SurfaceTool, pts: Array, r0: float, r1: float, seg: int) -> void :
	var bark: = Color(1, 0, 0)
	for k in pts.size() - 1:
		var p0: Vector3 = pts[k]
		var p1: Vector3 = pts[k + 1]
		var ra: = lerpf(r0, r1, float(k) / (pts.size() - 1))
		var rb: = lerpf(r0, r1, float(k + 1) / (pts.size() - 1))
		var ax: = (p1 - p0).normalized()
		var s1: = ax.cross(Vector3.FORWARD if absf(ax.z) < 0.9 else Vector3.RIGHT).normalized()
		var s2: = ax.cross(s1)
		for si in seg:
			var a0: = TAU * si / seg
			var a1: = TAU * (si + 1) / seg
			var d0: = s1 * cos(a0) + s2 * sin(a0)
			var d1: = s1 * cos(a1) + s2 * sin(a1)
			var mid: = (p0 + p1) * 0.5
			_tri(st, p0 + d0 * ra, p1 + d0 * rb, p0 + d1 * ra, mid, bark)
			_tri(st, p0 + d1 * ra, p1 + d0 * rb, p1 + d1 * rb, mid, bark)

func _olive_mesh(lod: int) -> Mesh:
	var rng: = RandomNumberGenerator.new()
	rng.seed = 7
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ts: = 6 if lod == 0 else 4
	_trunk(st, [Vector3(0, 0, 0), Vector3(0.15, 0.7, 0.05), Vector3(-0.05, 1.4, 0.1), Vector3(0.2, 2.0, 0.0)], 0.28, 0.14, ts)
	if lod == 0:
		_trunk(st, [Vector3(-0.05, 1.4, 0.1), Vector3(-0.5, 2.0, -0.2), Vector3(-0.8, 2.4, -0.3)], 0.13, 0.07, 4)
	var leaf: = Color(0, 0, 0)
	var blobs: = [Vector3(0.1, 2.7, 0.0), Vector3(-0.8, 2.6, -0.4), Vector3(0.7, 2.5, 0.4), Vector3(0.0, 3.2, 0.3), Vector3(-0.3, 2.4, 0.8), Vector3(0.5, 3.0, -0.6)]
	for i in (blobs.size() if lod == 0 else 3):
		var c: Vector3 = blobs[i]
		var sc: = rng.randf_range(0.85, 1.25) * (1.0 if lod == 0 else 1.3)
		_blob(st, c, Vector3(1.0, 0.7, 1.0) * sc, 7 if lod == 0 else 5, 4 if lod == 0 else 3, leaf, rng)
	return st.commit()

func _cypress_mesh(lod: int) -> Mesh:
	var rng: = RandomNumberGenerator.new()
	rng.seed = 11
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_trunk(st, [Vector3(0, 0, 0), Vector3(0, 1.2, 0)], 0.18, 0.12, 5 if lod == 0 else 3)
	_blob(st, Vector3(0, 4.2, 0), Vector3(0.9, 4.0, 0.9), 8 if lod == 0 else 5, 7 if lod == 0 else 4, Color(0, 0, 0), rng)
	return st.commit()

func _pine_mesh(lod: int) -> Mesh:
	var rng: = RandomNumberGenerator.new()
	rng.seed = 23
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_trunk(st, [Vector3(0, 0, 0), Vector3(0.3, 2.5, 0.1), Vector3(0.2, 5.0, -0.2), Vector3(0.5, 6.4, 0.0)], 0.3, 0.14, 6 if lod == 0 else 3)
	var blobs: = [Vector3(0.5, 6.8, 0.0), Vector3(-0.9, 6.3, 0.6), Vector3(1.4, 6.2, -0.7), Vector3(0.2, 7.3, 1.0)]
	for i in (blobs.size() if lod == 0 else 2):
		_blob(st, blobs[i], Vector3(1.9, 0.8, 1.9) * rng.randf_range(0.8, 1.2) * (1.0 if lod == 0 else 1.35), 8 if lod == 0 else 5, 4 if lod == 0 else 3, Color(0, 0, 0), rng)
	return st.commit()

func _foliage_mat(leaf: Color, leaf2: Color, bark: Color) -> ShaderMaterial:
	var m: = ShaderMaterial.new()
	m.shader = load("res://shaders/foliage.gdshader")
	var tx: = Surf.textures()
	m.set_shader_parameter("surf_a", tx[0])
	m.set_shader_parameter("surf_n", tx[1])
	m.set_shader_parameter("leaf_col", leaf)
	m.set_shader_parameter("leaf_col2", leaf2)
	m.set_shader_parameter("bark_col", bark)
	m.set_shader_parameter("lite", 1.0 if Game.mobile else 0.0)
	return m


func _free_spot(p: Vector3) -> bool:
	var d: = Vector2(p.x - center.x, p.z - center.z).length()
	if d < 175.0:
		return false
	return Vector2(p.x - city_at.x, p.z - city_at.z).length() > 440.0

func _build_trees(rng: RandomNumberGenerator) -> void :
	var olives: Array = []
	var cypress: Array = []
	var pines: Array = []
	var k: = 0.3 if Game.mobile else 1.0

	var groves: = int(150 * k)
	for g in groves:
		var a: = rng.randf() * TAU
		var d: = rng.randf_range(185.0, 1500.0) if g % 3 else rng.randf_range(185.0, 420.0)
		var gc: = center + Vector3(cos(a) * d, 0, sin(a) * d)
		var rot: = rng.randf() * TAU
		var nx: = rng.randi_range(3, 7)
		var nz: = rng.randi_range(3, 6)
		for ix in nx:
			for iz in nz:
				if rng.randf() < 0.15:
					continue
				var off: = Vector3(ix - nx * 0.5, 0, iz - nz * 0.5) * 8.5
				off = off.rotated(Vector3.UP, rot) + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5))
				var p: = gc + off
				if not _free_spot(p):
					continue
				p.y = ground_y(p.x, p.z)
				olives.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.1, 1.7)), p))
	for i in int(420 * k):
		var a: = rng.randf() * TAU
		var d: = rng.randf_range(185.0, 1800.0)
		var p: = center + Vector3(cos(a) * d, 0, sin(a) * d)
		if not _free_spot(p):
			continue
		p.y = ground_y(p.x, p.z)
		cypress.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1, rng.randf_range(0.8, 1.3), 1) * rng.randf_range(0.8, 1.2)), p))
	for i in int(900 * k):
		var a: = rng.randf() * TAU
		var d: = rng.randf_range(700.0, 2600.0)
		var p: = center + Vector3(cos(a) * d, 0, sin(a) * d)
		if not _free_spot(p):
			continue
		p.y = ground_y(p.x, p.z)
		if p.y < 40.0 and rng.randf() < 0.6:
			continue
		pines.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.6)), p))
	var mo: = _foliage_mat(Color(0.2, 0.25, 0.16), Color(0.3, 0.35, 0.24), Color(0.3, 0.26, 0.22))
	var mc: = _foliage_mat(Color(0.07, 0.12, 0.06), Color(0.11, 0.17, 0.09), Color(0.26, 0.21, 0.18))
	var mp: = _foliage_mat(Color(0.1, 0.17, 0.08), Color(0.15, 0.22, 0.11), Color(0.34, 0.26, 0.21))
	_build_scrub(rng)
	for lod in 2:
		_multimesh("Olives%d" % lod, _olive_mesh(lod), _near_far(olives, lod), mo, rng, lod == 0)
		_multimesh("Cypresses%d" % lod, _cypress_mesh(lod), _near_far(cypress, lod), mc, rng, lod == 0)
		_multimesh("Pines%d" % lod, _pine_mesh(lod), _near_far(pines, lod), mp, rng, lod == 0)




func _blocked_cells() -> Dictionary:
	var cells: = {}
	var pieces: Array = level.route.pieces if ("route" in level and level.route is Dictionary and level.route.has("pieces")) else []
	for p in pieces:
		if not (p is Dictionary) or not p.has("p"):
			continue
		var pos: Array = p.p
		if float(pos[1]) > 30.0:
			continue
		var r: = 6.0
		if p.has("d"):
			r = maxf(float(p.d[0]), float(p.d[2])) * 0.5 + 3.0
		elif p.has("rad"):
			r = float(p.rad) + 3.0
		elif p.has("s"):
			r = float(p.s) * 2.5 + 3.0
		r = minf(r, 60.0)
		var cx: = int(floor(float(pos[0]) / 5.0))
		var cz: = int(floor(float(pos[2]) / 5.0))
		var n: = int(ceil(r / 5.0))
		for ix in range(cx - n, cx + n + 1):
			for iz in range(cz - n, cz + n + 1):
				cells[Vector2i(ix, iz)] = true
	return cells

func _bush_mesh(lod: int) -> Mesh:
	var rng: = RandomNumberGenerator.new()
	rng.seed = 31
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts: = [[Vector3(0, 0.35, 0), Vector3(0.75, 0.5, 0.7)], [Vector3(0.5, 0.3, 0.25), Vector3(0.5, 0.4, 0.5)], [Vector3(-0.45, 0.28, -0.2), Vector3(0.55, 0.38, 0.5)]]
	for i in (parts.size() if lod == 0 else 1):
		_blob(st, parts[i][0], parts[i][1] * (1.0 if lod == 0 else 1.2), 6 if lod == 0 else 5, 4 if lod == 0 else 3, Color(0, 0, 0), rng)
	return st.commit()

func _stone_mesh() -> Mesh:
	var rng: = RandomNumberGenerator.new()
	rng.seed = 57
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_blob(st, Vector3(0, 0.15, 0), Vector3(0.8, 0.5, 0.65), 7, 4, Color(1, 0, 0), rng)
	return st.commit()

func _build_scrub(rng: RandomNumberGenerator) -> void :
	var blocked: = _blocked_cells()
	var patch: = FastNoiseLite.new()
	patch.seed = 77
	patch.frequency = 1.0 / 45.0
	var k: = 0.3 if Game.mobile else 1.0
	var bushes: Array = []
	var stones: Array = []
	var tries: = int(9000 * k)
	for i in tries:
		var a: = rng.randf() * TAU
		var d: = sqrt(rng.randf()) * 470.0 + 12.0
		var p: = center + Vector3(cos(a) * d, 0, sin(a) * d)
		if blocked.has(Vector2i(int(floor(p.x / 5.0)), int(floor(p.z / 5.0)))):
			continue
		if Vector2(p.x - city_at.x, p.z - city_at.z).length() < 440.0:
			continue
		var pn: = patch.get_noise_2d(p.x, p.z)
		var is_stone: = rng.randf() < 0.08
		if not is_stone and pn < -0.05:
			continue
		p.y = ground_y(p.x, p.z) - 0.08
		var sc: = rng.randf_range(0.7, 1.6) * (1.0 + maxf(pn, 0.0) * 0.8)
		var b: = Basis(Vector3.UP, rng.randf() * TAU)
		if is_stone:
			b = b * Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25))
			stones.append(Transform3D(b.scaled(Vector3(1.0, rng.randf_range(0.6, 1.2), 1.0) * rng.randf_range(0.5, 2.2)), p - Vector3(0, 0.1, 0)))
		else:
			bushes.append(Transform3D(b.scaled(Vector3(1.0, rng.randf_range(0.8, 1.3), 1.0) * sc), p))
	var mb: = _foliage_mat(Color(0.16, 0.21, 0.12), Color(0.27, 0.3, 0.18), Color(0.3, 0.26, 0.22))
	mb.set_shader_parameter("sway", 0.25)
	var ms: = _foliage_mat(Color(0.2, 0.25, 0.16), Color(0.3, 0.35, 0.24), Color(0.52, 0.49, 0.43))
	ms.set_shader_parameter("bark_layer", 11.0)
	ms.set_shader_parameter("sway", 0.0)
	for lod in 2:
		var part: = []
		for x in bushes:
			var dd: = Vector2((x as Transform3D).origin.x - center.x, (x as Transform3D).origin.z - center.z).length()
			if (dd < 260.0) == (lod == 0):
				part.append(x)
		_multimesh("Scrub%d" % lod, _bush_mesh(lod), part, mb, rng, lod == 0)
	_multimesh("Stones", _stone_mesh(), stones, ms, rng, true)


func _near_far(xfs: Array, lod: int) -> Array:
	var out: = []
	for x in xfs:
		var d: = Vector2((x as Transform3D).origin.x - center.x, (x as Transform3D).origin.z - center.z).length()
		if (d < 460.0) == (lod == 0):
			out.append(x)
	return out

func _multimesh(nm: String, mesh: Mesh, xfs: Array, mat: Material, rng: RandomNumberGenerator, shadows: = true) -> void :
	if xfs.is_empty():
		return
	var mm: = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_custom_data(i, Color(rng.randf(), 0, 0, 0))
	var mmi: = MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (shadows and not Game.mobile) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _build_villages(rng: RandomNumberGenerator) -> void :
	var stone: Material = level.mat("limestone")
	var tank: Material = level.mat("tank")
	var count: = 5 if Game.mobile else 10
	var made: = 0
	var tries: = 0
	while made < count and tries < 200:
		tries += 1
		var a: = rng.randf() * TAU
		var d: = rng.randf_range(750.0, 2300.0)
		var vc: = center + Vector3(cos(a) * d, 0, sin(a) * d)
		if Vector2(vc.x - city_at.x, vc.z - city_at.z).length() < 700.0:
			continue
		var hy: = ground_y(vc.x, vc.z)
		if hy < 50.0:
			continue
		var houses: = Node3D.new()
		houses.name = "Village%d" % made
		add_child(houses)
		var n: = rng.randi_range(18, 38) if not Game.mobile else rng.randi_range(10, 18)
		for i in n:
			var off: = Vector3(rng.randf_range(-70, 70), 0, rng.randf_range(-70, 70))
			var p: = vc + off
			var gy: = ground_y(p.x, p.z)
			var w: = rng.randf_range(7.0, 13.0)
			var hh: = rng.randf_range(4.0, 9.0)
			var dz: = rng.randf_range(7.0, 12.0)
			var mi: = MeshInstance3D.new()
			mi.mesh = Surf.box(Vector3(w, hh + 3.0, dz))
			mi.position = Vector3(p.x, gy + (hh + 3.0) * 0.5 - 3.0, p.z)
			mi.rotation.y = rng.randf_range(-0.3, 0.3) + (0.0 if i % 2 else PI * 0.5)
			mi.material_override = stone
			houses.add_child(mi)
			if rng.randf() < 0.6:
				var tk: = MeshInstance3D.new()
				var cm: = CylinderMesh.new()
				cm.top_radius = 0.7
				cm.bottom_radius = 0.7
				cm.height = 1.2
				cm.radial_segments = 8
				tk.mesh = cm
				tk.position = mi.position + Vector3(rng.randf_range( - w * 0.3, w * 0.3), (hh + 3.0) * 0.5 + 0.6, rng.randf_range( - dz * 0.3, dz * 0.3))
				tk.material_override = tank
				houses.add_child(tk)
		level._merge_meshes(houses)
		for g in houses.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		made += 1
