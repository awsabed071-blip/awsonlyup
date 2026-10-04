extends RefCounted
# Realistic replacements for the kit props the route refers to by name. Every builder fills the
# same bounding box the original prop had (measured at scale 1), so the climb stays identical.
# Models are built from the surface library materials (level_builder.mat) and merged per material.

var B
var _rng: = RandomNumberGenerator.new()

# measured boxes at scale 1: key -> [min, size]
const DIMS: = {
	"city/building_A.gltf": [[-1.0, 0.0, -1.0], [2.0, 1.65, 2.0]], "city/building_A_withoutBase.gltf": [[-0.6, 0.1, -0.65], [1.21, 1.55, 1.45]], 
	"city/building_B.gltf": [[-1.0, 0.0, -1.0], [2.0, 1.65, 2.0]], "city/building_C.gltf": [[-1.0, 0.0, -1.0], [2.0, 2.98, 2.0]], 
	"city/building_D.gltf": [[-1.0, 0.0, -1.0], [2.0, 2.97, 2.02]], "city/building_E.gltf": [[-1.0, 0.0, -1.0], [2.01, 2.35, 2.0]], 
	"city/building_F.gltf": [[-1.0, 0.0, -1.0], [2.01, 2.35, 2.0]], "city/building_H.gltf": [[-1.0, 0.0, -1.0], [2.01, 3.05, 2.0]], 
	"city/road_junction.gltf": [[-1.0, 0.0, -1.0], [2.0, 0.1, 2.0]], "city/road_straight.gltf": [[-1.0, 0.0, -1.0], [2.0, 0.1, 2.0]], 
	"furniture/bed_double_A.gltf": [[-1.55, 0.0, -1.5], [3.1, 1.0, 3.0]], "furniture/book_set.gltf": [[-0.39, -0.25, -0.18], [0.78, 0.5, 0.36]], 
	"furniture/cabinet_small.gltf": [[-0.5, 0.0, -0.5], [1.0, 1.0, 1.0]], "furniture/chair_A.gltf": [[-0.38, 0.0, -0.47], [0.75, 1.26, 0.85]], 
	"furniture/lamp_standing.gltf": [[-0.5, 0.0, -0.5], [1.0, 2.52, 1.0]], "furniture/pictureframe_large_A.gltf": [[-0.5, -0.6, 0.0], [1.01, 1.2, 0.2]], 
	"furniture/shelf_B_large_decorated.gltf": [[-1.0, -0.1, 0.0], [2.0, 0.82, 0.5]], "furniture/table_low.gltf": [[-1.2, 0.0, -0.75], [2.4, 0.5, 1.5]], 
	"furniture/table_medium.gltf": [[-1.0, 0.0, -1.0], [2.0, 1.0, 2.0]], "furniture/table_small.gltf": [[-0.5, 0.0, -0.5], [1.0, 1.0, 1.0]], 
	"furniture/rug_rectangle_stripes_A.gltf": [[-1.5, 0.0, -1.0], [3.0, 0.04, 2.0]], "furniture/rug_oval_A.gltf": [[-1.0, 0.0, -0.7], [2.0, 0.04, 1.4]], 
	"furniture/chair_A_wood.gltf": [[-0.38, 0.0, -0.47], [0.75, 1.26, 0.85]], "furniture/bed_single_A.gltf": [[-0.8, 0.0, -1.5], [1.6, 1.0, 3.0]], 
	"furniture/pillow_A.gltf": [[-0.35, 0.0, -0.25], [0.7, 0.2, 0.5]], "furniture/armchair.gltf": [[-0.6, 0.0, -0.6], [1.2, 1.1, 1.2]], 
	"furniture/pictureframe_standing_A.gltf": [[-0.3, 0.0, -0.1], [0.6, 0.8, 0.2]], 
	"halloween/bench.gltf": [[-0.9, 0.0, -0.35], [1.8, 0.95, 0.7]], "halloween/lantern_standing.gltf": [[-0.2, 0.0, -0.2], [0.4, 1.6, 0.4]], 
	"medieval/decoration/props/crate_long_A.gltf": [[-0.5, 0.0, -0.25], [1.0, 0.5, 0.5]], 
	"medieval/decoration/nature/waterplant_A.gltf": [[-0.3, 0.0, -0.3], [0.6, 0.9, 0.6]], "medieval/decoration/nature/waterplant_B.gltf": [[-0.3, 0.0, -0.3], [0.6, 0.7, 0.6]], 
	"medieval/decoration/nature/waterplant_C.gltf": [[-0.3, 0.0, -0.3], [0.6, 0.8, 0.6]], 
	"medieval/buildings/blue/building_church_blue.gltf": [[-0.51, 0.0, -0.56], [1.03, 1.65, 1.16]], "medieval/buildings/blue/building_home_A_blue.gltf": [[-0.4, 0.0, -0.47], [0.79, 0.93, 0.85]], 
	"medieval/buildings/blue/building_home_B_blue.gltf": [[-0.44, 0.0, -0.54], [0.87, 1.28, 1.1]], "medieval/buildings/blue/building_tower_A_blue.gltf": [[-0.5, 0.0, -0.57], [0.99, 2.19, 1.15]], 
	"medieval/buildings/blue/building_well_blue.gltf": [[-0.31, 0.0, -0.38], [0.65, 0.83, 0.75]], "medieval/buildings/blue/building_windmill_blue.gltf": [[-0.56, -0.5, -0.38], [1.13, 1.19, 0.79]], 
	"medieval/buildings/green/building_castle_green.gltf": [[-0.99, 0.0, -1.13], [1.98, 3.98, 2.26]], "medieval/buildings/green/building_church_green.gltf": [[-0.51, 0.0, -0.56], [1.03, 1.65, 1.16]], 
	"medieval/buildings/green/building_home_B_green.gltf": [[-0.44, 0.0, -0.54], [0.87, 1.28, 1.1]], "medieval/buildings/green/building_tavern_green.gltf": [[-0.59, 0.0, -0.7], [1.17, 1.4, 1.33]], 
	"medieval/buildings/green/building_tower_A_green.gltf": [[-0.5, 0.0, -0.57], [0.99, 2.19, 1.15]], "medieval/buildings/green/building_windmill_green.gltf": [[-0.56, -0.5, -0.38], [1.13, 1.19, 0.79]], 
	"medieval/buildings/neutral/building_scaffolding.gltf": [[-0.93, 0.0, -1.09], [1.9, 1.3, 2.11]], "medieval/buildings/red/building_castle_red.gltf": [[-0.99, 0.0, -1.13], [1.98, 3.98, 2.26]], 
	"medieval/buildings/red/building_church_red.gltf": [[-0.51, 0.0, -0.56], [1.03, 1.65, 1.16]], "medieval/buildings/red/building_market_red.gltf": [[-0.9, -0.01, -0.71], [1.8, 0.98, 1.32]], 
	"medieval/buildings/red/building_tower_A_red.gltf": [[-0.5, 0.0, -0.57], [0.99, 2.19, 1.15]], "medieval/buildings/red/building_well_red.gltf": [[-0.31, 0.0, -0.38], [0.65, 0.83, 0.75]], 
	"medieval/buildings/red/building_windmill_red.gltf": [[-0.56, -0.5, -0.38], [1.13, 1.19, 0.79]], "medieval/buildings/yellow/building_castle_yellow.gltf": [[-0.99, 0.0, -1.13], [1.98, 3.98, 2.26]], 
	"medieval/buildings/yellow/building_church_yellow.gltf": [[-0.51, 0.0, -0.56], [1.03, 1.65, 1.16]], "medieval/buildings/yellow/building_tower_A_yellow.gltf": [[-0.5, 0.0, -0.57], [0.99, 2.19, 1.15]], 
	"medieval/buildings/yellow/building_well_yellow.gltf": [[-0.31, 0.0, -0.38], [0.65, 0.83, 0.75]], "medieval/buildings/yellow/building_windmill_yellow.gltf": [[-0.56, -0.5, -0.38], [1.13, 1.19, 0.79]], 
	"medieval/decoration/nature/cloud_small.gltf": [[-1.16, -0.91, -0.96], [2.34, 1.84, 1.79]], "medieval/decoration/nature/rock_single_A.gltf": [[-0.15, 0.0, -0.16], [0.3, 0.07, 0.28]], 
	"medieval/decoration/nature/tree_single_A.gltf": [[-0.29, -0.1, -0.3], [0.57, 1.2, 0.55]], "medieval/decoration/nature/tree_single_B.gltf": [[-0.29, -0.1, -0.3], [0.57, 1.2, 0.55]], 
	"medieval/decoration/nature/trees_A_large.gltf": [[-0.97, -0.01, -0.99], [1.95, 0.93, 1.97]], "medieval/decoration/nature/trees_B_large.gltf": [[-0.91, -0.02, -0.99], [1.85, 1.17, 1.93]], 
	"medieval/tiles/base/hex_grass.gltf": [[-1.0, -1.0, -1.15], [2.0, 1.0, 2.31]], "medieval/tiles/base/hex_grass_bottom.gltf": [[-1.0, -1.0, -1.15], [2.0, 1.0, 2.31]], 
	"proto/Box_C.gltf": [[-0.4, 0.0, -0.3], [0.8, 0.4, 0.61]], "proto/Cube_Prototype_Large_A.gltf": [[-2.0, 0.0, -2.0], [4.0, 4.0, 4.0]], 
	"proto/Cube_Prototype_Large_B.gltf": [[-2.0, 0.0, -2.0], [4.0, 4.0, 4.0]], "proto/Floor_Prototype.gltf": [[-2.0, 0.0, -2.0], [4.0, 0.5, 4.0]], 
	"proto/Primitive_Floor.gltf": [[-2.0, 0.0, -2.0], [4.0, 1.0, 4.0]], "proto/table_medium.gltf": [[-1.0, 0.0, -0.75], [2.0, 0.8, 1.5]], 
	"restaurant/cuttingboard.gltf": [[-0.75, 0.0, -0.5], [1.5, 0.15, 1.0]], "restaurant/food_burger.gltf": [[-0.47, 0.0, -0.47], [0.95, 0.86, 0.95]], 
	"restaurant/kitchencounter_straight_A.gltf": [[-1.0, 0.0, -1.0], [2.0, 1.0, 2.04]], "restaurant/kitchentable_A.gltf": [[-1.0, 0.0, -1.0], [2.0, 1.0, 2.0]], 
	"restaurant/table_round_A.gltf": [[-1.5, 0.0, -1.5], [3.0, 1.0, 3.0]], 
	"space/basemodule_A.gltf": [[-1.18, 0.0, -1.0], [2.25, 1.0, 2.18]], "space/basemodule_B.gltf": [[-1.04, 0.0, -1.11], [2.08, 1.0, 2.32]], 
	"space/basemodule_E.gltf": [[-1.11, 0.0, -1.07], [2.22, 1.65, 2.28]], "space/basemodule_garage.gltf": [[-1.0, 0.0, -1.1], [2.0, 1.0, 2.37]], 
	"space/containers_A.gltf": [[-0.25, 0.0, -0.25], [0.5, 0.2, 0.5]], "space/drill_structure.gltf": [[-0.88, -0.87, -0.88], [1.75, 2.87, 1.75]], 
	"space/lander_A.gltf": [[-0.67, 0.0, -0.67], [1.37, 1.19, 1.42]], "space/lander_B.gltf": [[-0.67, 0.0, -0.67], [1.37, 1.1, 1.42]], 
	"space/landingpad_large.gltf": [[-1.25, 0.0, -1.25], [2.5, 0.5, 2.5]], "space/landingpad_small.gltf": [[-0.95, 0.0, -0.95], [1.9, 0.5, 1.9]], 
	"space/roofmodule_base.gltf": [[-0.7, -0.1, -0.7], [1.4, 0.2, 1.4]], "space/spacetruck_large.gltf": [[-0.24, -0.11, -0.57], [0.49, 0.67, 1.03]], 
	"space/structure_tall.gltf": [[-0.88, 0.0, -0.88], [1.75, 2.0, 1.75]], "space/terrain_tall.gltf": [[-1.0, -1.0, -1.0], [2.0, 2.0, 2.0]], 
	"space/windturbine_tall.gltf": [[-0.83, -0.49, -0.55], [1.67, 2.21, 1.0]], 
}
const PROTO_BY_ZONE: = ["limestone", "concrete", "steel_deck", "plaster", "rock", "metal_panel"]

func _init(builder) -> void :
	B = builder

func has(key: String) -> bool:
	return DIMS.has(key)

# ---- small helpers (unit space) ----
func _box(p: Node3D, size: Vector3, c: Vector3, m: String, rot_y: = 0.0) -> MeshInstance3D:
	return B._mesh_box(p, size, c, m, rot_y)

func _cyl(p: Node3D, r: float, h: float, c: Vector3, m: String, segs: = 16, r_top: = -1.0) -> MeshInstance3D:
	return B._mesh_cyl(p, r, h, c, m, segs, r_top)

func _sphere(p: Node3D, r: float, c: Vector3, m: String, sc: = Vector3.ONE, segs: = 12) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	var sm: = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = segs
	sm.rings = int(segs / 2)
	mi.mesh = sm
	mi.position = c
	mi.scale = sc
	mi.material_override = B.mat(m)
	p.add_child(mi)
	return mi

func _dome(p: Node3D, r: float, c: Vector3, m: String) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	var sm: = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.is_hemisphere = true
	sm.radial_segments = 20
	sm.rings = 8
	mi.mesh = sm
	mi.position = c
	mi.material_override = B.mat(m)
	p.add_child(mi)
	return mi

func _beam(p: Node3D, a: Vector3, b: Vector3, t: float, m: String) -> MeshInstance3D:
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	B._st_beam(st, a, b, t)
	st.generate_normals()
	var mi: = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = B.mat(m)
	p.add_child(mi)
	return mi

func _rock(p: Node3D, rad: float, depth: float, c: Vector3, top_m: String, body_m: String, seed_: int, rough: = 0.22) -> MeshInstance3D:
	var rng: = RandomNumberGenerator.new()
	rng.seed = seed_
	var am: ArrayMesh = B._island_mesh(rad, depth, rng, rough, false)
	var mi: = MeshInstance3D.new()
	mi.mesh = B._island_visual(am, rad, seed_)
	mi.set_surface_override_material(0, B.mat(top_m))
	mi.set_surface_override_material(1, B.mat(body_m))
	mi.position = c
	p.add_child(mi)
	return mi

func _window(p: Node3D, c: Vector3, w: float, h: float, side: int, lit: bool, rng: RandomNumberGenerator) -> void :
	# a recessed window on one of four sides (0 +z, 1 +x, 2 -z, 3 -x)
	var m: = ("window_lit%d" % rng.randi_range(0, 4)) if lit else "window"
	var a: = side * PI * 0.5
	var mi: = _box(p, Vector3(w, h, 0.06), Vector3.ZERO, m)
	mi.position = c
	mi.rotation.y = a
	var fr: = _box(p, Vector3(w + 0.1, h + 0.1, 0.03), Vector3.ZERO, "limestone")
	fr.position = c - Vector3(sin(a), 0, cos(a)) * 0.02
	fr.rotation.y = a
	if rng.randf() < 0.5:
		for s2 in [-1.0, 1.0]:
			var sh: = _box(p, Vector3(w * 0.45, h + 0.04, 0.03), Vector3.ZERO, "shutter")
			sh.position = c + Vector3(cos(a), 0, - sin(a)) * s2 * (w * 0.5 + w * 0.24) + Vector3(sin(a), 0, cos(a)) * 0.02
			sh.rotation.y = a

func _stone_house(p: Node3D, size: Vector3, seed_: int, dome: bool, floors: int, lit: = true) -> void :
	# Levantine stone house: ashlar walls, flat roof with a parapet, a dome, arched door, shutters
	var rng: = RandomNumberGenerator.new()
	rng.seed = seed_
	var hy: = size.y * 0.5
	_box(p, Vector3(size.x, size.y, size.z), Vector3(0, hy, 0), "limestone")
	var par: = 0.08 * minf(size.x, 2.0)
	for sx in [-1.0, 1.0]:
		_box(p, Vector3(par, par * 2.5, size.z), Vector3(sx * (size.x * 0.5 - par * 0.5), size.y + par * 1.25, 0), "limestone")
	for sz in [-1.0, 1.0]:
		_box(p, Vector3(size.x, par * 2.5, par), Vector3(0, size.y + par * 1.25, sz * (size.z * 0.5 - par * 0.5)), "limestone")
	var fh: = size.y / floors
	for f in range(1, floors):
		_box(p, Vector3(size.x + 0.04, 0.05, size.z + 0.04), Vector3(0, f * fh, 0), "concrete")
	for side in 4:
		var along: = size.x if side % 2 == 0 else size.z
		var depth: = size.z if side % 2 == 0 else size.x
		var n: = maxi(1, int(along / 0.9))
		for f in floors:
			for k in n:
				var u: = - along * 0.5 + along * (k + 0.5) / n
				var y: = f * fh + fh * 0.55
				var a: = side * PI * 0.5
				var pos: = Vector3(u * cos(a) + (depth * 0.5 + 0.02) * sin(a), y, - u * sin(a) + (depth * 0.5 + 0.02) * cos(a))
				if f == 0 and side == 0 and k == int(n / 2):
					var door: = _box(p, Vector3(0.3 * minf(size.x, 2.0), fh * 0.75, 0.05), Vector3.ZERO, "door")
					door.position = Vector3(pos.x, fh * 0.38, pos.z)
					door.rotation.y = a
					var arch: = _cyl(p, 0.15 * minf(size.x, 2.0), 0.06, Vector3.ZERO, "limestone", 12)
					arch.position = Vector3(pos.x, fh * 0.76, pos.z)
					arch.rotation = Vector3(PI * 0.5, a, 0)
					continue
				if rng.randf() < 0.75:
					_window(p, pos, 0.22 * minf(size.x, 2.0), fh * 0.42, side, lit and rng.randf() < 0.7, rng)
	if dome:
		_dome(p, minf(size.x, size.z) * 0.3, Vector3(0, size.y, 0), "plaster")
	# water tank, a vent, some bricks on the roof
	if size.x > 0.7:
		_cyl(p, 0.09 * size.x, 0.18 * size.x, Vector3(size.x * 0.28, size.y + 0.09 * size.x, - size.z * 0.25), "tank", 14)
	_box(p, Vector3(0.1, 0.25 * fh, 0.1), Vector3( - size.x * 0.3, size.y + 0.12 * fh, size.z * 0.25), "concrete")

func _olive(p: Node3D, c: Vector3, h: float, r: float, seed_: int) -> void :
	var rng: = RandomNumberGenerator.new()
	rng.seed = seed_
	var tr: = _cyl(p, r * 0.13, h * 0.5, c + Vector3(0, h * 0.25, 0), "olive_trunk", 7, r * 0.08)
	tr.rotation.z = rng.randf_range(-0.15, 0.15)
	for i in 3:
		var br: = _cyl(p, r * 0.06, h * 0.35, c + Vector3(rng.randf_range( - r * 0.15, r * 0.15), h * 0.52, rng.randf_range( - r * 0.15, r * 0.15)), "olive_trunk", 5, r * 0.03)
		br.rotation = Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
	for i in rng.randi_range(5, 7):
		var a: = rng.randf() * TAU
		var d: = rng.randf_range(0.0, r * 0.55)
		var rr: = rng.randf_range(r * 0.42, r * 0.62)
		_sphere(p, rr, c + Vector3(cos(a) * d, h * 0.7 + rng.randf_range( - h * 0.1, h * 0.15), sin(a) * d), "olive_leaf", Vector3(1.0, 0.7, 1.0), 10)

func _lattice_tower(p: Node3D, w: float, h: float, m: String, seg: float) -> void :
	var pairs: = []
	var corners: = [Vector3( - w, 0, - w), Vector3(w, 0, - w), Vector3(w, 0, w), Vector3( - w, 0, w)]
	for k in 4:
		pairs.append([corners[k], corners[k] + Vector3(0, h, 0)])
	var n: = maxi(1, int(h / seg))
	for i in n + 1:
		var y: = minf(i * seg, h)
		for k in 4:
			var a: Vector3 = corners[k] + Vector3(0, y, 0)
			var b: Vector3 = corners[(k + 1) % 4] + Vector3(0, y, 0)
			pairs.append([a, b])
			if i < n:
				pairs.append([a, corners[(k + 1) % 4] + Vector3(0, minf(y + seg, h), 0)])
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pr in pairs:
		B._st_beam(st, pr[0], pr[1], w * 0.12)
	st.generate_normals()
	var mi: = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = B.mat(m)
	p.add_child(mi)


# ---- the builder ----
func build(key: String, zone: int, seed_: int) -> Node3D:
	var model: = Node3D.new()
	model.name = "Model"
	if not DIMS.has(key):
		return model
	var d: Array = DIMS[key]
	var mn: = Vector3(d[0][0], d[0][1], d[0][2])
	var sz: = Vector3(d[1][0], d[1][1], d[1][2])
	var c: = mn + sz * 0.5
	_rng.seed = seed_
	var rng: = _rng
	var base: = key.get_file().get_basename()
	if key.begins_with("medieval/tiles/base/hex"):
		_rock(model, 1.12, 0.95, Vector3(0, 0, 0), "grass", "rock", seed_)
		if rng.randf() < 0.5:
			_sphere(model, 0.18, Vector3(rng.randf_range(-0.5, 0.5), 0.05, rng.randf_range(-0.5, 0.5)), "rock", Vector3(1.4, 0.6, 1.1), 8)
	elif key.begins_with("proto/Cube"):
		var mname: String = PROTO_BY_ZONE[clampi(zone - 1, 0, 5)]
		if base.ends_with("B"):
			mname = "concrete" if zone <= 2 else mname
		_box(model, sz, c, mname)
		if zone >= 2 and zone <= 3:
			for k in 2:
				_box(model, Vector3(sz.x + 0.04, 0.12, sz.z + 0.04), Vector3(c.x, mn.y + sz.y * (0.33 + k * 0.33), c.z), "ibeam")
	elif key.begins_with("proto/Floor") or key.begins_with("proto/Primitive"):
		var mname: String = PROTO_BY_ZONE[clampi(zone - 1, 0, 5)]
		_box(model, sz, c, mname)
		_box(model, Vector3(sz.x + 0.06, sz.y * 0.35, sz.z + 0.06), Vector3(c.x, mn.y + sz.y * 0.175, c.z), "concrete" if zone != 4 else "plaster")
	elif key.begins_with("proto/Box_C") or key.ends_with("crate_long_A.gltf"):
		_box(model, sz, c, "wood")
		for sx in [-1.0, 1.0]:
			_box(model, Vector3(0.05, sz.y + 0.01, sz.z + 0.02), c + Vector3(sx * (sz.x * 0.5 - 0.04), 0, 0), "olive_trunk")
		_box(model, Vector3(sz.x + 0.02, 0.05, sz.z + 0.02), c + Vector3(0, sz.y * 0.5 - 0.02, 0), "olive_trunk")
	elif key.begins_with("city/road"):
		_box(model, Vector3(sz.x, sz.y, sz.z), c, "asphalt")
		for sx in [-1.0, 1.0]:
			_box(model, Vector3(0.14, sz.y + 0.04, sz.z), c + Vector3(sx * (sz.x * 0.5 - 0.07), 0.02, 0), "sidewalk")
		if base == "road_straight":
			for k in 3:
				_box(model, Vector3(0.06, 0.005, 0.4), Vector3(0, sz.y + 0.003, - 0.7 + k * 0.7), "paint_white")
		else:
			for k in 4:
				_box(model, Vector3(0.35, 0.005, 0.06), Vector3(-0.6 + k * 0.4, sz.y + 0.003, 0.0), "paint_white")
	elif key.begins_with("city/building"):
		var floors: = maxi(1, int(round(sz.y / 0.75)))
		_stone_house(model, Vector3(sz.x * 0.96, sz.y, sz.z * 0.96), seed_, rng.randf() < 0.4, floors)
	elif key.ends_with("lamp_standing.gltf"):
		_cyl(model, 0.22, 0.04, Vector3(0, 0.02, 0), "iron", 16)
		_cyl(model, 0.03, 2.0, Vector3(0, 1.02, 0), "copper", 8)
		_cyl(model, 0.42, 0.46, Vector3(0, 2.25, 0), "carpet", 16, 0.26)
		_sphere(model, 0.08, Vector3(0, 2.15, 0), "lamp_glow", Vector3.ONE, 8)
	elif key.ends_with("shelf_B_large_decorated.gltf"):
		_box(model, Vector3(sz.x, 0.05, sz.z), Vector3(0, mn.y + 0.025, c.z), "wood")
		_box(model, Vector3(sz.x, 0.05, sz.z), Vector3(0, mn.y + sz.y - 0.025, c.z), "wood")
		for sx in [-1.0, 1.0]:
			_box(model, Vector3(0.05, sz.y, sz.z), Vector3(sx * (sz.x * 0.5 - 0.025), c.y, c.z), "wood")
		_box(model, Vector3(sz.x, sz.y, 0.03), Vector3(0, c.y, mn.z + 0.015), "wood")
		var x: = - sz.x * 0.5 + 0.1
		var cols: = ["carpet", "drum", "gas", "bead", "paint_yellow", "dome"]
		while x < sz.x * 0.5 - 0.1:
			var bw: = rng.randf_range(0.04, 0.09)
			_box(model, Vector3(bw, rng.randf_range(0.35, 0.6), sz.z * 0.7), Vector3(x + bw * 0.5, mn.y + 0.05 + 0.25, c.z), cols[rng.randi() % cols.size()])
			x += bw + 0.012
	elif key.begins_with("furniture/pictureframe"):
		var dpt: = 0.05
		_box(model, Vector3(sz.x, sz.y, dpt), Vector3(c.x, c.y, mn.z + dpt * 0.5), "wood")
		_box(model, Vector3(sz.x * 0.86, sz.y * 0.86, dpt * 0.5), Vector3(c.x, c.y, mn.z + dpt * 0.5 + 0.01), "painting")
		if key.ends_with("standing_A.gltf"):
			var leg: = _box(model, Vector3(0.04, sz.y * 0.9, 0.03), Vector3(0, sz.y * 0.4, mn.z + 0.1), "wood")
			leg.rotation.x = 0.35
	elif key.ends_with("book_set.gltf"):
		var cols: = ["carpet", "drum", "gas", "bead", "dome", "paint_yellow"]
		var y: = mn.y
		for k in 6:
			var h: = rng.randf_range(0.055, 0.09)
			var bw: = rng.randf_range(sz.x * 0.7, sz.x)
			_box(model, Vector3(bw, h, sz.z * rng.randf_range(0.75, 1.0)), Vector3(rng.randf_range(-0.04, 0.04), y + h * 0.5, 0), cols[k % cols.size()], rng.randf_range(-0.12, 0.12))
			_box(model, Vector3(bw * 0.97, h * 0.8, sz.z * 0.9), Vector3(0.02, y + h * 0.5, 0), "paper")
			y += h
	elif key.ends_with("cabinet_small.gltf"):
		_box(model, sz, c, "wood")
		_box(model, Vector3(sz.x * 0.44, sz.y * 0.8, 0.02), Vector3( - sz.x * 0.24, c.y, mn.z + sz.z - 0.01), "floor_wood")
		_box(model, Vector3(sz.x * 0.44, sz.y * 0.8, 0.02), Vector3(sz.x * 0.24, c.y, mn.z + sz.z - 0.01), "floor_wood")
		_sphere(model, 0.02, Vector3(-0.06, c.y, mn.z + sz.z + 0.01), "copper", Vector3.ONE, 6)
		_sphere(model, 0.02, Vector3(0.06, c.y, mn.z + sz.z + 0.01), "copper", Vector3.ONE, 6)
	elif key.begins_with("furniture/chair") or key.ends_with("armchair.gltf"):
		var seat_h: = sz.y * 0.4
		var arm: = key.ends_with("armchair.gltf")
		var m: = "cushion" if arm else "wood"
		_box(model, Vector3(sz.x, 0.08, sz.z * 0.95), Vector3(c.x, seat_h, c.z), m)
		_box(model, Vector3(sz.x, sz.y - seat_h, 0.1), Vector3(c.x, seat_h + (sz.y - seat_h) * 0.5, mn.z + 0.05), m)
		if arm:
			for sx in [-1.0, 1.0]:
				_box(model, Vector3(0.15, 0.3, sz.z * 0.9), Vector3(sx * (sz.x * 0.5 - 0.075), seat_h + 0.15, c.z), m)
			_box(model, Vector3(sz.x, seat_h, sz.z * 0.95), Vector3(c.x, seat_h * 0.5, c.z), m)
		else:
			for sx in [-1.0, 1.0]:
				for sz2 in [-1.0, 1.0]:
					_box(model, Vector3(0.05, seat_h, 0.05), Vector3(c.x + sx * (sz.x * 0.5 - 0.04), seat_h * 0.5, c.z + sz2 * (sz.z * 0.45 - 0.04)), "wood")
			for k in 3:
				_box(model, Vector3(sz.x * 0.9, 0.05, 0.03), Vector3(c.x, seat_h + 0.2 + k * 0.18, mn.z + 0.05), "wood")
	elif key.begins_with("furniture/table") or key.ends_with("proto/table_medium.gltf") or key.ends_with("kitchentable_A.gltf"):
		_box(model, Vector3(sz.x, 0.06, sz.z), Vector3(c.x, sz.y - 0.03, c.z), "floor_wood")
		for sx in [-1.0, 1.0]:
			for sz2 in [-1.0, 1.0]:
				_box(model, Vector3(0.07, sz.y - 0.06, 0.07), Vector3(c.x + sx * (sz.x * 0.5 - 0.08), (sz.y - 0.06) * 0.5, c.z + sz2 * (sz.z * 0.5 - 0.08)), "wood")
		if sz.x > 1.5:
			_cyl(model, 0.12, 0.26, Vector3(c.x + 0.3, sz.y + 0.13, c.z - 0.2), "copper", 10, 0.06)
			_cyl(model, 0.09, 0.02, Vector3(c.x - 0.4, sz.y + 0.01, c.z + 0.3), "porcelain", 14)
	elif key.ends_with("bed_double_A.gltf") or key.ends_with("bed_single_A.gltf"):
		_box(model, Vector3(sz.x, 0.25, sz.z), Vector3(c.x, 0.125 + 0.15, c.z), "wood")
		for sx in [-1.0, 1.0]:
			for sz2 in [-1.0, 1.0]:
				_box(model, Vector3(0.08, 0.3, 0.08), Vector3(c.x + sx * (sz.x * 0.5 - 0.06), 0.15, c.z + sz2 * (sz.z * 0.5 - 0.06)), "wood")
		_box(model, Vector3(sz.x - 0.1, 0.22, sz.z - 0.1), Vector3(c.x, 0.51, c.z), "linen")
		_box(model, Vector3(sz.x - 0.1, 0.1, sz.z * 0.62), Vector3(c.x, 0.67, c.z + sz.z * 0.17), "blanket")
		_box(model, Vector3(sz.x, sz.y - 0.4, 0.08), Vector3(c.x, 0.4 + (sz.y - 0.4) * 0.5, mn.z + 0.04), "wood")
		var npil: = 2 if sz.x > 2.0 else 1
		for k in npil:
			var px: = c.x + ( - 0.6 + k * 1.2 if npil == 2 else 0.0)
			_sphere(model, 0.22, Vector3(px, 0.68, mn.z + 0.45), "linen", Vector3(1.3, 0.35, 0.9), 10)
	elif key.ends_with("pillow_A.gltf"):
		_sphere(model, 0.25, Vector3(0, 0.1, 0), "linen", Vector3(1.4, 0.4, 1.0), 10)
	elif key.begins_with("furniture/rug"):
		var oval: = key.ends_with("rug_oval_A.gltf")
		if oval:
			var mi: = _cyl(model, sz.x * 0.5, 0.025, Vector3(c.x, 0.012, c.z), "carpet", 28)
			mi.scale = Vector3(1, 1, sz.z / sz.x)
		else:
			_box(model, Vector3(sz.x, 0.025, sz.z), Vector3(c.x, 0.012, c.z), "carpet")
			for k in 4:
				_box(model, Vector3(sz.x * 0.9, 0.005, 0.06), Vector3(c.x, 0.028, c.z - sz.z * 0.35 + k * sz.z * 0.23), "cushion")
	elif key.ends_with("bench.gltf"):
		_box(model, Vector3(sz.x, 0.07, 0.45), Vector3(0, 0.45, 0), "wood")
		for j in 3:
			_box(model, Vector3(sz.x, 0.1, 0.035), Vector3(0, 0.62 + j * 0.13, -0.24), "wood")
		for sx in [-0.72, 0.72]:
			_box(model, Vector3(0.06, 0.45, 0.4), Vector3(sx, 0.22, 0), "iron")
			_box(model, Vector3(0.06, 0.5, 0.05), Vector3(sx, 0.7, -0.26), "iron")
	elif key.ends_with("halloween/lantern_standing.gltf"):
		_cyl(model, 0.05, 1.2, Vector3(0, 0.6, 0), "iron", 8)
		_cyl(model, 0.18, 0.04, Vector3(0, 0.02, 0), "iron", 12)
		_box(model, Vector3(0.22, 0.3, 0.22), Vector3(0, 1.35, 0), "lamp_glow")
		_box(model, Vector3(0.26, 0.04, 0.26), Vector3(0, 1.52, 0), "iron")
		_box(model, Vector3(0.26, 0.04, 0.26), Vector3(0, 1.19, 0), "iron")
	elif key.ends_with("kitchencounter_straight_A.gltf"):
		_box(model, Vector3(sz.x, sz.y - 0.06, sz.z), Vector3(c.x, (sz.y - 0.06) * 0.5, c.z), "wood")
		_box(model, Vector3(sz.x + 0.04, 0.06, sz.z + 0.04), Vector3(c.x, sz.y - 0.03, c.z), "marble")
		for k in 3:
			_box(model, Vector3(sz.x * 0.28, sz.y * 0.75, 0.02), Vector3(c.x - sz.x * 0.33 + k * sz.x * 0.33, sz.y * 0.45, mn.z + sz.z - 0.01), "floor_wood")
	elif key.ends_with("cuttingboard.gltf"):
		_box(model, Vector3(sz.x, sz.y, sz.z), c, "floor_wood")
		_sphere(model, 0.22, Vector3(c.x - 0.3, sz.y + 0.1, c.z), "bread", Vector3(1.6, 0.5, 1.0), 10)
		_sphere(model, 0.18, Vector3(c.x + 0.35, sz.y + 0.08, c.z + 0.1), "bread", Vector3(1.0, 0.45, 1.0), 10)
	elif key.ends_with("food_burger.gltf"):
		# a stack of taboon bread and a plate of olives and za'atar
		_cyl(model, sz.x * 0.5, 0.03, Vector3(0, 0.015, 0), "porcelain", 24)
		for k in 4:
			var mi: = _cyl(model, sz.x * 0.42 * (1.0 - k * 0.04), 0.09, Vector3(rng.randf_range(-0.03, 0.03), 0.03 + 0.045 + k * 0.1, rng.randf_range(-0.03, 0.03)), "bread", 20, sz.x * 0.36)
			mi.rotation.y = rng.randf() * TAU
		_cyl(model, 0.12, 0.05, Vector3(0.25, 0.055, 0.22), "porcelain", 14)
		_sphere(model, 0.1, Vector3(0.25, 0.1, 0.22), "olive_leaf", Vector3(1.0, 0.4, 1.0), 10)
		_cyl(model, 0.07, sz.y - 0.5, Vector3(-0.3, (sz.y - 0.5) * 0.5 + 0.03, -0.2), "copper", 10, 0.05)
	elif key.ends_with("table_round_A.gltf"):
		_cyl(model, sz.x * 0.5, 0.06, Vector3(0, sz.y - 0.03, 0), "floor_wood", 28)
		_cyl(model, 0.12, sz.y - 0.06, Vector3(0, (sz.y - 0.06) * 0.5, 0), "iron", 10)
		_cyl(model, sz.x * 0.25, 0.05, Vector3(0, 0.025, 0), "iron", 16)
	elif key.ends_with("containers_A.gltf"):
		_box(model, sz, c, "metal_panel")
		for sx in [-1.0, 1.0]:
			for sz2 in [-1.0, 1.0]:
				_box(model, Vector3(0.03, sz.y + 0.01, 0.03), c + Vector3(sx * (sz.x * 0.5 - 0.015), 0, sz2 * (sz.z * 0.5 - 0.015)), "rail")
		_box(model, Vector3(sz.x * 0.5, 0.01, sz.z * 0.3), c + Vector3(0, sz.y * 0.5, 0), "paint_yellow")
	elif key.ends_with("windturbine_tall.gltf"):
		_lattice_tower(model, 0.12, 1.5, "truss", 0.3)
		_box(model, Vector3(0.3, 0.2, 0.5), Vector3(0, 1.58, 0.1), "metal_panel")
		for k in 3:
			var a: = TAU * k / 3.0
			var bl: = _box(model, Vector3(0.06, 0.0, 0.0), Vector3.ZERO, "paint_white")
			bl.mesh = BoxMesh.new()
			(bl.mesh as BoxMesh).size = Vector3(0.07, 0.75, 0.02)
			bl.position = Vector3(0, 1.58, 0.4) + Vector3(sin(a), cos(a), 0) * 0.37
			bl.rotation = Vector3(0, 0, - a)
		_cyl(model, 0.25, 0.1, Vector3(0, -0.44, 0), "concrete", 12)
	elif key.ends_with("spacetruck_large.gltf"):
		_box(model, Vector3(0.42, 0.22, 0.9), Vector3(0, 0.26, 0), "metal_panel")
		_box(model, Vector3(0.36, 0.2, 0.3), Vector3(0, 0.46, 0.2), "glass")
		_box(model, Vector3(0.4, 0.04, 0.44), Vector3(0, 0.49, -0.2), "steel")
		for sx in [-1.0, 1.0]:
			for k in 3:
				var wh: = _cyl(model, 0.09, 0.08, Vector3(sx * 0.22, 0.09, -0.32 + k * 0.32), "rubber", 12)
				wh.rotation.z = PI * 0.5
		_cyl(model, 0.01, 0.4, Vector3(0.15, 0.56, -0.4), "steel", 6)
		_cyl(model, 0.06, 0.03, Vector3(0.15, 0.56, -0.4), "paint_white", 12)
	elif key.ends_with("structure_tall.gltf"):
		_lattice_tower(model, 0.7, 1.9, "truss", 0.5)
		_box(model, Vector3(1.6, 0.08, 1.6), Vector3(0, 1.96, 0), "steel_deck")
		for k in 4:
			var a: = TAU * k / 4.0 + PI * 0.25
			_sphere(model, 0.05, Vector3(cos(a) * 0.75, 2.05, sin(a) * 0.75), "neon_blue", Vector3.ONE, 6)
	elif key.ends_with("drill_structure.gltf"):
		_lattice_tower(model, 0.5, 2.0, "ibeam", 0.5)
		_cyl(model, 0.18, 2.6, Vector3(0, 0.3, 0), "steel", 12)
		_cyl(model, 0.4, 0.12, Vector3(0, -0.8, 0), "rail", 10, 0.05)
		_box(model, Vector3(1.7, 0.1, 1.7), Vector3(0, 1.95, 0), "steel_deck")
	elif key.begins_with("space/lander"):
		_cyl(model, 0.45, 0.55, Vector3(0, 0.5, 0), "rocket_white", 20)
		_cyl(model, 0.45, 0.35, Vector3(0, 0.95, 0), "metal_panel", 20, 0.2)
		_sphere(model, 0.2, Vector3(0, 1.12, 0), "rocket_white", Vector3(1, 0.5, 1), 12)
		_box(model, Vector3(0.22, 0.26, 0.04), Vector3(0, 0.5, 0.45), "glass")
		for k in 4:
			var a: = TAU * k / 4.0 + PI * 0.25
			_beam(model, Vector3(cos(a) * 0.35, 0.3, sin(a) * 0.35), Vector3(cos(a) * 0.65, 0.02, sin(a) * 0.65), 0.04, "rail")
			_cyl(model, 0.1, 0.03, Vector3(cos(a) * 0.65, 0.015, sin(a) * 0.65), "rail", 10)
		_cyl(model, 0.3, 0.22, Vector3(0, 0.12, 0), "engine_glow", 16, 0.18)
	elif key.ends_with("terrain_tall.gltf"):
		var r: = _rock(model, 0.95, 1.9, Vector3(0, 1.0, 0), "asteroid_top", "asteroid", seed_, 0.3)
	elif key.begins_with("space/basemodule"):
		var r: = minf(sz.x, sz.z) * 0.46
		var mi: = _cyl(model, r, sz.y * 0.92, Vector3(c.x, sz.y * 0.46, c.z), "metal_panel", 24)
		mi.rotation.z = 0.0
		for k in [0.2, 0.5, 0.8]:
			_cyl(model, r + 0.03, 0.05, Vector3(c.x, sz.y * k, c.z), "rail", 24)
		_box(model, Vector3(r * 1.2, 0.18, 0.05), Vector3(c.x, sz.y * 0.55, c.z + r), "glass")
		_box(model, Vector3(0.5, 0.7, 0.08), Vector3(c.x + r, sz.y * 0.35, c.z), "steel")
		_cyl(model, r * 0.9, 0.06, Vector3(c.x, sz.y * 0.95, c.z), "steel_deck", 24)
		if key.ends_with("garage.gltf"):
			_box(model, Vector3(sz.x, sz.y * 0.9, sz.z * 0.5), Vector3(c.x, sz.y * 0.45, c.z - sz.z * 0.2), "metal_panel")
	elif key.ends_with("roofmodule_base.gltf"):
		_cyl(model, sz.x * 0.5, sz.y, Vector3(c.x, 0.0, c.z), "steel_deck", 8)
	elif key.begins_with("space/landingpad"):
		_cyl(model, sz.x * 0.5, sz.y * 0.8, Vector3(0, sz.y * 0.4, 0), "steel_deck", 8)
		_cyl(model, sz.x * 0.5 + 0.03, sz.y * 0.2, Vector3(0, sz.y * 0.9, 0), "paint_yellow", 8)
		_cyl(model, sz.x * 0.2, 0.01, Vector3(0, sz.y + 0.005, 0), "paint_white", 24)
		for k in 8:
			var a: = TAU * k / 8.0
			_sphere(model, 0.04, Vector3(cos(a) * sz.x * 0.46, sz.y + 0.04, sin(a) * sz.x * 0.46), "neon_blue", Vector3.ONE, 6)
	elif key.find("building_church") >= 0:
		_box(model, Vector3(sz.x, sz.y * 0.55, sz.z), Vector3(c.x, sz.y * 0.275, c.z), "limestone")
		var roof: = _box(model, Vector3(sz.x * 0.75, 0.06, sz.z * 1.04), Vector3(c.x - sz.x * 0.25, sz.y * 0.55 + sz.x * 0.2, c.z), "terracotta")
		roof.rotation.z = -0.6
		var roof2: = _box(model, Vector3(sz.x * 0.75, 0.06, sz.z * 1.04), Vector3(c.x + sz.x * 0.25, sz.y * 0.55 + sz.x * 0.2, c.z), "terracotta")
		roof2.rotation.z = 0.6
		_box(model, Vector3(sz.x * 0.3, sz.y * 0.4, sz.z * 0.3), Vector3(c.x, sz.y * 0.75, mn.z + sz.z * 0.2), "limestone")
		_dome(model, sz.x * 0.17, Vector3(c.x, sz.y * 0.95, mn.z + sz.z * 0.2), "dome")
		_box(model, Vector3(0.04, 0.16, 0.04), Vector3(c.x, sz.y * 0.95 + sz.x * 0.17 + 0.08, mn.z + sz.z * 0.2), "gold")
		_box(model, Vector3(0.1, 0.04, 0.04), Vector3(c.x, sz.y * 0.95 + sz.x * 0.17 + 0.1, mn.z + sz.z * 0.2), "gold")
		var door: = _box(model, Vector3(sz.x * 0.2, sz.y * 0.3, 0.05), Vector3(c.x, sz.y * 0.15, mn.z + sz.z + 0.02), "door")
		for k in 3:
			var win: = _box(model, Vector3(0.05, sz.y * 0.2, 0.08), Vector3(mn.x + sz.x + 0.02, sz.y * 0.32, mn.z + sz.z * (0.25 + k * 0.25)), "window_lit3")
	elif key.find("building_home") >= 0 or key.find("building_tavern") >= 0:
		var fl: = 2 if sz.y > 1.1 else 1
		_stone_house(model, Vector3(sz.x * 0.94, sz.y * (0.85 if sz.x > 0.8 else 0.92), sz.z * 0.94), seed_, true, fl)
		if key.find("tavern") >= 0:
			# arcade in front
			for k in 3:
				_box(model, Vector3(0.1, sz.y * 0.4, 0.1), Vector3(mn.x + sz.x * (0.2 + k * 0.3), sz.y * 0.2, mn.z + sz.z + 0.12), "limestone")
			_box(model, Vector3(sz.x, 0.05, 0.3), Vector3(c.x, sz.y * 0.42, mn.z + sz.z + 0.1), "wood")
	elif key.find("building_tower") >= 0:
		var r: = minf(sz.x, sz.z) * 0.42
		_cyl(model, r, sz.y * 0.9, Vector3(c.x, sz.y * 0.45, c.z), "limestone", 14, r * 0.92)
		_cyl(model, r * 1.1, 0.08, Vector3(c.x, sz.y * 0.9, c.z), "concrete", 14)
		for k in 8:
			var a: = TAU * k / 8.0
			_box(model, Vector3(0.1, 0.12, 0.1), Vector3(c.x + cos(a) * r * 1.0, sz.y * 0.96, c.z + sin(a) * r * 1.0), "limestone")
		for k in 3:
			_box(model, Vector3(0.08, 0.16, 0.06), Vector3(c.x + r * 0.98, sz.y * (0.3 + k * 0.22), c.z), "window_lit2")
		_box(model, Vector3(0.03, 0.4, 0.03), Vector3(c.x, sz.y * 1.0 + 0.2, c.z), "pole")
		_box(model, Vector3(0.02, 0.14, 0.22), Vector3(c.x, sz.y * 1.0 + 0.33, c.z + 0.12), "carpet")
	elif key.find("building_well") >= 0:
		var r: = minf(sz.x, sz.z) * 0.45
		_cyl(model, r, sz.y * 0.4, Vector3(c.x, sz.y * 0.2, c.z), "ashlar", 14)
		_cyl(model, r * 0.8, sz.y * 0.4, Vector3(c.x, sz.y * 0.21, c.z), "tank", 12)
		for sx in [-1.0, 1.0]:
			_box(model, Vector3(0.06, sz.y * 0.6, 0.06), Vector3(c.x + sx * r * 0.9, sz.y * 0.65, c.z), "wood")
		_box(model, Vector3(r * 2.2, 0.06, 0.4), Vector3(c.x, sz.y * 0.96, c.z), "terracotta")
		_cyl(model, 0.02, r * 1.8, Vector3(c.x, sz.y * 0.75, c.z), "wood", 6).rotation.z = PI * 0.5
		_cyl(model, 0.07, 0.1, Vector3(c.x, sz.y * 0.55, c.z), "copper", 10)
	elif key.find("building_windmill") >= 0:
		var r: = 0.3
		_cyl(model, r, sz.y * 0.75, Vector3(c.x, mn.y + sz.y * 0.375, c.z), "ashlar", 12, r * 0.8)
		_cyl(model, r * 0.9, sz.y * 0.12, Vector3(c.x, mn.y + sz.y * 0.8, c.z), "terracotta", 12, 0.05)
		for k in 4:
			var a: = TAU * k / 4.0
			var sail: = _box(model, Vector3(0.1, 0.5, 0.02), Vector3(c.x + sin(a) * 0.3, mn.y + sz.y * 0.72 + cos(a) * 0.3, c.z + r + 0.08), "plank_white")
			sail.rotation.z = - a
		_cyl(model, 0.03, 0.3, Vector3(c.x, mn.y + sz.y * 0.72, c.z + r), "wood", 6).rotation.x = PI * 0.5
	elif key.find("building_castle") >= 0:
		_box(model, Vector3(sz.x, sz.y * 0.55, sz.z), Vector3(c.x, sz.y * 0.275, c.z), "ashlar")
		_box(model, Vector3(sz.x * 0.6, sz.y * 0.9, sz.z * 0.6), Vector3(c.x, sz.y * 0.45, c.z), "ashlar")
		for sx in [-1.0, 1.0]:
			for sz2 in [-1.0, 1.0]:
				_cyl(model, sz.x * 0.12, sz.y * 0.7, Vector3(c.x + sx * (sz.x * 0.5 - sz.x * 0.1), sz.y * 0.35, c.z + sz2 * (sz.z * 0.5 - sz.x * 0.1)), "ashlar", 12)
				_cyl(model, sz.x * 0.14, 0.08, Vector3(c.x + sx * (sz.x * 0.5 - sz.x * 0.1), sz.y * 0.7, c.z + sz2 * (sz.z * 0.5 - sz.x * 0.1)), "concrete", 12)
		var n: = int(sz.x / 0.18)
		for k in n:
			var u: = - sz.x * 0.5 + 0.09 + k * 0.18
			if k % 2 == 0:
				_box(model, Vector3(0.1, 0.12, 0.1), Vector3(c.x + u, sz.y * 0.55 + 0.06, mn.z + 0.05), "ashlar")
				_box(model, Vector3(0.1, 0.12, 0.1), Vector3(c.x + u, sz.y * 0.55 + 0.06, mn.z + sz.z - 0.05), "ashlar")
		for k in 4:
			var a: = TAU * k / 4.0
			var w: = _box(model, Vector3(0.08, 0.2, 0.06), Vector3.ZERO, "window_lit1")
			w.position = Vector3(c.x + sin(a) * sz.x * 0.3, sz.y * 0.75, c.z + cos(a) * sz.z * 0.3)
			w.rotation.y = a
		_box(model, Vector3(sz.x * 0.2, sz.y * 0.25, 0.08), Vector3(c.x, sz.y * 0.125, mn.z + sz.z + 0.02), "door")
		_box(model, Vector3(0.03, 0.5, 0.03), Vector3(c.x, sz.y * 0.9 + 0.25, c.z), "pole")
	elif key.ends_with("building_scaffolding.gltf"):
		for sx in [-1.0, 1.0]:
			for sz2 in [-1.0, 1.0]:
				_cyl(model, 0.03, sz.y, Vector3(c.x + sx * sz.x * 0.45, sz.y * 0.5, c.z + sz2 * sz.z * 0.45), "pole", 8)
		for lvl in [0.45, 0.95]:
			_box(model, Vector3(sz.x * 0.9, 0.05, sz.z * 0.9), Vector3(c.x, sz.y * lvl, c.z), "floor_wood")
			for sx in [-1.0, 1.0]:
				_cyl(model, 0.02, sz.z * 0.9, Vector3(c.x + sx * sz.x * 0.45, sz.y * lvl + 0.03, c.z), "pole", 6).rotation.x = PI * 0.5
	elif key.ends_with("building_market_red.gltf"):
		_box(model, Vector3(sz.x, 0.5, sz.z * 0.6), Vector3(c.x, 0.25, c.z), "wood")
		for sx in [-1.0, 1.0]:
			_cyl(model, 0.03, sz.y, Vector3(c.x + sx * sz.x * 0.45, sz.y * 0.5, mn.z + 0.1), "wood", 6)
			_cyl(model, 0.03, sz.y * 0.8, Vector3(c.x + sx * sz.x * 0.45, sz.y * 0.4, mn.z + sz.z - 0.1), "wood", 6)
		var aw: = _box(model, Vector3(sz.x + 0.1, 0.03, sz.z * 1.05), Vector3(c.x, sz.y * 0.9, c.z), "carpet")
		aw.rotation.x = 0.18
		for k in 3:
			_box(model, Vector3(0.25, 0.12, 0.25), Vector3(c.x - 0.5 + k * 0.5, 0.56, c.z), ["bread", "olive_leaf", "clay"][k])
	elif key.ends_with("cloud_small.gltf"):
		for k in 5:
			var r: = rng.randf_range(0.45, 0.7)
			_sphere(model, r, Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.2, 0.3), rng.randf_range(-0.4, 0.4)), "cloud", Vector3(1, 0.8, 1), 12)
	elif key.ends_with("rock_single_A.gltf"):
		_sphere(model, 0.15, Vector3(0, 0.02, 0), "rock", Vector3(1.0, 0.45, 0.9), 8)
	elif key.find("trees_A_large") >= 0 or key.find("trees_B_large") >= 0:
		for k in 3:
			var a: = TAU * k / 3.0 + rng.randf()
			_olive(model, Vector3(cos(a) * 0.5, 0, sin(a) * 0.5), sz.y * rng.randf_range(0.85, 1.0), 0.5, seed_ + k)
	elif key.find("tree_single") >= 0:
		_olive(model, Vector3(0, mn.y, 0), sz.y, sz.x * 0.55, seed_)
	elif key.find("waterplant") >= 0:
		for k in 7:
			var a: = rng.randf() * TAU
			var dd: = rng.randf_range(0.0, 0.25)
			var reed: = _cyl(model, 0.012, sz.y * rng.randf_range(0.6, 1.0), Vector3(cos(a) * dd, sz.y * 0.4, sin(a) * dd), "olive_leaf", 5, 0.004)
			reed.rotation = Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
	else:
		_box(model, sz, c, PROTO_BY_ZONE[clampi(zone - 1, 0, 5)])
	B._merge_meshes(model)
	return model
