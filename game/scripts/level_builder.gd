extends Node3D


const ROUTE_PATH: = "res://data/route.json"

var route: Dictionary
var zones: Array = []
var nodes: Array = []
var piece_nodes: Array = []
var vehicles: Array = []
var finish_pos: = Vector3.ZERO
var low_gravity_y: = 99999.0

var _mats: = {}
var _scene_cache: = {}
var _shape_cache: = {}
var _surface_shader: Shader
var _cloud_shader: Shader
var SP
var PR
var CH = null
var oid_map: = {}

const MATS: = {
	"ground": {"a": Color(0.55, 0.62, 0.34), "b": Color(0.47, 0.55, 0.3), "top": Color(0.52, 0.64, 0.32), "top_amt": 0.0, "ns": 0.08, "rough": 0.95}, 
	"plaza": {"a": Color(0.86, 0.79, 0.66), "b": Color(0.8, 0.72, 0.58), "ns": 0.5, "rough": 0.9, "stripes": 0.6, "sw": 1.2}, 
	"limestone": {"a": Color(0.9, 0.84, 0.72), "b": Color(0.82, 0.74, 0.6), "ns": 0.6, "rough": 0.92, "top": Color(0.62, 0.66, 0.4), "top_amt": 0.25}, 
	"wood": {"a": Color(0.58, 0.4, 0.24), "b": Color(0.48, 0.32, 0.19), "ns": 0.9, "rough": 0.8, "stripes": 0.8, "sw": 0.3}, 
	"tank": {"a": Color(0.1, 0.1, 0.11), "b": Color(0.16, 0.16, 0.17), "ns": 0.4, "rough": 0.45}, 
	"drum": {"a": Color(0.16, 0.38, 0.68), "b": Color(0.12, 0.3, 0.55), "ns": 0.8, "rough": 0.5, "metal": 0.3}, 
	"concrete": {"a": Color(0.7, 0.7, 0.68), "b": Color(0.6, 0.6, 0.58), "ns": 0.5, "rough": 0.95}, 
	"roof": {"a": Color(0.82, 0.8, 0.76), "b": Color(0.74, 0.72, 0.68), "ns": 0.4, "rough": 0.95, "hazard": 0.0}, 
	"steel": {"a": Color(0.55, 0.58, 0.62), "b": Color(0.45, 0.48, 0.52), "ns": 0.9, "rough": 0.45, "metal": 0.7}, 
	"ibeam": {"a": Color(0.95, 0.55, 0.12), "b": Color(0.85, 0.45, 0.1), "ns": 1.0, "rough": 0.55, "metal": 0.3}, 
	"pipe_metal": {"a": Color(0.62, 0.66, 0.7), "b": Color(0.52, 0.56, 0.6), "ns": 1.0, "rough": 0.35, "metal": 0.8}, 
	"pipe_orange": {"a": Color(0.9, 0.42, 0.14), "b": Color(0.8, 0.35, 0.1), "ns": 1.0, "rough": 0.5, "metal": 0.3}, 
	"pole": {"a": Color(0.3, 0.32, 0.35), "b": Color(0.25, 0.27, 0.3), "ns": 1.0, "rough": 0.5, "metal": 0.6}, 
	"plank_white": {"a": Color(0.95, 0.93, 0.9), "b": Color(0.88, 0.86, 0.84), "ns": 1.0, "rough": 0.7, "stripes": 0.6, "sw": 0.35}, 
	"carpet": {"a": Color(0.72, 0.12, 0.14), "b": Color(0.6, 0.08, 0.1), "ns": 1.5, "rough": 0.9, "stripes": 0.9, "sw": 0.25}, 
	"mossy": {"a": Color(0.6, 0.58, 0.55), "b": Color(0.5, 0.48, 0.46), "ns": 0.6, "rough": 0.9, "top": Color(0.35, 0.62, 0.28), "top_amt": 0.9}, 
	"rope_bridge": {"a": Color(0.62, 0.45, 0.28), "b": Color(0.52, 0.36, 0.22), "ns": 1.2, "rough": 0.85, "stripes": 0.9, "sw": 0.45}, 
	"metal_panel": {"a": Color(0.78, 0.8, 0.84), "b": Color(0.66, 0.7, 0.76), "ns": 0.5, "rough": 0.4, "metal": 0.5, "stripes": 0.4, "sw": 1.0}, 
	"truss": {"a": Color(0.85, 0.85, 0.88), "b": Color(0.7, 0.72, 0.76), "ns": 1.0, "rough": 0.4, "metal": 0.6, "stripes": 0.5, "sw": 0.5}, 
	"bounce": {"a": Color(1.0, 0.35, 0.45), "b": Color(0.95, 0.25, 0.4), "ns": 1.0, "rough": 0.4, "em": Color(1.0, 0.3, 0.45), "ems": 0.35, "pulse": 3.0}, 
	"fan": {"a": Color(0.25, 0.28, 0.32), "b": Color(0.2, 0.22, 0.25), "ns": 1.5, "rough": 0.5, "metal": 0.6, "em": Color(0.4, 0.85, 1.0), "ems": 0.5, "pulse": 2.0}, 
	"rock": {"a": Color(0.52, 0.47, 0.42), "b": Color(0.42, 0.38, 0.34), "ns": 0.7, "rough": 0.95}, 
	"grass": {"a": Color(0.42, 0.66, 0.3), "b": Color(0.36, 0.58, 0.26), "ns": 0.5, "rough": 0.95}, 
	"asteroid": {"a": Color(0.45, 0.43, 0.47), "b": Color(0.33, 0.31, 0.35), "ns": 0.8, "rough": 0.95}, 
	"asteroid_top": {"a": Color(0.6, 0.58, 0.62), "b": Color(0.5, 0.48, 0.52), "ns": 0.8, "rough": 0.9}, 
	"moon": {"a": Color(0.98, 0.94, 0.8), "b": Color(0.92, 0.88, 0.74), "ns": 0.6, "rough": 0.7, "em": Color(1.0, 0.9, 0.6), "ems": 0.8}, 
	"olive_leaf": {"a": Color(0.46, 0.53, 0.36), "b": Color(0.36, 0.44, 0.3), "ns": 1.2, "rough": 0.9, "top": Color(0.6, 0.66, 0.48), "top_amt": 0.6}, 
	"olive_trunk": {"a": Color(0.42, 0.36, 0.3), "b": Color(0.32, 0.27, 0.22), "ns": 2.0, "rough": 0.95}, 
	"window": {"a": Color(0.16, 0.22, 0.3), "b": Color(0.12, 0.16, 0.22), "ns": 1.0, "rough": 0.25, "metal": 0.2}, 

	"window_lit0": {"a": Color(0.2, 0.2, 0.22), "b": Color(0.16, 0.16, 0.2), "ns": 1.0, "rough": 0.3, "em": Color(1.0, 0.72, 0.36), "ems": 0.0}, 
	"window_lit1": {"a": Color(0.2, 0.2, 0.22), "b": Color(0.16, 0.16, 0.2), "ns": 1.0, "rough": 0.3, "em": Color(1.0, 0.78, 0.45), "ems": 0.0}, 
	"window_lit2": {"a": Color(0.2, 0.2, 0.22), "b": Color(0.16, 0.16, 0.2), "ns": 1.0, "rough": 0.3, "em": Color(1.0, 0.66, 0.3), "ems": 0.0}, 
	"window_lit3": {"a": Color(0.2, 0.2, 0.22), "b": Color(0.16, 0.16, 0.2), "ns": 1.0, "rough": 0.3, "em": Color(0.95, 0.85, 0.6), "ems": 0.0}, 
	"window_lit4": {"a": Color(0.2, 0.2, 0.22), "b": Color(0.16, 0.16, 0.2), "ns": 1.0, "rough": 0.3, "em": Color(1.0, 0.6, 0.3), "ems": 0.0}, 
	"shutter": {"a": Color(0.2, 0.52, 0.55), "b": Color(0.16, 0.44, 0.48), "ns": 1.0, "rough": 0.7, "stripes": 0.8, "sw": 0.12}, 
	"door": {"a": Color(0.45, 0.28, 0.18), "b": Color(0.38, 0.22, 0.14), "ns": 1.2, "rough": 0.7, "stripes": 0.6, "sw": 0.15}, 
	"dome": {"a": Color(0.2, 0.55, 0.42), "b": Color(0.16, 0.48, 0.36), "ns": 0.8, "rough": 0.35, "metal": 0.3}, 
	"gold": {"a": Color(0.95, 0.75, 0.3), "b": Color(0.85, 0.65, 0.25), "ns": 1.0, "rough": 0.3, "metal": 0.9}, 
	"rubber": {"a": Color(0.12, 0.12, 0.13), "b": Color(0.08, 0.08, 0.09), "ns": 3.0, "rough": 0.9, "stripes": 0.5, "sw": 0.1}, 
	"container_red": {"a": Color(0.66, 0.22, 0.16), "b": Color(0.58, 0.18, 0.13), "ns": 0.9, "rough": 0.6, "metal": 0.3, "rib": 1.0}, 
	"container_blue": {"a": Color(0.16, 0.36, 0.62), "b": Color(0.12, 0.3, 0.54), "ns": 0.9, "rough": 0.6, "metal": 0.3, "rib": 1.0}, 
	"container_green": {"a": Color(0.2, 0.48, 0.3), "b": Color(0.16, 0.4, 0.25), "ns": 0.9, "rough": 0.6, "metal": 0.3, "rib": 1.0}, 
	"container_orange": {"a": Color(0.9, 0.5, 0.15), "b": Color(0.8, 0.42, 0.12), "ns": 0.9, "rough": 0.6, "metal": 0.3, "rib": 1.0}, 
	"rail": {"a": Color(0.22, 0.24, 0.27), "b": Color(0.18, 0.2, 0.22), "ns": 1.0, "rough": 0.4, "metal": 0.7}, 
	"lamp_glow": {"a": Color(1.0, 0.9, 0.7), "b": Color(1.0, 0.9, 0.7), "ns": 1.0, "rough": 0.3, "em": Color(1.0, 0.85, 0.55), "ems": 2.2}, 
	"planter": {"a": Color(0.72, 0.52, 0.38), "b": Color(0.64, 0.45, 0.32), "ns": 1.0, "rough": 0.85, "top": Color(0.35, 0.58, 0.25), "top_amt": 1.0}, 
	"tank_white": {"a": Color(0.92, 0.9, 0.84), "b": Color(0.84, 0.82, 0.76), "ns": 0.8, "rough": 0.55, "metal": 0.15}, 
	"tank_band": {"a": Color(0.16, 0.52, 0.56), "b": Color(0.13, 0.45, 0.5), "ns": 1.0, "rough": 0.5, "metal": 0.2}, 
	"grating": {"a": Color(0.44, 0.46, 0.48), "b": Color(0.38, 0.4, 0.42), "ns": 1.0, "rough": 0.5, "metal": 0.6, "stripes": 0.9, "sw": 0.09}, 
	"train_red": {"a": Color(0.8, 0.22, 0.18), "b": Color(0.72, 0.17, 0.14), "ns": 0.8, "rough": 0.42, "metal": 0.25}, 
	"train_cream": {"a": Color(0.96, 0.91, 0.79), "b": Color(0.9, 0.85, 0.72), "ns": 0.8, "rough": 0.5}, 
	"glass": {"a": Color(0.2, 0.3, 0.38), "b": Color(0.16, 0.24, 0.3), "ns": 1.0, "rough": 0.12, "metal": 0.35}, 
	"wicker": {"a": Color(0.68, 0.5, 0.29), "b": Color(0.57, 0.41, 0.23), "ns": 2.0, "rough": 0.9, "stripes": 1.0, "sw": 0.07}, 
	"rocket_white": {"a": Color(0.96, 0.96, 0.97), "b": Color(0.89, 0.89, 0.91), "ns": 0.6, "rough": 0.32, "metal": 0.2}, 
	"rocket_red": {"a": Color(0.86, 0.17, 0.16), "b": Color(0.76, 0.12, 0.12), "ns": 0.8, "rough": 0.4}, 
	"plaster": {"a": Color(0.94, 0.89, 0.8), "b": Color(0.88, 0.82, 0.73), "ns": 0.4, "rough": 0.95}, 
	"floor_wood": {"a": Color(0.62, 0.43, 0.27), "b": Color(0.53, 0.36, 0.22), "ns": 0.9, "rough": 0.75, "stripes": 0.9, "sw": 0.26}, 
	"flame": {"a": Color(1.0, 0.7, 0.3), "b": Color(1.0, 0.6, 0.2), "ns": 1.0, "rough": 1.0, "em": Color(1.0, 0.55, 0.15), "ems": 4.0, "pulse": 9.0}, 
	"engine_glow": {"a": Color(0.3, 0.3, 0.32), "b": Color(0.25, 0.25, 0.27), "ns": 1.0, "rough": 0.4, "metal": 0.7, "em": Color(1.0, 0.5, 0.2), "ems": 0.0}, 
	"cobble": {"a": Color(0.78, 0.72, 0.62), "b": Color(0.62, 0.56, 0.47), "ns": 3.0, "rough": 0.9, "stripes": 0.5, "sw": 0.5}, 
	"asphalt": {"a": Color(0.25, 0.26, 0.28), "b": Color(0.2, 0.21, 0.23), "ns": 2.5, "rough": 0.9}, 
	"sidewalk": {"a": Color(0.72, 0.7, 0.66), "b": Color(0.64, 0.62, 0.58), "ns": 1.0, "rough": 0.9, "stripes": 0.6, "sw": 0.6}, 
	"paint_white": {"a": Color(0.95, 0.95, 0.93), "b": Color(0.9, 0.9, 0.88), "ns": 1.0, "rough": 0.7}, 
	"paint_yellow": {"a": Color(0.98, 0.8, 0.2), "b": Color(0.92, 0.72, 0.15), "ns": 1.0, "rough": 0.7}, 
	"steel_deck": {"a": Color(0.5, 0.52, 0.55), "b": Color(0.42, 0.44, 0.47), "ns": 1.0, "rough": 0.5, "metal": 0.6, "stripes": 0.8, "sw": 0.12}, 
	"stone_bridge": {"a": Color(0.86, 0.76, 0.6), "b": Color(0.74, 0.64, 0.5), "ns": 1.2, "rough": 0.9, "stripes": 0.35, "sw": 0.9}, 
	"clay": {"a": Color(0.76, 0.46, 0.3), "b": Color(0.66, 0.38, 0.24), "ns": 1.5, "rough": 0.95}, 
	"bread": {"a": Color(0.88, 0.66, 0.36), "b": Color(0.72, 0.48, 0.24), "ns": 4.0, "rough": 0.9}, 
	"bus": {"a": Color(0.98, 0.76, 0.12), "b": Color(0.92, 0.68, 0.08), "ns": 0.8, "rough": 0.45, "metal": 0.2}, 
	"chassis": {"a": Color(0.18, 0.18, 0.19), "b": Color(0.12, 0.12, 0.13), "ns": 2.0, "rough": 0.7, "metal": 0.4}, 
	"gas": {"a": Color(0.18, 0.42, 0.78), "b": Color(0.14, 0.36, 0.7), "ns": 0.8, "rough": 0.4, "metal": 0.35}, 
	"gas_grey": {"a": Color(0.72, 0.73, 0.75), "b": Color(0.64, 0.65, 0.67), "ns": 0.8, "rough": 0.4, "metal": 0.4}, 
	"porcelain": {"a": Color(0.97, 0.96, 0.93), "b": Color(0.93, 0.92, 0.89), "ns": 0.5, "rough": 0.2}, 
	"coffee": {"a": Color(0.36, 0.22, 0.1), "b": Color(0.3, 0.18, 0.08), "ns": 3.0, "rough": 0.15}, 
	"iron": {"a": Color(0.2, 0.18, 0.17), "b": Color(0.28, 0.2, 0.15), "ns": 2.5, "rough": 0.6, "metal": 0.7}, 
	"bead": {"a": Color(0.55, 0.22, 0.1), "b": Color(0.42, 0.14, 0.06), "ns": 1.2, "rough": 0.2, "metal": 0.1}, 
	"copper": {"a": Color(0.86, 0.55, 0.28), "b": Color(0.76, 0.46, 0.22), "ns": 1.0, "rough": 0.3, "metal": 0.9}, 
	"neon_blue": {"a": Color(0.6, 0.85, 1.0), "b": Color(0.6, 0.85, 1.0), "ns": 1.0, "rough": 0.3, "em": Color(0.3, 0.7, 1.0), "ems": 2.0}, 
	"crumble_stone": {"a": Color(0.78, 0.7, 0.6), "b": Color(0.62, 0.55, 0.47), "ns": 1.5, "rough": 0.95}, 
	"terracotta": {"a": Color(0.5, 0.5, 0.5), "b": Color(0.46, 0.44, 0.44), "ns": 1.0, "rough": 0.85}, 
	"ashlar": {"a": Color(0.52, 0.5, 0.46), "b": Color(0.46, 0.45, 0.42), "ns": 0.8, "rough": 0.9}, 
	"marble": {"a": Color(0.92, 0.9, 0.86), "b": Color(0.84, 0.82, 0.8), "ns": 1.5, "rough": 0.2}, 
	"cushion": {"a": Color(0.42, 0.14, 0.14), "b": Color(0.34, 0.1, 0.12), "ns": 1.0, "rough": 0.95}, 
	"linen": {"a": Color(0.9, 0.88, 0.8), "b": Color(0.82, 0.8, 0.72), "ns": 1.0, "rough": 0.95}, 
	"blanket": {"a": Color(0.25, 0.32, 0.42), "b": Color(0.2, 0.26, 0.36), "ns": 1.0, "rough": 0.95}, 
	"paper": {"a": Color(0.9, 0.86, 0.76), "b": Color(0.84, 0.8, 0.7), "ns": 2.0, "rough": 0.9}, 
	"painting": {"a": Color(0.3, 0.36, 0.5), "b": Color(0.72, 0.5, 0.36), "ns": 0.6, "rough": 0.6}, 
	"cloud": {"a": Color(0.92, 0.93, 0.96), "b": Color(0.8, 0.84, 0.92), "ns": 0.5, "rough": 1.0}, 
}

func _ready() -> void :
	SP = load("res://scripts/setpieces.gd").new(self)
	PR = load("res://scripts/props_real.gd").new(self)
	_surface_shader = load("res://shaders/surface.gdshader")
	_cloud_shader = load("res://shaders/cloud.gdshader")

func load_route() -> void :
	var f: = FileAccess.open(ROUTE_PATH, FileAccess.READ)
	route = JSON.parse_string(f.get_as_text())
	zones = route.zones
	nodes = route.nodes
	oid_map.clear()
	for i in nodes.size():
		var o: = int(nodes[i].get("oid", i))
		if o >= 0:
			oid_map[o] = i
	for n in nodes:
		if n.get("finish", false):
			finish_pos = _v3(n.p)
	for n in nodes:
		if int(n.z) == 6 and n.get("hub", 0) == 6:
			low_gravity_y = float(n.p[1]) - 1.0
			break
	Game.low_gravity_y = low_gravity_y

func build() -> void :
	if route.is_empty():
		load_route()
	var path_root: = Node3D.new()
	path_root.name = "Path"
	add_child(path_root)
	var decor_root: = Node3D.new()
	decor_root.name = "Decor"
	add_child(decor_root)
	piece_nodes.resize(route.pieces.size())
	var i: = 0
	for p in route.pieces:
		var parent: Node3D = decor_root if p.role == "decor" else path_root
		var n: = _build_piece(p, i)
		if n:
			parent.add_child(n)
		piece_nodes[i] = n
		i += 1
	SP.bead_cords(route.pieces, piece_nodes)

func _v3(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func mat(name: String) -> Material:
	if _mats.has(name):
		return _mats[name]
	var d: Dictionary = MATS.get(name, MATS["concrete"])
	var m: = ShaderMaterial.new()
	m.shader = _surface_shader
	m.set_shader_parameter("color_a", d.get("a", Color.WHITE))
	m.set_shader_parameter("color_b", d.get("b", Color.WHITE))
	m.set_shader_parameter("top_color", d.get("top", Color(0.4, 0.6, 0.3)))
	m.set_shader_parameter("top_amount", d.get("top_amt", 0.0))
	m.set_shader_parameter("noise_scale", d.get("ns", 0.5))
	m.set_shader_parameter("roughness_v", d.get("rough", 0.85))
	m.set_shader_parameter("metallic_v", d.get("metal", 0.0))
	m.set_shader_parameter("stripes", d.get("stripes", 0.0))
	m.set_shader_parameter("stripe_width", d.get("sw", 0.35))
	m.set_shader_parameter("hazard", d.get("hazard", 0.0))
	m.set_shader_parameter("emission_color", d.get("em", Color.BLACK))
	m.set_shader_parameter("emission_strength", d.get("ems", 0.0))
	m.set_shader_parameter("pulse", d.get("pulse", 0.0))
	m.set_shader_parameter("rib", d.get("rib", 0.0))
	Surf.apply(m, name)
	_mats[name] = m
	return m

func cloud_mat() -> Material:
	if _mats.has("_cloud"):
		return _mats["_cloud"]
	var m: = ShaderMaterial.new()
	m.shader = _cloud_shader
	m.set_shader_parameter("lite", 1.0 if Game.mobile else 0.0)
	_mats["_cloud"] = m
	return m


func _build_piece(p: Dictionary, idx: int) -> Node3D:
	var t: String = p.t
	var mech: Dictionary = p.get("m", {})
	var mtype: String = mech.get("type", "")
	var body: Node3D
	match t:
		"prop":
			body = _prop_body(p, mtype != "")
		"mover":
			if p.get("m", {}).get("type", "") == "path":
				body = SP.vehicle(p)
				vehicles.append(body)
			else:
				body = _box_body(p)
		"box", "hub_roof", "hub_deck", "ground":
			body = _box_body(p)
		"station":
			body = SP.station(p)
		"room":
			body = SP.room(p)
		"wallpiece":
			body = SP.wall(p)
		"viaduct":
			body = SP.viaduct(p)
		"crane_mast":
			body = SP.crane_mast(p)
		"crane_jib":
			body = SP.crane_jib(p)
		"tower":
			body = SP.tower(p)
		"cyl", "tank", "pole", "tire", "plaza":
			body = _cyl_body(p)
			if t == "plaza" and p.get("tag", "") == "boulevard":
				SP.plaza_dress(body, p)
		"house":
			body = _house_body(p)
		"olive":
			body = _olive_body(p)
		"minaret":
			body = _minaret_body(p)
		"crane":
			body = _crane_body(p)
		"balloon":
			body = _balloon_body(p)
		"isle_big", "planetoid":
			body = _island_body(p)
		"beam", "pipe", "promenade":
			body = _beam_body(p)
		"ch":

			if CH == null:
				CH = load("res://scripts/challenge_pieces.gd").new(self)
			body = CH.build(p)
		"boulevard":
			body = SP.boulevard(p)
		"bus":
			body = SP.bus(p)
		"key":
			body = SP.key(p)
		"taboon", "gas", "finjan", "bead":
			body = SP.moment_cyl(p)
		"dallah":
			body = SP.dallah(p)
		"island", "cloud", "asteroid", "moon":
			body = _island_body(p)
		_:
			return null
	body.name = "P%d" % idx
	body.set_meta("piece", idx)
	if p.get("tag", "") == "hub":
		_hub_sign(body, p)
	var vr: = 1100.0 if p.role == "decor" else 750.0
	if Game.mobile:

		var qm: int = int(Game.settings.quality)
		vr = [300.0, 380.0, 460.0, 560.0][qm] * (0.8 if p.role == "decor" else 1.0)
		var ext: = 0.0
		for gi2 in body.find_children("*", "VisualInstance3D", true, false):
			if gi2 is GeometryInstance3D and not gi2 is Label3D:
				ext = maxf(ext, (gi2 as VisualInstance3D).get_aabb().size.length() * absf((gi2 as Node3D).scale.x))
		if ext > 22.0:
			vr = 1000.0
	for gi in body.find_children("*", "GeometryInstance3D", true, false):
		if gi is Label3D:
			continue
		(gi as GeometryInstance3D).visibility_range_end = vr
		(gi as GeometryInstance3D).visibility_range_end_margin = 50.0
	if mtype != "":
		_attach_mech(body, p, mech)
	return body

func _new_body(animatable: bool) -> PhysicsBody3D:
	if animatable:
		var ab: = AnimatableBody3D.new()
		ab.sync_to_physics = true
		ab.set_meta("moving", true)
		return ab
	return StaticBody3D.new()

func _needs_animatable(p: Dictionary) -> bool:
	var mech: Dictionary = p.get("m", {})
	return mech.get("type", "") in ["move", "crumble", "path"]


func _prop_body(p: Dictionary, has_mech: bool) -> Node3D:
	var key: String = p.k
	var s: float = p.s
	var body: = _new_body(_needs_animatable(p))
	body.position = _v3(p.p)
	body.rotation.y = p.r
	var zone_id: int = int(p.get("z", 1))
	var seed_: int = int(absf(float(p.p[0]) * 31.0 + float(p.p[1]) * 7.0 + float(p.p[2]) * 13.0)) + 11
	var model: Node3D = PR.build(key, zone_id, seed_)
	model.scale = Vector3.ONE * s
	model.name = "Model"
	body.add_child(model)
	var decor: bool = p.role == "decor"
	var ck: = "%s@%.3f@%d" % [key, s, seed_ if key.begins_with("medieval/tiles") else 0]
	var shape: Shape3D
	if _shape_cache.has(ck):
		shape = _shape_cache[ck]
	else:
		var faces: = PackedVector3Array()
		_collect_faces(model, Transform3D.IDENTITY.scaled(Vector3.ONE * s), faces, true)
		var cps: = ConcavePolygonShape3D.new()
		cps.set_faces(faces)
		cps.backface_collision = true
		shape = cps
		_shape_cache[ck] = shape
	var cs: = CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var gi: = mi as GeometryInstance3D
		if decor:
			gi.visibility_range_end = 900.0
			gi.visibility_range_end_margin = 60.0
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return body

func _collect_faces(node: Node, xf: Transform3D, out: PackedVector3Array, is_root: bool) -> void :
	var here: = xf
	if not is_root and node is Node3D:
		here = xf * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh:
			var f: = mesh.get_faces()
			for v in f:
				out.append(here * v)
	for c in node.get_children():
		_collect_faces(c, here, out, false)


func _box_body(p: Dictionary) -> Node3D:
	var t: String = p.t
	var d: = _v3(p.d)
	var body: = _new_body(_needs_animatable(p))
	body.position = _v3(p.p)
	body.rotation.y = p.get("r", 0.0)
	var mi: = MeshInstance3D.new()
	var bm: Mesh = Surf.box(d)
	mi.mesh = bm
	var mname: String = p.get("mat", "concrete")
	if t == "ground":
		mname = "plaza"
	mi.material_override = mat(mname)
	body.add_child(mi)
	var cs: = CollisionShape3D.new()
	var bs: = BoxShape3D.new()
	bs.size = d
	cs.shape = bs
	body.add_child(cs)
	if t == "mover":
		var kind: String = p.get("m", {}).get("kind", "slab")
		if kind == "carpet":
			_decorate_carpet(mi, d)
		elif kind == "rock":
			mi.material_override = mat("mossy" if int(p.z) == 5 else "asteroid_top")
			_add_rock_under(body, d)
	var mtype: String = p.get("m", {}).get("type", "")
	if mtype == "bounce":
		mi.visible = false
		_build_trampoline(body, d)
		_merge_meshes(body)
	elif mtype == "updraft" and String(p.get("m", {}).get("style", "")) == "":
		_build_fan_base(body, d)
	elif mname == "cloud":
		mi.visible = false
		_build_cloud_slab(body, d, int(p.get("r", 0.0) * 1000.0))
		_merge_meshes(body)
	elif mtype == "crumble":
		mi.material_override = mat("crumble_stone")
	elif t == "box" and mname == "concrete" and int(p.get("z", 0)) == 3 and d.y > 0.7:
		var cols: = ["container_red", "container_blue", "container_green", "container_orange"]
		mi.material_override = mat(cols[int(absf(p.get("r", 0.0)) * 100.0) % cols.size()])
		_container_trim(body, d)
	if t == "hub_deck":
		mi.material_override = mat("concrete")
		_add_hazard_trim(body, d)
	if t == "hub_roof":
		_add_roof_trim(body, d)
	return body

func _container_trim(body: Node3D, d: Vector3) -> void :

	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_mesh_box(body, Vector3(0.14, d.y + 0.02, 0.14), Vector3(sx * (d.x * 0.5 - 0.06), 0, sz * (d.z * 0.5 - 0.06)), "rail")
	for sz in [-1.0, 1.0]:
		_mesh_box(body, Vector3(d.x + 0.02, 0.1, 0.1), Vector3(0, d.y * 0.5 - 0.05, sz * (d.z * 0.5 - 0.04)), "rail")
		_mesh_box(body, Vector3(d.x + 0.02, 0.1, 0.1), Vector3(0, - d.y * 0.5 + 0.05, sz * (d.z * 0.5 - 0.04)), "rail")
	_merge_meshes(body)

func _build_trampoline(body: Node3D, d: Vector3) -> void :

	var top_y: = d.y * 0.5
	var frame_m: = mat("pole")
	var pad: = MeshInstance3D.new()
	var pm: Mesh = Surf.box(Vector3(d.x - 0.3, 0.12, d.z - 0.3))
	pad.mesh = pm
	pad.position = Vector3(0, top_y - 0.08, 0)
	pad.material_override = mat("bounce")
	body.add_child(pad)
	for sx in [-1.0, 1.0]:
		var bar: = MeshInstance3D.new()
		var bm: Mesh = Surf.box(Vector3(0.22, 0.22, d.z))
		bar.mesh = bm
		bar.position = Vector3(sx * (d.x * 0.5 - 0.11), top_y - 0.11, 0)
		bar.material_override = mat("drum")
		body.add_child(bar)
	for sz in [-1.0, 1.0]:
		var bar2: = MeshInstance3D.new()
		var bm2: Mesh = Surf.box(Vector3(d.x, 0.22, 0.22))
		bar2.mesh = bm2
		bar2.position = Vector3(0, top_y - 0.11, sz * (d.z * 0.5 - 0.11))
		bar2.material_override = mat("drum")
		body.add_child(bar2)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var leg: = MeshInstance3D.new()
			var lm: = CylinderMesh.new()
			lm.top_radius = 0.07
			lm.bottom_radius = 0.07
			lm.height = 1.2
			leg.mesh = lm
			leg.position = Vector3(sx * (d.x * 0.5 - 0.2), top_y - 0.7, sz * (d.z * 0.5 - 0.2))
			leg.material_override = frame_m
			body.add_child(leg)

	var glow: = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.4, 0.55)
	glow.light_energy = 0.8
	glow.omni_range = 4.0
	glow.position = Vector3(0, top_y + 0.5, 0)
	body.add_child(glow)

func _build_fan_base(body: Node3D, d: Vector3) -> void :
	var ring: = MeshInstance3D.new()
	var tm: = TorusMesh.new()
	var r: float = minf(d.x, d.z) * 0.42
	tm.inner_radius = r
	tm.outer_radius = r + 0.12
	tm.rings = 32
	ring.mesh = tm
	ring.position = Vector3(0, d.y * 0.5 + 0.02, 0)
	var m: = StandardMaterial3D.new()
	m.albedo_color = Color(0.4, 0.85, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.4, 0.85, 1.0)
	m.emission_energy_multiplier = 2.0
	ring.material_override = m
	body.add_child(ring)

func _build_cloud_slab(body: Node3D, d: Vector3, sd: int) -> void :
	var rng: = RandomNumberGenerator.new()
	rng.seed = sd
	var top: = MeshInstance3D.new()
	var bm: Mesh = Surf.box(Vector3(d.x - 0.2, 0.3, d.z - 0.2))
	top.mesh = bm
	top.position = Vector3(0, d.y * 0.5 - 0.15, 0)
	top.material_override = cloud_mat()
	body.add_child(top)
	var n: = 4 + int(d.x * d.z * 0.4)
	for i in n:
		var r: = rng.randf_range(0.45, 0.8) * minf(d.x, d.z) * 0.6
		var sm: = SphereMesh.new()
		sm.radius = r
		sm.height = r * 1.3
		sm.radial_segments = 12
		sm.rings = 6
		var mi: = MeshInstance3D.new()
		mi.mesh = sm
		mi.position = Vector3(rng.randf_range(-0.4, 0.4) * d.x, d.y * 0.5 - r * 0.6, rng.randf_range(-0.4, 0.4) * d.z)
		mi.material_override = cloud_mat()
		body.add_child(mi)

func _promenade_dressing(body: Node3D, d: Vector3, mname: String, sd: int) -> void :

	var rng: = RandomNumberGenerator.new()
	rng.seed = sd
	var L: = d.x
	var hw: = d.z * 0.5
	var top: = d.y * 0.5
	var rail_m: = "wood" if mname in ["wood", "limestone"] else "rail"
	for sz in [-1.0, 1.0]:
		_mesh_box(body, Vector3(L - 0.2, 0.08, 0.08), Vector3(0, top + 0.95, sz * (hw - 0.06)), rail_m)
		_mesh_box(body, Vector3(L - 0.2, 0.05, 0.05), Vector3(0, top + 0.5, sz * (hw - 0.06)), rail_m)
		var npost: = int(L / 2.0) + 1
		for k in npost:
			var x: = - L * 0.5 + 0.15 + (L - 0.3) * k / maxf(npost - 1, 1)
			_mesh_box(body, Vector3(0.08, 0.95, 0.08), Vector3(x, top + 0.47, sz * (hw - 0.06)), rail_m)
		var cs: = CollisionShape3D.new()
		var bs: = BoxShape3D.new()
		bs.size = Vector3(L - 0.2, 1.0, 0.12)
		cs.shape = bs
		cs.position = Vector3(0, top + 0.5, sz * (hw - 0.06))
		body.add_child(cs)

	var nl: = int(L / 6.0)
	for k in nl:
		var x: = - L * 0.5 + (k + 0.5) * L / nl
		var sz: = 1.0 if k % 2 == 0 else -1.0
		_mesh_box(body, Vector3(0.1, 2.6, 0.1), Vector3(x, top + 1.3, sz * (hw - 0.06)), "rail")
		_mesh_box(body, Vector3(0.5, 0.08, 0.08), Vector3(x, top + 2.55, sz * (hw - 0.3)), "rail")
		var bulb: = MeshInstance3D.new()
		var sm: = SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		bulb.mesh = sm
		bulb.position = Vector3(x, top + 2.38, sz * (hw - 0.52))
		bulb.material_override = mat("lamp_glow")
		body.add_child(bulb)

	for k in rng.randi_range(1, 3):
		var x: = rng.randf_range( - L * 0.4, L * 0.4)
		var sz: float = 1.0 if rng.randf() < 0.5 else -1.0
		_mesh_box(body, Vector3(1.1, 0.5, 0.45), Vector3(x, top + 0.25, sz * (hw - 0.35)), "planter")
	_merge_meshes(body)

func _build_tire(body: Node3D, rad: float, h: float, plain: = false) -> void :

	var tube: = rad * 0.24
	for k in 2:
		var tr: = MeshInstance3D.new()
		var tm: = TorusMesh.new()
		tm.inner_radius = rad - tube * 2.0
		tm.outer_radius = rad
		tm.rings = 36
		tm.ring_segments = 14
		tr.mesh = tm
		tr.position = Vector3(0, h * 0.5 - tube - k * tube * 1.9, 0)
		tr.scale = Vector3(1, 1.15, 1)
		tr.material_override = mat("rubber")
		body.add_child(tr)
		var rimm: = MeshInstance3D.new()
		var cm: = CylinderMesh.new()
		cm.top_radius = rad - tube * 2.0 + 0.05
		cm.bottom_radius = rad - tube * 2.0 + 0.05
		cm.height = 0.12
		rimm.mesh = cm
		rimm.position = tr.position
		rimm.material_override = mat("steel")
		body.add_child(rimm)
	var pad: = MeshInstance3D.new()
	var pm: = CylinderMesh.new()
	pm.top_radius = rad - tube * 1.6
	pm.bottom_radius = rad - tube * 1.6
	pm.height = 0.1
	pad.mesh = pm
	pad.position = Vector3(0, h * 0.5 - 0.08, 0)
	pad.material_override = mat("floor_wood" if plain else "bounce")
	body.add_child(pad)
	if not plain:
		var glow: = OmniLight3D.new()
		glow.light_color = Color(1.0, 0.45, 0.55)
		glow.light_energy = 0.7
		glow.omni_range = 4.0
		glow.position = Vector3(0, h * 0.5 + 0.6, 0)
		body.add_child(glow)
	_merge_meshes(body)

func _decorate_carpet(mi: MeshInstance3D, d: Vector3) -> void :

	mi.visible = false
	var rug: Node3D = PR.build("furniture/rug_rectangle_stripes_A.gltf", 4, 7)
	rug.scale = Vector3(d.x / 3.0, 1.6, d.z / 2.0)
	rug.position = Vector3(0, d.y * 0.5 - 0.04, 0)
	mi.get_parent().add_child(rug)

func _add_rock_under(body: Node3D, d: Vector3) -> void :
	var cone: = MeshInstance3D.new()
	var cm: = CylinderMesh.new()
	cm.top_radius = max(d.x, d.z) * 0.5
	cm.bottom_radius = 0.1
	cm.height = max(d.x, d.z) * 0.9
	cm.radial_segments = 7
	cm.rings = 1
	cone.mesh = cm
	cone.position = Vector3(0, - d.y * 0.5 - cm.height * 0.5, 0)
	cone.material_override = mat("rock")
	body.add_child(cone)

func _add_hazard_trim(body: Node3D, d: Vector3) -> void :
	var trim: = MeshInstance3D.new()
	var bm: Mesh = Surf.box(Vector3(d.x + 0.02, d.y * 0.5, d.z + 0.02))
	trim.mesh = bm
	trim.position = Vector3(0, - d.y * 0.25, 0)
	var m: = (mat("ibeam") as ShaderMaterial).duplicate()
	m.set_shader_parameter("hazard", 1.0)
	trim.material_override = m
	body.add_child(trim)

func _add_roof_trim(body: Node3D, d: Vector3) -> void :

	var band: = MeshInstance3D.new()
	var bm: Mesh = Surf.box(Vector3(d.x + 0.06, d.y * 0.6, d.z + 0.06))
	band.mesh = bm
	band.position = Vector3(0, - d.y * 0.2, 0)
	band.material_override = mat("limestone")
	body.add_child(band)


func _merge_meshes(root: Node3D) -> void :
	var groups: = {}
	var order: = []
	var to_remove: = []
	for c in root.get_children():
		if c is MeshInstance3D and c.material_override != null and c.mesh != null and c.get_child_count() == 0 and c.visible:
			var mi: = c as MeshInstance3D
			var m: Material = mi.material_override
			if not groups.has(m):
				var st: = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[m] = st
				order.append(m)
			for si in mi.mesh.get_surface_count():
				groups[m].append_from(mi.mesh, si, mi.transform)
			to_remove.append(mi)
	if to_remove.size() < 2:
		return
	var am: = ArrayMesh.new()
	var i: = 0
	for m in order:
		groups[m].commit(am)
		am.surface_set_material(i, m)
		i += 1
	for mi in to_remove:
		root.remove_child(mi)
		mi.free()
	var merged: = MeshInstance3D.new()
	merged.name = "Merged"
	merged.mesh = am
	root.add_child(merged)


func _mesh_box(parent: Node3D, size: Vector3, pos: Vector3, m: String, rot_y: = 0.0) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	var bm: Mesh = Surf.box(size)
	mi.mesh = bm
	mi.position = pos
	mi.rotation.y = rot_y
	mi.material_override = mat(m)
	parent.add_child(mi)
	return mi

func _mesh_cyl(parent: Node3D, r: float, h: float, pos: Vector3, m: String, segs: = 16, r_top: = -1.0) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	var cm: = CylinderMesh.new()
	cm.top_radius = r if r_top < 0.0 else r_top
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.position = pos
	mi.material_override = mat(m)
	parent.add_child(mi)
	return mi

func _house_body(p: Dictionary) -> Node3D:
	var d: = _v3(p.d)
	var body: = StaticBody3D.new()
	body.position = _v3(p.p)
	body.rotation.y = p.get("r", 0.0)
	var rng: = RandomNumberGenerator.new()
	rng.seed = int(p.get("seed", 1))
	_mesh_box(body, d, Vector3.ZERO, "limestone")
	var cs: = CollisionShape3D.new()
	var bs: = BoxShape3D.new()
	bs.size = d
	cs.shape = bs
	body.add_child(cs)
	var hy: = d.y * 0.5
	var floors: = int(round((d.y - 0.4) / 3.4))

	for sx in [-1.0, 1.0]:
		_mesh_box(body, Vector3(0.22, 0.55, d.z), Vector3(sx * (d.x * 0.5 - 0.11), hy + 0.27, 0), "limestone")
	for sz in [-1.0, 1.0]:
		_mesh_box(body, Vector3(d.x, 0.55, 0.22), Vector3(0, hy + 0.27, sz * (d.z * 0.5 - 0.11)), "limestone")

	for f in range(1, floors):
		_mesh_box(body, Vector3(d.x + 0.12, 0.18, d.z + 0.12), Vector3(0, - hy + f * 3.4, 0), "concrete")

	for side in 4:
		var along: = d.x if side % 2 == 0 else d.z
		var depth: = d.z if side % 2 == 0 else d.x
		var n: = int(along / 2.6)
		for f in floors:
			for k in n:
				var u: = - along * 0.5 + along * (k + 0.5) / n
				var y: = - hy + f * 3.4 + 1.9
				if f == 0 and side == 0 and k == n / 2:
					var door: = Vector3(u, - hy + 1.1, depth * 0.5 + 0.03)
					var dm: = _mesh_box(body, Vector3(1.2, 2.2, 0.1), Vector3.ZERO, "door")
					_place_on_side(dm, side, door)
					continue
				var wv: = Vector3(u, y, depth * 0.5 + 0.03)
				var wm: = _mesh_box(body, Vector3(1.0, 1.35, 0.08), Vector3.ZERO, "window_lit%d" % rng.randi_range(0, 4) if rng.randf() < 0.8 else "window")
				_place_on_side(wm, side, wv)
				if rng.randf() < 0.45:
					for s2 in [-1.0, 1.0]:
						var sh: = _mesh_box(body, Vector3(0.5, 1.4, 0.06), Vector3.ZERO, "shutter")
						_place_on_side(sh, side, wv + Vector3(s2 * 0.78, 0, 0.02))

	var tanks: = rng.randi_range(1, 3) if p.get("tag", "") != "grandma" else 0
	for i in tanks:
		var tx: = rng.randf_range( - d.x * 0.3, d.x * 0.3)
		var tz: = rng.randf_range( - d.z * 0.3, d.z * 0.3)
		var r: = rng.randf_range(0.5, 0.7)
		_mesh_cyl(body, r, 1.3, Vector3(tx, hy + 0.9, tz), "tank", 18)
		_mesh_box(body, Vector3(r * 1.8, 0.25, r * 1.8), Vector3(tx, hy + 0.12, tz), "steel")
	if rng.randf() < 0.6 and p.get("tag", "") != "grandma":
		var sp: = _mesh_box(body, Vector3(1.8, 0.08, 1.1), Vector3( - d.x * 0.25, hy + 0.9, d.z * 0.28), "window")
		sp.rotation.x = -0.6
		_mesh_cyl(body, 0.28, 1.6, Vector3( - d.x * 0.25, hy + 1.45, d.z * 0.28 - 0.6), "steel", 12).rotation.z = PI * 0.5
	if rng.randf() < 0.5 and p.get("tag", "") != "grandma":
		var dish: = _mesh_cyl(body, 0.5, 0.12, Vector3(d.x * 0.3, hy + 1.0, - d.z * 0.3), "roof", 16)
		dish.rotation.x = 0.8
	if p.get("float", false):

		var am: = _island_mesh(max(d.x, d.z) * 0.62, 10.0, rng, 0.25, false)
		var rock: = MeshInstance3D.new()
		rock.mesh = _island_visual(am, max(d.x, d.z) * 0.62, int(p.get("seed", 3)))
		rock.position = Vector3(0, - hy, 0)
		rock.set_surface_override_material(0, mat("concrete"))
		rock.set_surface_override_material(1, mat("rock"))
		body.add_child(rock)
	_merge_meshes(body)
	return body

func _place_on_side(mi: Node3D, side: int, v: Vector3) -> void :

	var a: = side * PI * 0.5
	mi.position = Vector3(v.x * cos(a) + v.z * sin(a), v.y, - v.x * sin(a) + v.z * cos(a))
	mi.rotation.y = a

func _olive_body(p: Dictionary) -> Node3D:
	var body: = StaticBody3D.new()
	var pos: = _v3(p.p)
	var r: float = p.rad
	var h: float = p.h
	body.position = Vector3(pos.x, 0.0, pos.z)
	var rng: = RandomNumberGenerator.new()
	rng.seed = int(p.get("seed", 1))
	var tr: = _mesh_cyl(body, 0.32, h * 0.55, Vector3(0, h * 0.27, 0), "olive_trunk", 7, 0.22)
	tr.rotation.z = rng.randf_range(-0.2, 0.2)
	for i in rng.randi_range(2, 3):
		var br: = _mesh_cyl(body, 0.16, h * 0.4, Vector3(rng.randf_range(-0.4, 0.4), h * 0.55, rng.randf_range(-0.4, 0.4)), "olive_trunk", 6, 0.1)
		br.rotation = Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
	for i in rng.randi_range(5, 8):
		var sm: = SphereMesh.new()
		var rr: = rng.randf_range(r * 0.45, r * 0.7)
		sm.radius = rr
		sm.height = rr * 1.4
		sm.radial_segments = 10
		sm.rings = 6
		var mi: = MeshInstance3D.new()
		mi.mesh = sm
		var a: = rng.randf() * TAU
		var dd: = rng.randf_range(0.0, r * 0.55)
		mi.position = Vector3(cos(a) * dd, h * 0.72 + rng.randf_range(-0.4, 0.6), sin(a) * dd)
		mi.material_override = mat("olive_leaf")
		body.add_child(mi)
	var cs: = CollisionShape3D.new()
	var shp: = CylinderShape3D.new()
	shp.radius = 0.35
	shp.height = h * 0.6
	cs.shape = shp
	cs.position = Vector3(0, h * 0.3, 0)
	body.add_child(cs)
	_merge_meshes(body)
	return body

func _minaret_body(p: Dictionary) -> Node3D:
	var body: = StaticBody3D.new()
	var pos: = _v3(p.p)
	var r: float = p.rad
	var h: float = p.h
	body.position = Vector3(pos.x, 0.0, pos.z)
	_mesh_box(body, Vector3(r * 2.6, 3.0, r * 2.6), Vector3(0, 1.5, 0), "limestone")
	_mesh_cyl(body, r, h * 0.62, Vector3(0, 3.0 + h * 0.31, 0), "limestone", 8)
	var by: = 3.0 + h * 0.62
	_mesh_cyl(body, r * 1.45, 0.5, Vector3(0, by, 0), "concrete", 8)
	for i in 8:
		var a: = TAU * i / 8.0
		_mesh_box(body, Vector3(0.14, 1.0, 0.14), Vector3(cos(a) * r * 1.35, by + 0.7, sin(a) * r * 1.35), "limestone")
	_mesh_cyl(body, r * 1.45, 0.25, Vector3(0, by + 1.3, 0), "concrete", 8)
	_mesh_cyl(body, r * 0.7, h * 0.22, Vector3(0, by + 1.3 + h * 0.11, 0), "limestone", 8)
	var ty: = by + 1.3 + h * 0.22
	var dome: = MeshInstance3D.new()
	var sm: = SphereMesh.new()
	sm.radius = r * 0.85
	sm.height = r * 1.9
	sm.is_hemisphere = false
	dome.mesh = sm
	dome.position = Vector3(0, ty + r * 0.35, 0)
	dome.material_override = mat("dome")
	body.add_child(dome)
	_mesh_cyl(body, 0.08, 1.6, Vector3(0, ty + r * 1.3 + 0.6, 0), "gold", 6)
	var cres: = MeshInstance3D.new()
	cres.mesh = crescent_mesh(0.7, 0.2, 0.15)
	cres.material_override = mat("gold")
	cres.position = Vector3(0, ty + r * 1.3 + 1.7, 0)
	cres.rotation_degrees = Vector3(0, 0, 90)
	body.add_child(cres)
	var cs: = CollisionShape3D.new()
	var shp: = CylinderShape3D.new()
	shp.radius = r
	shp.height = h
	cs.shape = shp
	cs.position = Vector3(0, h * 0.5, 0)
	body.add_child(cs)
	_merge_meshes(body)
	return body


func _cyl_body(p: Dictionary) -> Node3D:
	var t: String = p.t
	var rad: float = p.rad
	var h: float = p.h
	var body: = _new_body(_needs_animatable(p))
	body.position = _v3(p.p)
	var mi: = MeshInstance3D.new()
	var cm: = CylinderMesh.new()
	cm.top_radius = rad
	cm.bottom_radius = rad
	cm.height = h
	cm.radial_segments = 20 if t == "tank" else 14
	mi.mesh = cm
	mi.material_override = mat(p.get("mat", "tank"))
	body.add_child(mi)
	var cs: = CollisionShape3D.new()
	var shp: = CylinderShape3D.new()
	shp.radius = rad
	shp.height = h
	cs.shape = shp
	body.add_child(cs)
	if t == "tire":
		mi.visible = false
		_build_tire(body, rad, h, String(p.get("m", {}).get("style", "")) == "swing")
	elif t == "plaza":
		var rim: = MeshInstance3D.new()
		var tm: = TorusMesh.new()
		tm.inner_radius = rad - 0.12
		tm.outer_radius = rad + 0.06
		tm.rings = 40
		rim.mesh = tm
		rim.position = Vector3(0, h * 0.5 - 0.02, 0)
		rim.material_override = mat("rail" if p.get("mat", "") in ["steel", "metal_panel"] else "concrete")
		body.add_child(rim)
		if p.get("mat", "") == "cloud":
			mi.material_override = cloud_mat()
	if t == "tank":

		for k in 3:
			var rib: = MeshInstance3D.new()
			var tm: = TorusMesh.new()
			tm.inner_radius = rad - 0.02
			tm.outer_radius = rad + 0.05
			tm.rings = 20
			rib.mesh = tm
			rib.position = Vector3(0, - h * 0.35 + k * h * 0.33, 0)
			rib.material_override = mat("tank")
			body.add_child(rib)
		var lid: = MeshInstance3D.new()
		var lm: = CylinderMesh.new()
		lm.top_radius = rad * 0.35
		lm.bottom_radius = rad * 0.35
		lm.height = 0.08
		lid.mesh = lm
		lid.position = Vector3(0, h * 0.5 + 0.02, 0)
		lid.material_override = mat("drum")
		body.add_child(lid)
	return body


func _beam_body(p: Dictionary) -> Node3D:
	var t: String = p.t
	var d: = _v3(p.d)
	var body: = _new_body(false)
	body.position = _v3(p.p)
	body.basis = Basis(Vector3.UP, p.r) * Basis(Vector3.BACK, p.pitch)
	if t != "promenade" and d.z < 1.4 and d.x > d.z * 2.5:
		body.set_meta("beam_w", d.z)
	var mname: String = p.get("mat", "wood")
	if t == "pipe":
		var mi: = MeshInstance3D.new()
		var cm: = CylinderMesh.new()
		cm.top_radius = d.z * 0.5
		cm.bottom_radius = d.z * 0.5
		cm.height = d.x
		cm.radial_segments = 18
		mi.mesh = cm
		mi.rotation.z = PI * 0.5
		mi.material_override = mat(mname)
		body.add_child(mi)
		var cs: = CollisionShape3D.new()
		var shp: = CylinderShape3D.new()
		shp.radius = d.z * 0.5
		shp.height = d.x
		cs.shape = shp
		cs.rotation.z = PI * 0.5
		body.add_child(cs)

		for sgn in [-1.0, 1.0]:
			var fl: = MeshInstance3D.new()
			var fm: = CylinderMesh.new()
			fm.top_radius = d.z * 0.5 + 0.06
			fm.bottom_radius = d.z * 0.5 + 0.06
			fm.height = 0.12
			fl.mesh = fm
			fl.rotation.z = PI * 0.5
			fl.position = Vector3(sgn * (d.x * 0.5 - 0.06), 0, 0)
			fl.material_override = mat("pole")
			body.add_child(fl)
		return body
	var mi2: = MeshInstance3D.new()
	var bm: Mesh = Surf.box(Vector3(d.x, d.y, d.z))
	mi2.mesh = bm
	mi2.material_override = cloud_mat() if mname == "cloud" else mat(mname)
	body.add_child(mi2)
	if t == "promenade":
		_promenade_dressing(body, d, mname, int(absf(p.p[0]) * 10.0))
	var cs2: = CollisionShape3D.new()
	var bs: = BoxShape3D.new()
	bs.size = Vector3(d.x, d.y, d.z)
	cs2.shape = bs
	body.add_child(cs2)
	if mname == "ibeam":

		var web: = MeshInstance3D.new()
		var wm: Mesh = Surf.box(Vector3(d.x, 0.5, 0.08))
		web.mesh = wm
		web.position = Vector3(0, - d.y * 0.5 - 0.25, 0)
		web.material_override = mat(mname)
		body.add_child(web)
		var bot: = MeshInstance3D.new()
		var bbm: Mesh = Surf.box(Vector3(d.x, 0.1, d.z))
		bot.mesh = bbm
		bot.position = Vector3(0, - d.y * 0.5 - 0.55, 0)
		bot.material_override = mat(mname)
		body.add_child(bot)
	elif mname == "rope_bridge":
		for sgn in [-1.0, 1.0]:
			var rope: = MeshInstance3D.new()
			var rm: = CylinderMesh.new()
			rm.top_radius = 0.035
			rm.bottom_radius = 0.035
			rm.height = d.x
			rope.mesh = rm
			rope.rotation.z = PI * 0.5
			rope.position = Vector3(0, 0.9, sgn * (d.z * 0.5 + 0.35))
			rope.material_override = mat("wood")
			body.add_child(rope)
	elif mname == "truss":
		var under: = MeshInstance3D.new()
		var um: Mesh = Surf.box(Vector3(d.x, 0.6, d.z * 0.6))
		under.mesh = um
		under.position = Vector3(0, - d.y * 0.5 - 0.3, 0)
		under.material_override = mat("steel")
		body.add_child(under)
	return body


func _island_body(p: Dictionary) -> Node3D:
	var t: String = p.t
	var rad: float = p.rad
	var depth: float = p.depth
	var sd: int = int(p.get("seed", 1))
	var body: = _new_body(_needs_animatable(p))
	body.position = _v3(p.p)
	if t == "cloud":
		_build_cloud(body, rad, sd)
		_merge_meshes(body)
		var cs: = CollisionShape3D.new()
		var shp: = CylinderShape3D.new()
		shp.radius = rad
		shp.height = 1.2
		cs.shape = shp
		cs.position = Vector3(0, -0.6, 0)
		body.add_child(cs)
		return body
	var rng: = RandomNumberGenerator.new()
	rng.seed = sd
	var top_mat: = "grass"
	var body_mat: = "rock"
	var rough: = 0.18
	match t:
		"asteroid", "planetoid":
			top_mat = "asteroid_top"
			body_mat = "asteroid"
			rough = 0.3
		"moon":
			top_mat = "moon"
			body_mat = "moon"
			rough = 0.08
	var am: = _island_mesh(rad, depth, rng, rough, t == "asteroid")
	var mi: = MeshInstance3D.new()
	mi.mesh = _island_visual(am, rad, sd)
	mi.set_surface_override_material(0, mat(top_mat))
	mi.set_surface_override_material(1, mat(body_mat))
	body.add_child(mi)
	var cs2: = CollisionShape3D.new()
	var tri: = am.create_trimesh_shape()
	tri.backface_collision = true
	cs2.shape = tri
	body.add_child(cs2)
	if t == "island" and rad > 2.2:
		_island_dressing(body, rad, rng)
	if t == "isle_big":
		_isle_big_dressing(body, rad, rng)
	if t == "moon":
		_build_finish(body, rad)
	return body

func _island_mesh(rad: float, depth: float, rng: RandomNumberGenerator, rough: float, round_bottom: bool) -> ArrayMesh:
	var seg: = 14 + int(rad * 2.0)
	var top: = SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim: Array[Vector3] = []
	for i in seg:
		var a: = TAU * float(i) / seg
		var rr: = rad * (1.0 + rng.randf_range(-0.04, 0.06))
		rim.append(Vector3(cos(a) * rr, 0.0, sin(a) * rr))

	top.set_smooth_group(1)
	for i in seg:
		var a0: = rim[i]
		var a1: = rim[(i + 1) % seg]
		top.add_vertex(Vector3.ZERO)
		top.add_vertex(a0)
		top.add_vertex(a1)

	var lip: Array[Vector3] = []
	for i in seg:
		lip.append(rim[i] * 1.03 + Vector3(0, -0.35, 0))
	top.set_smooth_group(2)
	for i in seg:
		var j: = (i + 1) % seg
		_quad(top, rim[i], rim[j], lip[j], lip[i])
	top.generate_normals()
	var body: = SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: = 4
	var prev: = lip
	for k in range(1, rings + 1):
		var f: = float(k) / rings
		var cur: Array[Vector3] = []
		var y: = -0.35 - depth * f
		var shrink: = 1.0 - pow(f, 1.6 if not round_bottom else 2.2) * 0.92
		for i in seg:
			var a: = TAU * float(i) / seg + rng.randf_range(-0.08, 0.08)
			var rr: = rad * shrink * (1.0 + rng.randf_range( - rough, rough))
			cur.append(Vector3(cos(a) * rr, y + rng.randf_range( - rough, rough) * depth * 0.2, sin(a) * rr))
		for i in seg:
			var j: = (i + 1) % seg
			_quad(body, prev[i], prev[j], cur[j], cur[i])
		prev = cur
	var tip: = Vector3(rng.randf_range(-0.3, 0.3), -0.35 - depth * 1.12, rng.randf_range(-0.3, 0.3))
	for i in seg:
		var j: = (i + 1) % seg
		body.add_vertex(prev[i])
		body.add_vertex(prev[j])
		body.add_vertex(tip)
	body.generate_normals()
	var am: = top.commit()
	body.commit(am)
	return am




static var _isle_noise: FastNoiseLite
func _island_visual(am: ArrayMesh, rad: float, seed_: int) -> ArrayMesh:
	if _isle_noise == null:
		_isle_noise = FastNoiseLite.new()
		_isle_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_isle_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		_isle_noise.fractal_octaves = 3
		_isle_noise.frequency = 0.2
	var out: = ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, am.surface_get_arrays(0))
	var src_arr: = am.surface_get_arrays(1)
	var tris: PackedVector3Array = src_arr[Mesh.ARRAY_VERTEX]
	var src_idx = src_arr[Mesh.ARRAY_INDEX]
	if src_idx != null and (src_idx as PackedInt32Array).size() > 0:
		var flat: = PackedVector3Array()
		for i: int in src_idx:
			flat.append(tris[i])
		tris = flat
	var src_n: PackedVector3Array = src_arr[Mesh.ARRAY_NORMAL]
	var ref_n: Vector3 = src_n[src_idx[0] if src_idx != null and (src_idx as PackedInt32Array).size() > 0 else 0] if src_n.size() > 0 else Vector3.DOWN
	var levels: = 1 if Game.mobile else 2
	for l in levels:
		var nt: = PackedVector3Array()
		nt.resize(tris.size() * 4)
		var o: = 0
		for i in range(0, tris.size(), 3):
			var a: = tris[i]
			var b: = tris[i + 1]
			var c: = tris[i + 2]
			var ab: = (a + b) * 0.5
			var bc: = (b + c) * 0.5
			var ca: = (c + a) * 0.5
			for v in [a, ab, ca, ab, b, bc, ca, bc, c, ab, bc, ca]:
				nt[o] = v
				o += 1
		tris = nt
	var idx_of: = {}
	var verts: = PackedVector3Array()
	var indices: = PackedInt32Array()
	indices.resize(tris.size())
	for i in tris.size():
		var v: = tris[i]
		var key: = Vector3i(roundi(v.x * 256.0), roundi(v.y * 256.0), roundi(v.z * 256.0))
		var k: int = idx_of.get(key, -1)
		if k < 0:
			k = verts.size()
			idx_of[key] = k
			verts.append(v)
		indices[i] = k
	var amp: = clampf(rad * 0.06, 0.1, 0.8)
	var off: = Vector3(float(seed_ % 97), float(seed_ % 13), float((seed_ * 7) % 89)) * 3.1
	for i in verts.size():
		var v: = verts[i]
		var w: = clampf(( - v.y - 0.35) / 1.2, 0.0, 1.0)
		var r: = Vector2(v.x, v.z).length()
		if w <= 0.0 or r < 0.05:
			continue
		var q: = v + off
		var n1: = _isle_noise.get_noise_3dv(q)
		var n2: = _isle_noise.get_noise_3dv(q * 3.1 + Vector3(9, 3, 1))
		var strata: = sin((v.y + n1 * 1.4) * 2.6)
		var d: = amp * (n1 * 1.1 + n2 * 0.35 + strata * 0.3) * w * minf(1.0, r / (amp * 3.0))
		verts[i] = v + Vector3(v.x / r, 0.0, v.z / r) * d + Vector3(0, n2 * amp * 0.3 * w, 0)

	var nrm: = PackedVector3Array()
	nrm.resize(verts.size())
	for i in range(0, indices.size(), 3):
		var fa: = verts[indices[i]]
		var fn: = (verts[indices[i + 2]] - fa).cross(verts[indices[i + 1]] - fa)
		nrm[indices[i]] += fn
		nrm[indices[i + 1]] += fn
		nrm[indices[i + 2]] += fn
	var first: = (verts[indices[2]] - verts[indices[0]]).cross(verts[indices[1]] - verts[indices[0]])
	var sg: = -1.0 if first.dot(ref_n) < 0.0 else 1.0
	for i in nrm.size():
		nrm[i] = (nrm[i] * sg).normalized()
	var arr: = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_INDEX] = indices
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void :
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)

func _build_cloud(body: Node3D, rad: float, sd: int) -> void :
	var rng: = RandomNumberGenerator.new()
	rng.seed = sd
	var puffs: = 5 + int(rad * 1.5)
	for i in puffs:
		var a: = rng.randf() * TAU
		var d: = rng.randf_range(0.0, rad * 0.75)
		var r: = rng.randf_range(rad * 0.35, rad * 0.6)
		var sm: = SphereMesh.new()
		sm.radius = r
		sm.height = r * 1.2
		sm.radial_segments = 14
		sm.rings = 8
		var mi: = MeshInstance3D.new()
		mi.mesh = sm
		mi.position = Vector3(cos(a) * d, - r * 0.55 + 0.02, sin(a) * d)
		mi.material_override = cloud_mat()
		body.add_child(mi)

	var top: = MeshInstance3D.new()
	var cm: = CylinderMesh.new()
	cm.top_radius = rad * 0.98
	cm.bottom_radius = rad * 0.8
	cm.height = 0.5
	cm.radial_segments = 20
	top.mesh = cm
	top.position = Vector3(0, -0.24, 0)
	top.material_override = cloud_mat()
	body.add_child(top)

func _island_dressing(body: Node3D, rad: float, rng: RandomNumberGenerator) -> void :

	var n: = int(rad * 2)
	for i in n:
		var a: = rng.randf() * TAU
		var d: = rad * rng.randf_range(0.8, 0.95)
		var key: String = ["medieval/decoration/nature/waterplant_A.gltf", "medieval/decoration/nature/waterplant_B.gltf", "medieval/decoration/nature/waterplant_C.gltf"][rng.randi() % 3]
		var m: Node3D = PR.build(key, 5, rng.randi())
		m.scale = Vector3.ONE * rng.randf_range(2.0, 3.5)
		m.position = Vector3(cos(a) * d, 0.0, sin(a) * d)
		m.rotation.y = rng.randf() * TAU
		body.add_child(m)

func _isle_big_dressing(body: Node3D, rad: float, rng: RandomNumberGenerator) -> void :
	var colors: = ["blue", "green", "red", "yellow"]
	var c: String = colors[rng.randi() % 4]
	var keys: = ["medieval/buildings/%s/building_castle_%s.gltf" % [c, c], "medieval/buildings/%s/building_church_%s.gltf" % [c, c], 
		"medieval/buildings/%s/building_windmill_%s.gltf" % [c, c], "medieval/buildings/%s/building_tower_A_%s.gltf" % [c, c]]
	var main_key: String = keys[rng.randi() % keys.size()]
	var b: Node3D = PR.build(main_key, 5, rng.randi())
	b.scale = Vector3.ONE * rng.randf_range(5.0, 7.0)
	b.rotation.y = rng.randf() * TAU
	body.add_child(b)
	for i in rng.randi_range(3, 6):
		var tr: Node3D = PR.build("medieval/decoration/nature/tree_single_A.gltf", 5, rng.randi())
		var a: = rng.randf() * TAU
		var d: = rng.randf_range(rad * 0.55, rad * 0.85)
		tr.position = Vector3(cos(a) * d, 0, sin(a) * d)
		tr.scale = Vector3.ONE * rng.randf_range(5.0, 8.0)
		body.add_child(tr)

	var a2: = rng.randf() * TAU
	var wf: = MeshInstance3D.new()
	var qm: = QuadMesh.new()
	qm.size = Vector2(rng.randf_range(2.0, 3.5), rad * 3.5)
	wf.mesh = qm
	var wm: = ShaderMaterial.new()
	wm.shader = load("res://shaders/waterfall.gdshader")
	wf.material_override = wm
	wf.position = Vector3(cos(a2) * (rad * 1.02), - qm.size.y * 0.5 + 0.2, sin(a2) * (rad * 1.02))
	wf.rotation.y = - a2 + PI * 0.5
	wf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(wf)

func _st_box(st: SurfaceTool, xf: Transform3D, size: Vector3) -> void :
	var h: = size * 0.5
	var c: = [Vector3( - h.x, - h.y, - h.z), Vector3(h.x, - h.y, - h.z), Vector3(h.x, h.y, - h.z), Vector3( - h.x, h.y, - h.z), 
		Vector3( - h.x, - h.y, h.z), Vector3(h.x, - h.y, h.z), Vector3(h.x, h.y, h.z), Vector3( - h.x, h.y, h.z)]
	var faces: = [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5]]
	st.set_smooth_group(-1)
	for f in faces:
		var a: Vector3 = xf * c[f[0]]
		var b: Vector3 = xf * c[f[1]]
		var cc: Vector3 = xf * c[f[2]]
		var d: Vector3 = xf * c[f[3]]
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(cc)
		st.add_vertex(a)
		st.add_vertex(cc)
		st.add_vertex(d)
	st.set_smooth_group(0)

func _st_beam(st: SurfaceTool, a: Vector3, b: Vector3, t: float) -> void :
	var dvec: = b - a
	var L: = dvec.length()
	if L < 0.001:
		return
	var y: = dvec / L
	var x: = y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z: = x.cross(y)
	var xf: = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	_st_box(st, xf, Vector3(t, L, t))

func _crane_body(p: Dictionary) -> Node3D:
	var body: = StaticBody3D.new()
	body.position = _v3(p.p)
	body.rotation.y = p.r
	var H: float = p.h
	var J: float = p.jib
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w: = 1.8
	var seg: = 3.0
	var n: = int(H / seg)
	var corners: = [Vector3( - w, 0, - w), Vector3(w, 0, - w), Vector3(w, 0, w), Vector3( - w, 0, w)]
	for k in 4:
		_st_beam(st, corners[k], corners[k] + Vector3(0, H, 0), 0.22)
	for i in n + 1:
		var y: = i * seg
		for k in 4:
			var a: Vector3 = corners[k] + Vector3(0, y, 0)
			var b: Vector3 = corners[(k + 1) % 4] + Vector3(0, y, 0)
			_st_beam(st, a, b, 0.14)
			if i < n:
				_st_beam(st, a, corners[(k + 1) % 4] + Vector3(0, y + seg, 0), 0.1)

	var top: = H
	var jn: = int(J / seg)
	for i in jn + 1:
		var x: = i * seg
		_st_beam(st, Vector3(x, top, -0.8), Vector3(x, top, 0.8), 0.12)
		_st_beam(st, Vector3(x, top, -0.8), Vector3(x, top + 1.6, 0), 0.1)
		_st_beam(st, Vector3(x, top, 0.8), Vector3(x, top + 1.6, 0), 0.1)
	_st_beam(st, Vector3(0, top, -0.8), Vector3(J, top, -0.8), 0.18)
	_st_beam(st, Vector3(0, top, 0.8), Vector3(J, top, 0.8), 0.18)
	_st_beam(st, Vector3(0, top + 1.6, 0), Vector3(J, top + 1.6, 0), 0.16)
	_st_beam(st, Vector3(-8, top, -0.8), Vector3(0, top, -0.8), 0.18)
	_st_beam(st, Vector3(-8, top, 0.8), Vector3(0, top, 0.8), 0.18)
	_st_beam(st, Vector3(0, top, 0), Vector3(0, top + 5, 0), 0.25)
	_st_beam(st, Vector3(0, top + 5, 0), Vector3(J * 0.7, top + 1.6, 0), 0.06)
	_st_beam(st, Vector3(0, top + 5, 0), Vector3(-8, top, 0), 0.06)
	st.generate_normals()
	var mi: = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat("ibeam")
	body.add_child(mi)
	_mesh_box(body, Vector3(3.0, 2.2, 2.4), Vector3(-5.5, top - 1.2, 0), "concrete")
	_mesh_box(body, Vector3(2.2, 2.0, 2.0), Vector3(0.8, top - 1.0, 2.0), "window")
	var rng: = RandomNumberGenerator.new()
	rng.seed = int(p.get("seed", 1))
	var hx: = J * rng.randf_range(0.5, 0.9)
	var cable: = rng.randf_range(6.0, 16.0)
	_mesh_box(body, Vector3(0.05, cable, 0.05), Vector3(hx, top - cable * 0.5, 0), "pole")
	_mesh_box(body, Vector3(0.6, 0.5, 0.4), Vector3(hx, top - cable, 0), "pole")
	var ld: Node3D = PR.build("medieval/decoration/props/crate_long_A.gltf", 3, int(p.get("seed", 1)))
	ld.scale = Vector3.ONE * 9.0
	ld.position = Vector3(hx, top - cable - 4.5, 0)
	body.add_child(ld)
	var cs: = CollisionShape3D.new()
	var bs: = BoxShape3D.new()
	bs.size = Vector3(w * 2, H, w * 2)
	cs.shape = bs
	cs.position = Vector3(0, H * 0.5, 0)
	body.add_child(cs)
	var cs2: = CollisionShape3D.new()
	var bs2: = BoxShape3D.new()
	bs2.size = Vector3(J + 8, 1.8, 1.8)
	cs2.shape = bs2
	cs2.position = Vector3((J - 8) * 0.5, top + 0.8, 0)
	body.add_child(cs2)
	_merge_meshes(body)
	return body

func _balloon_body(p: Dictionary) -> Node3D:
	var root: = Node3D.new()
	root.position = _v3(p.p)
	var R: float = p.rad
	var rng: = RandomNumberGenerator.new()
	rng.seed = int(p.get("seed", 1))
	var env: = MeshInstance3D.new()
	var sm: = SphereMesh.new()
	sm.radius = R
	sm.height = R * 2.3
	sm.radial_segments = 36
	sm.rings = 18
	env.mesh = sm
	var m: = ShaderMaterial.new()
	m.shader = load("res://shaders/balloon.gdshader")
	var palettes: = [[Color(0.95, 0.3, 0.25), Color(1.0, 0.85, 0.3), Color(0.2, 0.55, 0.85)], 
		[Color(0.2, 0.6, 0.35), Color(0.95, 0.95, 0.9), Color(0.85, 0.2, 0.2)], 
		[Color(0.55, 0.3, 0.75), Color(1.0, 0.6, 0.2), Color(0.95, 0.9, 0.8)]]
	var pal: Array = palettes[rng.randi() % palettes.size()]
	m.set_shader_parameter("c1", pal[0])
	m.set_shader_parameter("c2", pal[1])
	m.set_shader_parameter("c3", pal[2])
	env.material_override = m
	root.add_child(env)
	_mesh_box(root, Vector3(1.6, 1.1, 1.6), Vector3(0, - R * 1.15 - 3.2, 0), "wood")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var a: = Vector3(sx * 0.7, - R * 1.15 - 2.7, sz * 0.7)
			var b: = Vector3(sx * R * 0.45, - R * 1.0, sz * R * 0.45)
			var st: = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_st_beam(st, a, b, 0.05)
			st.generate_normals()
			var mi: = MeshInstance3D.new()
			mi.mesh = st.commit()
			mi.material_override = mat("olive_trunk")
			root.add_child(mi)
	root.set_script(load("res://scripts/mech/bob.gd"))
	root.set("amp", rng.randf_range(0.6, 1.4))
	root.set("speed", rng.randf_range(0.2, 0.4))
	return root

func _build_finish(body: Node3D, rad: float) -> void :

	var cres: = MeshInstance3D.new()
	cres.mesh = crescent_mesh(5.5, 0.8, 0.9)
	var m: = StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.92, 0.7)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.82, 0.45)
	m.emission_energy_multiplier = 1.6
	m.roughness = 0.4
	cres.material_override = m
	cres.position = Vector3(0, 8.0, - rad * 0.35)
	cres.rotation_degrees = Vector3(0, 0, -25)
	cres.name = "Crescent"
	body.add_child(cres)
	var star: = MeshInstance3D.new()
	var sm: = SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.4
	star.mesh = sm
	star.material_override = m
	star.position = Vector3(2.6, 9.6, - rad * 0.35)
	body.add_child(star)
	var light: = OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.6)
	light.light_energy = 2.5
	light.omni_range = 28.0
	light.position = Vector3(0, 6, 0)
	body.add_child(light)

	var lan_key: = "halloween/lantern_standing.gltf"
	if true:
		for i in 8:
			var a: = TAU * i / 8.0
			var l: Node3D = PR.build(lan_key, 6, i)
			l.scale = Vector3.ONE * 0.75
			l.position = Vector3(cos(a) * (rad - 0.5), 0.0, sin(a) * (rad - 0.5))
			body.add_child(l)
			var ll: = OmniLight3D.new()
			ll.light_color = Color(1.0, 0.7, 0.35)
			ll.light_energy = 1.2
			ll.omni_range = 5.0
			ll.position = l.position + Vector3(0, 0.9, 0)
			body.add_child(ll)

func crescent_mesh(R: float, thick: float, depth: float) -> ArrayMesh:

	var r2: = R * 0.84
	var off: = R * 0.42
	var pts: Array[Vector2] = []
	var n: = 64

	var x_int: = (R * R - r2 * r2 + off * off) / (2.0 * off)
	var y_int: = sqrt(max(R * R - x_int * x_int, 0.0))
	var a0: = atan2(y_int, x_int)
	for i in n + 1:
		var a: float = lerp(a0, TAU - a0, float(i) / n)
		pts.append(Vector2(cos(a) * R, sin(a) * R))
	var b0: = atan2(y_int, x_int - off)
	for i in n + 1:
		var a: float = lerp(TAU - b0, b0, float(i) / n)
		pts.append(Vector2(off + cos(a) * r2, sin(a) * r2))
	var tris: = Geometry2D.triangulate_polygon(PackedVector2Array(pts))
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hz: = depth * 0.5
	st.set_smooth_group(1)
	for k in range(0, tris.size(), 3):
		var p0: = pts[tris[k]]
		var p1: = pts[tris[k + 1]]
		var p2: = pts[tris[k + 2]]
		st.add_vertex(Vector3(p0.x, p0.y, hz))
		st.add_vertex(Vector3(p1.x, p1.y, hz))
		st.add_vertex(Vector3(p2.x, p2.y, hz))
		st.add_vertex(Vector3(p0.x, p0.y, - hz))
		st.add_vertex(Vector3(p2.x, p2.y, - hz))
		st.add_vertex(Vector3(p1.x, p1.y, - hz))
	var m: = pts.size()
	st.set_smooth_group(2)
	for i in m:
		var a: = pts[i]
		var b: = pts[(i + 1) % m]
		st.add_vertex(Vector3(a.x, a.y, hz))
		st.add_vertex(Vector3(a.x, a.y, - hz))
		st.add_vertex(Vector3(b.x, b.y, - hz))
		st.add_vertex(Vector3(a.x, a.y, hz))
		st.add_vertex(Vector3(b.x, b.y, - hz))
		st.add_vertex(Vector3(b.x, b.y, hz))
	st.generate_normals()
	var mesh: = st.commit()
	return mesh

func _hub_sign(body: Node3D, p: Dictionary) -> void :
	var zid: = int(p.z)
	var zname: = ""
	for z in zones:
		if int(z.id) == zid:
			zname = z.name
	var lbl: = Label3D.new()
	lbl.text = zname
	lbl.font = load("res://assets/fonts/Lalezar.ttf")
	lbl.font_size = 220
	lbl.pixel_size = 0.012
	lbl.outline_size = 36
	lbl.outline_modulate = Color(0.1, 0.08, 0.05, 0.9)
	lbl.modulate = Color(1.0, 0.82, 0.4)
	lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	lbl.double_sided = true
	lbl.no_depth_test = false
	var top: = _piece_top(p)
	lbl.position = Vector3(0, top - body.position.y + 5.5, 0)
	body.add_child(lbl)


func node_idx(old: int) -> int:

	return int(oid_map.get(old, old))

func _attach_mech(body: Node3D, p: Dictionary, mech: Dictionary) -> void :
	if p.t == "ch":
		return
	match mech.type:
		"zipline":
			_build_zipline(body, _v3(mech.a), _v3(mech.b))
		"move":
			var sc: = load("res://scripts/mech/mover.gd")
			body.set_script(sc)
			body.set("base", body.position)
			body.set("offset", _v3(mech.b))
			body.set("period", float(mech.period))
			body.set("phase", float(mech.phase))
		"crumble":
			body.set_script(load("res://scripts/mech/crumble.gd"))
			body.set("delay", float(mech.get("delay", 0.7)))
			body.set("respawn", float(mech.get("respawn", 3.5)))
		"bounce" when String(mech.get("style", "")) == "swing":

			var sw: = Node3D.new()
			sw.name = "Swing"
			sw.set_script(load("res://scripts/mech/swing.gd"))
			sw.set("to", _v3(mech.to))
			sw.set("pad_r", float(p.get("rad", 1.3)))
			sw.set("builder", self)
			sw.position = Vector3(0, _piece_top(p) - body.position.y, 0)
			body.add_child(sw)
		"bounce":
			body.set_meta("bounce", float(mech.v))
			body.set_script(load("res://scripts/mech/bounce_pad.gd"))
		"updraft" when String(mech.get("style", "")) == "bike":

			var bk: = Node3D.new()
			bk.name = "Bike"
			bk.set_script(load("res://scripts/mech/bike_ride.gd"))
			bk.set("path", mech.path)
			bk.set("center", _v3(mech.center))
			bk.set("to", _v3(mech.to))
			bk.set("height", float(mech.h))
			bk.set("builder", self)
			bk.position = Vector3(0, _piece_top(p) - body.position.y, 0)
			body.add_child(bk)
		"updraft" when String(mech.get("style", "")) in ["eagle", "elevator", "kite"]:

			var st: = String(mech.style)
			var nd: = Node3D.new()
			nd.name = {"eagle": "Eagle", "elevator": "Elevator", "kite": "Kite"}[st]
			nd.set_script(load("res://scripts/mech/%s.gd" % {"eagle": "eagle_lift", "elevator": "elevator", "kite": "kite_lift"}[st]))
			nd.set("height", float(mech.h))
			nd.set("to", _v3(mech.to))
			nd.set("radius", float(mech.rad))
			var top2: = _piece_top(p)
			nd.position = Vector3(0, top2 - body.position.y, 0)
			body.add_child(nd)
		"updraft":
			var up: = Area3D.new()
			up.set_script(load("res://scripts/mech/updraft.gd"))
			up.set("height", float(mech.h))
			up.set("radius", float(mech.rad))
			up.set("speed", float(mech.v))
			var top: = _piece_top(p)
			up.position = Vector3(0, top - body.position.y, 0)
			body.add_child(up)
		"wind":
			var wz: = Area3D.new()
			wz.set_script(load("res://scripts/mech/wind_zone.gd"))
			var d: = _v3(p.d)
			wz.set("size", Vector3(d.x + 2.0, 4.5, max(d.z, 1.0) + 6.0))
			wz.set("wind_dir", Vector3(mech.dir[0], 0, mech.dir[1]))
			wz.set("strength", float(mech.strength))
			wz.set("period", float(mech.period))
			body.add_child(wz)

func _build_zipline(body: Node3D, a: Vector3, b: Vector3) -> void :
	var root: = Node3D.new()
	root.top_level = true
	root.name = "Zipline"
	body.add_child(root)
	root.global_transform = Transform3D.IDENTITY
	var sb: = StaticBody3D.new()
	root.add_child(sb)
	for pt in [[a, 3.2], [b, 3.0]]:
		var top: Vector3 = pt[0]
		var hgt: float = pt[1] + 0.4
		var pole: = _mesh_cyl(sb, 0.13, hgt, top + Vector3(0, 0.4 - hgt * 0.5, 0), "ibeam", 10)
		pole.name = "Pole"
		var cs: = CollisionShape3D.new()
		var cyl: = CylinderShape3D.new()
		cyl.radius = 0.13
		cyl.height = hgt
		cs.shape = cyl
		cs.position = pole.position
		sb.add_child(cs)
		_mesh_box(sb, Vector3(0.5, 0.18, 0.5), top + Vector3(0, 0.1, 0), "rail")
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_st_beam(st, a, b, 0.05)
	st.generate_normals()
	var cable: = MeshInstance3D.new()
	cable.mesh = st.commit()
	cable.material_override = mat("pole")
	root.add_child(cable)

	var u: = (b - a).normalized()
	var hpos: = a + u * 1.3
	var handle: = Node3D.new()
	handle.position = hpos
	root.add_child(handle)
	var st2: = SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	_st_beam(st2, Vector3.ZERO, Vector3(0, -1.0, 0), 0.04)
	var side: = u.cross(Vector3.UP).normalized()
	_st_beam(st2, Vector3(0, -1.0, 0) - side * 0.35, Vector3(0, -1.0, 0) + side * 0.35, 0.07)
	st2.generate_normals()
	var hm: = MeshInstance3D.new()
	hm.mesh = st2.commit()
	hm.material_override = mat("ibeam")
	handle.add_child(hm)
	var area: = Area3D.new()
	area.set_script(load("res://scripts/mech/zip_grab.gd"))
	area.set("a", a)
	area.set("b", b)
	area.position = hpos + Vector3(0, -1.15, 0)
	root.add_child(area)

func _piece_top(p: Dictionary) -> float:
	var pos: = _v3(p.p)
	if p.has("d"):
		return pos.y + float(p.d[1]) * 0.5
	if p.has("h"):
		return pos.y + float(p.h) * 0.5
	return pos.y


func zone_at(y: float) -> int:
	var zid: = 1
	for z in zones:
		if y >= float(z.y0) - 2.0:
			zid = int(z.id)
	return zid
