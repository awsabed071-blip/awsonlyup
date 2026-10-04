extends Node3D


var level
var cloud_sea: MeshInstance3D
var planet: Node3D
var _clouds: Array[Node3D] = []
var landscape: Node3D

func build(level_ref) -> void :
	level = level_ref
	var rng: = RandomNumberGenerator.new()
	rng.seed = 4242
	_build_ground()

	landscape = load("res://scripts/landscape.gd").new()
	landscape.name = "Landscape"
	add_child(landscape)
	landscape.build(level)
	_build_cloud_sea()
	_build_cloud_banks(rng)
	_build_space(rng)

func _build_ground() -> void :
	var body: = StaticBody3D.new()
	var cs: = CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	add_child(body)

func _prop(key: String, pos: Vector3, s: float, yaw: float, shadows: = false) -> Node3D:
	if level == null or level.PR == null or not level.PR.has(key):
		return null
	var n: Node3D = level.PR.build(key, level.zone_at(pos.y), int(absf(pos.x + pos.z * 3.0)))
	n.position = pos
	n.scale = Vector3.ONE * s
	n.rotation.y = yaw
	if not shadows:
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	return n

func _build_cloud_sea() -> void :
	cloud_sea = MeshInstance3D.new()
	var pm: = PlaneMesh.new()
	pm.size = Vector2(5000, 5000)
	pm.subdivide_width = 220
	pm.subdivide_depth = 220
	cloud_sea.mesh = pm
	var sm: = ShaderMaterial.new()
	sm.shader = load("res://shaders/cloud_sea.gdshader")
	cloud_sea.material_override = sm
	cloud_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var y: = 340.0
	if level.zones.size() >= 4:
		y = float(level.zones[3].y0) - 18.0
	cloud_sea.position = Vector3(0, y, 0)
	add_child(cloud_sea)

	var holes: = []
	for n in level.nodes:
		var p: = Vector3(float(n.p[0]), float(n.p[1]), float(n.p[2]))
		if absf(p.y - y) > 55.0:
			continue
		var far: = true
		for h in holes:
			if Vector2(h.x, h.y).distance_to(Vector2(p.x, p.z)) < 14.0:
				far = false
				break
		if far and holes.size() < 48:
			holes.append(Vector4(p.x, p.z, 0.0, 30.0))
	sm.set_shader_parameter("holes", holes)
	sm.set_shader_parameter("hole_count", holes.size())
	sm.set_shader_parameter("fade_near", 45.0)

func _build_cloud_banks(rng: RandomNumberGenerator) -> void :

	var cm: = ShaderMaterial.new()
	cm.shader = load("res://shaders/cloud_billboard.gdshader")
	_cloud_bank_mat = cm
	var quad: = QuadMesh.new()
	quad.size = Vector2.ONE
	var c: = Vector3.ZERO
	for n in level.nodes:
		c += Vector3(float(n.p[0]), 0, float(n.p[2]))
	c /= max(level.nodes.size(), 1)
	var count: = 40 if Game.mobile else 70
	for i in count:
		var a: = rng.randf() * TAU
		var d: = rng.randf_range(180.0, 900.0)
		var y: = rng.randf_range(60.0, 900.0)
		if y > 300.0 and y < 380.0:
			y += 90.0
		var size: = rng.randf_range(55.0, 150.0)
		var cl: = Node3D.new()
		cl.position = c + Vector3(cos(a) * d, y, sin(a) * d)
		add_child(cl)
		var puffs: = rng.randi_range(2, 3) if Game.mobile else rng.randi_range(3, 5)
		for k in puffs:
			var mi: = MeshInstance3D.new()
			mi.mesh = quad
			mi.material_override = cm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var ps: = size * rng.randf_range(0.55, 1.0)
			mi.scale = Vector3(ps, ps * 0.62, ps)
			mi.position = Vector3(rng.randf_range(-0.5, 0.5) * size, rng.randf_range(-0.08, 0.12) * size, rng.randf_range(-0.3, 0.3) * size)
			cl.add_child(mi)
		_clouds.append(cl)

func _build_space(rng: RandomNumberGenerator) -> void :
	planet = Node3D.new()
	add_child(planet)
	var sphere: = SphereMesh.new()
	sphere.radius = 380.0
	sphere.height = 760.0
	sphere.radial_segments = 64
	sphere.rings = 32
	var pmi: = MeshInstance3D.new()
	pmi.mesh = sphere
	var pm: = StandardMaterial3D.new()
	pm.albedo_color = Color(0.85, 0.55, 0.38)
	pm.emission_enabled = true
	pm.emission = Color(0.35, 0.2, 0.15)
	pm.roughness = 1.0
	pmi.material_override = pm
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet.add_child(pmi)
	var ring: = MeshInstance3D.new()
	var tm: = TorusMesh.new()
	tm.inner_radius = 520.0
	tm.outer_radius = 640.0
	tm.rings = 64
	tm.ring_segments = 3
	ring.mesh = tm
	ring.scale = Vector3(1, 0.02, 1)
	ring.rotation_degrees = Vector3(18, 0, 12)
	var rm: = StandardMaterial3D.new()
	rm.albedo_color = Color(0.9, 0.8, 0.65, 0.55)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet.add_child(ring)
	planet.position = Vector3(-1800, 1500, -2600)
	planet.visible = false

var _cloud_bank_mat: ShaderMaterial

func _tint_clouds() -> void :

	if Game.main == null or Game.main.envm == null:
		return
	var l: Dictionary = Game.main.envm._cur_look
	if not l.has("sea"):
		return
	var sea: Color = l.sea
	var sm: = cloud_sea.material_override as ShaderMaterial
	sm.set_shader_parameter("top_col", sea)
	sm.set_shader_parameter("shade_col", sea * Color(0.72, 0.76, 0.86))
	sm.set_shader_parameter("under_col", sea * Color(0.6, 0.62, 0.7))
	if _cloud_bank_mat:
		var sun_c: Color = l.get("sun_col", Color.WHITE)
		_cloud_bank_mat.set_shader_parameter("top_col", sea.lerp(sea * sun_c, 0.45))
		_cloud_bank_mat.set_shader_parameter("bottom_col", sea * Color(0.62, 0.64, 0.78))
		if Game.main.envm.sun:
			_cloud_bank_mat.set_shader_parameter("sun_dir", Game.main.envm.sun.global_transform.basis.z)

func update(cam_pos: Vector3) -> void :
	_tint_clouds()

	if level.zones.size() >= 6:
		planet.visible = cam_pos.y > float(level.zones[5].y0) - 60.0
