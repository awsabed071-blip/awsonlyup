class_name Surf
extends RefCounted





const FAM: = {
	"smooth": [0, 1.0], "concrete": [1, 3.0], "plaster": [2, 2.5], "ashlar": [3, 3.2], "brick": [4, 1.5], 
	"cobble": [5, 2.0], "asphalt": [6, 3.0], "wood": [7, 2.0], "paint_metal": [8, 2.0], "brushed": [9, 1.0], 
	"corrugated": [10, 1.2], "rock": [11, 4.0], "grass": [12, 2.0], "terracotta": [13, 2.0], "fabric": [14, 0.4], 
	"rubber": [15, 0.6], "tread": [16, 0.5], "paving": [17, 2.4], "bark": [18, 1.5], "leaves": [19, 1.0], 
}

# [detail, bump, streaks, wear, mask_color, mask_amount, mask_rough, mask_metal, grime, tint_k]
# tint_k 1.0: the palette colour drives the look (grey library family); 0.3: the library's own colour.
const FDEF: = {
	"smooth": [0.3, 0.5, 0.0, 0.0, Color(0.5, 0.5, 0.5), 0.0, 0.5, 0.0, 0.2, 1.0], 
	"concrete": [0.85, 1.0, 0.6, 0.35, Color(0.3, 0.29, 0.27), 0.5, 0.95, 0.0, 0.7, 0.3], 
	"plaster": [0.75, 1.0, 0.5, 0.25, Color(0.62, 0.58, 0.52), 0.6, 0.95, 0.0, 0.6, 0.3], 
	"ashlar": [0.75, 1.0, 0.35, 0.45, Color(0.5, 0.47, 0.42), 0.9, 0.95, 0.0, 0.7, 0.3], 
	"brick": [0.9, 1.0, 0.3, 0.3, Color(0.64, 0.62, 0.58), 0.9, 0.95, 0.0, 0.6, 0.25], 
	"cobble": [0.9, 1.0, 0.0, 0.2, Color(0.22, 0.19, 0.15), 0.9, 1.0, 0.0, 0.7, 0.3], 
	"asphalt": [0.8, 1.0, 0.0, 0.0, Color(0.1, 0.1, 0.11), 0.7, 0.6, 0.0, 0.6, 0.3], 
	"wood": [1.0, 1.0, 0.25, 0.4, Color(0.4, 0.38, 0.35), 0.8, 1.0, 0.0, 0.7, 0.3], 
	"paint_metal": [0.6, 1.0, 0.3, 0.55, Color(0.32, 0.17, 0.09), 1.0, 0.85, 0.15, 0.4, 1.0], 
	"brushed": [0.7, 1.0, 0.0, 0.3, Color(0.35, 0.22, 0.12), 0.5, 0.8, 0.2, 0.3, 1.0], 
	"corrugated": [0.7, 1.0, 0.3, 0.4, Color(0.33, 0.18, 0.1), 1.0, 0.85, 0.15, 0.5, 1.0], 
	"rock": [1.0, 1.2, 0.0, 0.3, Color(0.5, 0.52, 0.36), 0.7, 0.95, 0.0, 0.8, 0.3], 
	"grass": [0.7, 1.0, 0.0, 0.0, Color(0.42, 0.32, 0.22), 0.8, 1.0, 0.0, 0.35, 0.3], 
	"terracotta": [0.8, 1.0, 0.2, 0.2, Color(0.3, 0.38, 0.2), 0.6, 1.0, 0.0, 0.6, 0.3], 
	"fabric": [0.8, 0.8, 0.0, 0.0, Color(0.5, 0.5, 0.5), 0.0, 1.0, 0.0, 0.5, 1.0], 
	"rubber": [0.5, 0.8, 0.0, 0.0, Color(0.2, 0.2, 0.2), 0.3, 0.7, 0.0, 0.3, 1.0], 
	"tread": [0.45, 1.0, 0.0, 0.3, Color(0.2, 0.2, 0.2), 0.15, 0.8, 0.0, 0.4, 1.0], 
	"paving": [0.85, 1.0, 0.0, 0.3, Color(0.34, 0.31, 0.27), 0.85, 1.0, 0.0, 0.7, 0.3], 
	"bark": [1.0, 1.2, 0.0, 0.0, Color(0.46, 0.5, 0.35), 0.5, 1.0, 0.0, 0.8, 0.3], 
	"leaves": [0.55, 0.8, 0.0, 0.0, Color(0.16, 0.22, 0.12), 0.35, 1.0, 0.0, 0.3, 0.3], 
}

const MAT: = {
	"ground": {"f": "grass"}, "plaza": {"f": "paving"}, "limestone": {"f": "ashlar", "top": "paving"}, "wood": {"f": "wood"}, 
	"tank": {"f": "smooth", "d": 0.5}, "drum": {"f": "paint_metal"}, "concrete": {"f": "concrete"}, 
	"roof": {"f": "plaster", "s": 0.9, "top": "concrete"}, "steel": {"f": "brushed"}, "ibeam": {"f": "paint_metal", "w": 0.7}, 
	"pipe_metal": {"f": "brushed"}, "pipe_orange": {"f": "paint_metal"}, "pole": {"f": "paint_metal"}, 
	"plank_white": {"f": "wood", "d": 0.45, "m": 0.5}, "carpet": {"f": "fabric", "t": 0.5}, 
	"mossy": {"f": "rock", "t": 3.0, "top": "grass"}, "rope_bridge": {"f": "wood", "t": 1.6}, "metal_panel": {"f": "paint_metal", "m": 0.6}, 
	"truss": {"f": "paint_metal", "w": 0.7}, "bounce": {"f": "rubber"}, "fan": {"f": "paint_metal"}, 
	"rock": {"f": "rock"}, "grass": {"f": "grass"}, "asteroid": {"f": "rock", "t": 6.0}, "asteroid_top": {"f": "rock", "t": 5.0}, 
	"moon": {"f": "rock", "t": 8.0, "d": 0.6}, "olive_leaf": {"f": "leaves"}, "olive_trunk": {"f": "bark"}, 
	"window": {"f": "smooth"}, "window_lit0": {"f": "smooth"}, "window_lit1": {"f": "smooth"}, "window_lit2": {"f": "smooth"}, 
	"window_lit3": {"f": "smooth"}, "window_lit4": {"f": "smooth"}, "shutter": {"f": "corrugated", "t": 0.6}, 
	"door": {"f": "wood", "t": 1.2}, "dome": {"f": "plaster", "s": 0.3}, "gold": {"f": "brushed", "m": 0.0}, 
	"rubber": {"f": "rubber"}, "container_red": {"f": "corrugated", "t": 2.4}, "container_blue": {"f": "corrugated", "t": 2.4}, 
	"container_green": {"f": "corrugated", "t": 2.4}, "container_orange": {"f": "corrugated", "t": 2.4}, 
	"rail": {"f": "paint_metal"}, "lamp_glow": {"f": "smooth"}, "planter": {"f": "plaster", "m": 0.2}, 
	"tank_white": {"f": "paint_metal", "m": 0.5}, "tank_band": {"f": "paint_metal"}, "grating": {"f": "tread"}, 
	"train_red": {"f": "paint_metal", "m": 0.5}, "train_cream": {"f": "paint_metal", "m": 0.4}, "glass": {"f": "smooth"}, 
	"wicker": {"f": "fabric", "t": 1.4, "d": 1.0}, "rocket_white": {"f": "paint_metal", "m": 0.25, "s": 0.0}, 
	"rocket_red": {"f": "paint_metal", "m": 0.25, "s": 0.0}, "plaster": {"f": "plaster"}, "floor_wood": {"f": "wood", "t": 1.6}, 
	"flame": {"f": "smooth"}, "engine_glow": {"f": "brushed"}, "cobble": {"f": "cobble"}, "asphalt": {"f": "asphalt"}, 
	"sidewalk": {"f": "paving", "t": 1.8}, "paint_white": {"f": "smooth"}, "paint_yellow": {"f": "smooth"}, 
	"steel_deck": {"f": "tread"}, "stone_bridge": {"f": "ashlar", "top": "paving"}, "clay": {"f": "plaster", "m": 0.0, "d": 1.0}, 
	"bread": {"f": "plaster", "d": 0.8, "m": 0.0}, "bus": {"f": "paint_metal", "m": 0.4}, "chassis": {"f": "paint_metal"}, 
	"gas": {"f": "paint_metal", "m": 0.5}, "gas_grey": {"f": "paint_metal", "m": 0.5}, "porcelain": {"f": "smooth"}, 
	"coffee": {"f": "smooth"}, "iron": {"f": "paint_metal", "m": 1.0, "mc": Color(0.36, 0.2, 0.1)}, "bead": {"f": "smooth"}, 
	"copper": {"f": "brushed", "m": 0.4, "mc": Color(0.3, 0.52, 0.42)}, "neon_blue": {"f": "smooth"}, 
	"crumble_stone": {"f": "rock", "t": 2.5}, 
}

static var _ta: TextureLayered
static var _tn: TextureLayered
static var _box_cache: = {}
static var _front: = 0.0

static func textures() -> Array:
	if _ta == null:
		var res: = "512" if Game.mobile else "1024"
		_ta = load("res://assets/surfaces/surf_a_%s.png" % res)
		_tn = load("res://assets/surfaces/surf_n_%s.png" % res)
	return [_ta, _tn]


static func apply(m: ShaderMaterial, name: String) -> void :
	var o: Dictionary = MAT.get(name, {"f": "concrete"})
	var f: String = o.f
	var fam: Array = FAM[f]
	var fd: Array = FDEF[f]
	var tx: = textures()
	m.set_shader_parameter("surf_a", tx[0])
	m.set_shader_parameter("surf_n", tx[1])
	m.set_shader_parameter("layer", float(fam[0]))
	m.set_shader_parameter("tile", float(o.get("t", fam[1])))
	m.set_shader_parameter("detail", float(o.get("d", fd[0])))
	m.set_shader_parameter("bump", float(fd[1]))
	m.set_shader_parameter("streaks", 0.0 if Game.mobile else float(o.get("s", fd[2])))
	m.set_shader_parameter("wear", float(o.get("w", fd[3])))
	m.set_shader_parameter("mask_color", o.get("mc", fd[4]))
	m.set_shader_parameter("mask_amount", float(o.get("m", fd[5])))
	m.set_shader_parameter("mask_rough", float(fd[6]))
	m.set_shader_parameter("mask_metal", float(fd[7]))
	m.set_shader_parameter("grime", float(fd[8]))
	m.set_shader_parameter("tint_k", float(o.get("k", fd[9])))
	m.set_shader_parameter("lite", 1.0 if Game.mobile else 0.0)
	if o.has("top"):
		m.set_shader_parameter("top_layer", float(FAM[o.top][0]))
		m.set_shader_parameter("top_tile", float(FAM[o.top][1]))
		m.set_shader_parameter("top_tint_k", float(FDEF[o.top][9]))

	if f != "smooth":
		m.set_shader_parameter("stripes", 0.0)
		m.set_shader_parameter("rib", 0.0)


static func box(size: Vector3) -> Mesh:
	var mn: float = minf(size.x, minf(size.y, size.z))
	if mn < 0.03:
		var b: = BoxMesh.new()
		b.size = size
		return b
	var key: = "%.3f,%.3f,%.3f" % [size.x, size.y, size.z]
	if _box_cache.has(key):
		return _box_cache[key]
	var r: float = clampf(mn * 0.12, 0.006, 0.04)
	var h: = size * 0.5
	var i: = h - Vector3(r, r, r)
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for ax in 3:
		for s in [-1.0, 1.0]:
			var q: = _face_quad(ax, s, h, i)
			_quad(st, q[0], q[1], q[2], q[3])

	for ax in 3:
		var a1: = (ax + 1) % 3
		var a2: = (ax + 2) % 3
		for s1 in [-1.0, 1.0]:
			for s2 in [-1.0, 1.0]:
				var pts: Array = []
				for e in [-1.0, 1.0]:
					var p1: = Vector3.ZERO
					p1[ax] = e * i[ax]
					p1[a1] = s1 * h[a1]
					p1[a2] = s2 * i[a2]
					var p2: = Vector3.ZERO
					p2[ax] = e * i[ax]
					p2[a1] = s1 * i[a1]
					p2[a2] = s2 * h[a2]
					pts.append(p1)
					pts.append(p2)
				_quad(st, pts[0], pts[1], pts[3], pts[2])

	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var c: = Vector3(sx, sy, sz)
				_tri(st, Vector3(sx * h.x, sy * i.y, sz * i.z), Vector3(sx * i.x, sy * h.y, sz * i.z), Vector3(sx * i.x, sy * i.y, sz * h.z), c)
	var m: = st.commit()
	_box_cache[key] = m
	return m

static func _face_quad(ax: int, s: float, h: Vector3, i: Vector3) -> Array:
	var a1: = (ax + 1) % 3
	var a2: = (ax + 2) % 3
	var out: = []
	for c in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
		var p: = Vector3.ZERO
		p[ax] = s * h[ax]
		p[a1] = c[0] * i[a1]
		p[a2] = c[1] * i[a2]
		out.append(p)
	return out

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void :
	var out: = (a + b + c + d) * 0.25
	_tri(st, a, b, c, out)
	_tri(st, a, c, d, out)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void :
	var nrm: = (b - a).cross(c - a)
	if nrm.length_squared() < 1e-12:
		return
	nrm = nrm.normalized()
	if _front == 0.0:
		_front = _winding_sign()

	if nrm.dot(outward) < 0.0:
		var t: = b
		b = c
		c = t
		nrm = - nrm
	if _front < 0.0:
		var t2: = b
		b = c
		c = t2
	for v in [a, b, c]:
		st.set_normal(nrm)
		st.set_uv(Vector2.ZERO)
		st.add_vertex(v)


static func _winding_sign() -> float:
	var bm: = BoxMesh.new()
	var arr: = bm.get_mesh_arrays()
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var a: = vs[idx[0]]
	var b: = vs[idx[1]]
	var c: = vs[idx[2]]
	return 1.0 if (b - a).cross(c - a).dot(ns[idx[0]]) > 0.0 else -1.0



const PROP_RULES: = [
	["proto/", {"proto": true}], 
	["mountain", {"side": "rock", "top": "grass", "st": 7.0, "tt": 5.0, "desat": 0.3}], 
	["hex_", {"side": "rock", "top": "grass", "st": 3.0, "desat": 0.3}], 
	["city/road", {"side": "asphalt", "top": "asphalt", "d": 0.6, "desat": 0.1, "streaks": 0.0}], 
	["city/building", {"side": "plaster", "top": "concrete", "desat": 0.15}], 
	["city/", {"side": "paint_metal", "top": "paint_metal", "d": 0.5}], 
	["tree", {"side": "leaves", "top": "leaves", "desat": 0.3, "streaks": 0.0}], 
	["bush", {"side": "leaves", "top": "leaves", "desat": 0.3, "streaks": 0.0}], 
	["rock", {"side": "rock", "top": "rock", "desat": 0.2}], 
	["building_", {"side": "plaster", "top": "concrete", "roof": "terracotta", "desat": 0.2}], 
	["containers", {"side": "corrugated", "top": "corrugated", "metal": 0.3, "st": 1.0}], 
	["terrain", {"side": "rock", "top": "rock", "desat": 0.2}], 
	["space/", {"side": "paint_metal", "top": "tread", "d": 0.55, "metal": 0.25}], 
	["furniture/lamp", {"side": "brushed", "top": "brushed", "metal": 0.6}], 
	["furniture/bed", {"side": "wood", "top": "fabric", "tt": 0.6}], 
	["furniture/", {"side": "wood", "top": "wood", "st": 1.2, "tt": 1.2, "streaks": 0.0}], 
	["restaurant/food", {"side": "smooth", "top": "smooth", "streaks": 0.0}], 
	["restaurant/", {"side": "paint_metal", "top": "brushed", "d": 0.5, "streaks": 0.0}], 
	["dungeon/", {"side": "ashlar", "top": "paving"}], 
	["", {"side": "concrete", "top": "concrete", "d": 0.5}], 
]

const PROTO_BY_ZONE: = ["limestone", "concrete", "steel_deck", "plaster", "rock", "metal_panel"]

static var _prop_shader: Shader
static var _prop_cache: = {}


static func dress(root: Node, level = null) -> int:
	if _prop_shader == null:
		_prop_shader = load("res://shaders/prop_real.gdshader")
	var count: = 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m3: = mi as MeshInstance3D
		if m3.mesh == null or m3.material_override != null:
			continue
		var key: = _kit_key(m3)
		if key == "":
			continue
		for si in m3.mesh.get_surface_count():
			var src: = m3.get_active_material(si)
			if not (src is StandardMaterial3D):
				continue
			var sm: = src as StandardMaterial3D
			var rule: Dictionary = {}
			for r in PROP_RULES:
				if (r[0] as String) in key:
					rule = r[1]
					break
			if rule.get("proto", false) and level != null:
				m3.set_surface_override_material(si, level.mat(PROTO_BY_ZONE[_zone_of(m3.global_position.y, level)]))
				count += 1
				continue
			var ck: = "%d|%s" % [sm.get_instance_id(), key.get_base_dir() + "/" + str(PROP_RULES.find(rule))]
			var nm: ShaderMaterial = _prop_cache.get(ck)
			if nm == null:
				nm = _make_prop_mat(sm, rule)
				_prop_cache[ck] = nm
			m3.set_surface_override_material(si, nm)
			count += 1
	return count

static func _make_prop_mat(sm: StandardMaterial3D, rule: Dictionary) -> ShaderMaterial:
	var tx: = textures()
	var m: = ShaderMaterial.new()
	m.shader = _prop_shader
	m.set_shader_parameter("surf_a", tx[0])
	m.set_shader_parameter("surf_n", tx[1])
	m.set_shader_parameter("albedo_tex", sm.albedo_texture)
	m.set_shader_parameter("use_tex", sm.albedo_texture != null)
	m.set_shader_parameter("albedo_col", sm.albedo_color)
	m.set_shader_parameter("base_rough", clampf(sm.roughness, 0.3, 1.0))
	m.set_shader_parameter("base_metal", float(rule.get("metal", sm.metallic)))
	var side: String = rule.get("side", "concrete")
	var top: String = rule.get("top", side)
	m.set_shader_parameter("side_layer", float(FAM[side][0]))
	m.set_shader_parameter("side_tile", float(rule.get("st", FAM[side][1])))
	m.set_shader_parameter("top_layer", float(FAM[top][0]))
	m.set_shader_parameter("top_tile", float(rule.get("tt", FAM[top][1])))
	if rule.has("roof"):
		m.set_shader_parameter("roof_layer", float(FAM[rule.roof][0]))
		m.set_shader_parameter("roof_tile", float(FAM[rule.roof][1]))
	m.set_shader_parameter("detail", float(rule.get("d", FDEF[side][0] * 0.85)))
	m.set_shader_parameter("bump", float(FDEF[side][1]))
	m.set_shader_parameter("grime", float(FDEF[side][8]))
	m.set_shader_parameter("streaks", 0.0 if Game.mobile else float(rule.get("streaks", 0.35)))
	m.set_shader_parameter("desat", float(rule.get("desat", 0.12)))
	m.set_shader_parameter("lite", 1.0 if Game.mobile else 0.0)
	return m


static func _kit_key(n: Node) -> String:
	var p: Node = n
	while p != null:
		var f: = p.scene_file_path
		if f != "":
			var i: = f.find("/kaykit/")
			return f.substr(i + 8) if i >= 0 else ""
		p = p.get_parent()
	return ""

static func _zone_of(y: float, level) -> int:
	var z: = 0
	for i in level.zones.size():
		if y >= float(level.zones[i].y0) - 2.0:
			z = i
	return clampi(z, 0, PROTO_BY_ZONE.size() - 1)
