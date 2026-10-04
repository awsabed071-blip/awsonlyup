extends Area3D


var height: = 15.0
var radius: = 1.2
var speed: = 9.0
var _players: Array = []
var _fan: Node3D

func _ready() -> void :
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var cs: = CollisionShape3D.new()
	var shp: = CylinderShape3D.new()
	shp.radius = radius
	shp.height = height
	cs.shape = shp
	cs.position = Vector3(0, height * 0.5, 0)
	add_child(cs)
	body_entered.connect( func(b): if b is CharacterBody3D: _players.append(b))
	body_exited.connect( func(b): _players.erase(b))
	_build_visuals()

func _build_visuals() -> void :

	_fan = Node3D.new()
	add_child(_fan)
	for i in 4:
		var blade: = MeshInstance3D.new()
		var bm: = BoxMesh.new()
		bm.size = Vector3(radius * 1.6, 0.04, 0.28)
		blade.mesh = bm
		blade.rotation.y = i * PI * 0.25
		blade.position.y = 0.06
		var m: = StandardMaterial3D.new()
		m.albedo_color = Color(0.75, 0.8, 0.85)
		m.metallic = 0.6
		m.roughness = 0.35
		blade.material_override = m
		_fan.add_child(blade)

	var parts: = GPUParticles3D.new()
	parts.amount = 90
	parts.lifetime = height / speed
	parts.visibility_aabb = AABB(Vector3( - radius * 2, -1, - radius * 2), Vector3(radius * 4, height + 4, radius * 4))
	var pm: = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = radius * 0.8
	pm.emission_ring_inner_radius = 0.1
	pm.emission_ring_height = 0.2
	pm.direction = Vector3.UP
	pm.spread = 4.0
	pm.initial_velocity_min = speed * 0.9
	pm.initial_velocity_max = speed * 1.2
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var grad: = Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.add_point(0.2, Color(1, 1, 1, 0.55))
	grad.set_color(grad.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var gt: = GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	parts.process_material = pm
	var qm: = QuadMesh.new()
	qm.size = Vector2(0.06, 0.9)
	var sm: = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.vertex_color_use_as_albedo = true
	sm.albedo_color = Color(0.85, 0.95, 1.0)
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	qm.material = sm
	parts.draw_pass_1 = qm
	add_child(parts)

func _physics_process(delta: float) -> void :
	if _fan:
		_fan.rotation.y += delta * 9.0
	for p in _players:
		if not is_instance_valid(p):
			continue
		var local_y: float = p.global_position.y - global_position.y
		if local_y < height + 0.5:
			p.updraft_speed = max(p.updraft_speed, speed)
