extends Node3D



const LOOP_ANIMS: = ["Idle", "Walk", "Run", "Sit_Chair", "Sit_Floor", "Lie", "Hang", "Balance", "LookUp", "Grief", "Jump_Air"]
const ONESHOT_ANIMS: = ["Cheer", "PickUp", "Land", "Land_Hard", "Stun_GetUp", "Jump_Start", "Mantle"]
const ANIM_MAP: = {
	"Walking_A": "Walk", "Walking_B": "Walk", "Walking_C": "Walk", "Running_A": "Run", "Running_B": "Run", 
	"Jump_Idle": "Hang", "Jump_Land": "Land", "Lie_StandUp": "Stun_GetUp", "Sit_Chair_Idle": "Sit_Chair", 
	"Sit_Floor_Idle": "Sit_Floor", "Lie_Idle": "Lie", "Unarmed_Idle": "Idle", "Spellcasting": "Grief", "Hit_A": "Land_Hard", 
}
const MODELS: = {
	"salim": "res://assets/characters/salim.glb", 
	"grandma": "res://assets/characters/grandma.glb", 
	"child": "res://assets/characters/child.glb", 
	"musahhir": "res://assets/characters/musahhir.glb", 
}

var model: Node3D
var anim: AnimationPlayer
var skel: Skeleton3D
var ghost: = false
var _ghost_mat: ShaderMaterial
var _ghost_alpha: = 0.0
var _ghost_target: = 0.0
var _ghost_rate: = 1.0
var _motes: GPUParticles3D
var _cur: = ""
var lantern: Node3D
var mats: = {}

static var _ghost_shader: Shader

func setup(path: String, opts: = {}) -> void :
	# `path` may be a model key ("grandma") or a resource path
	var p: String = MODELS.get(path, path)
	if opts.get("grandma", false):
		p = MODELS.grandma
	var ps: PackedScene = load(p)
	model = ps.instantiate()
	add_child(model)
	model.scale = Vector3.ONE * float(opts.get("model_scale", 1.0))
	anim = model.find_child("AnimationPlayer", true, false)
	skel = model.find_child("Skeleton3D", true, false)
	for n in LOOP_ANIMS:
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	for n in ONESHOT_ANIMS:
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_NONE
	mats = CharMaterials.apply(model, 1)
	if opts.has("scale"):
		scale = Vector3.ONE * float(opts.scale)
	play("Idle", 0.0)

func play(n0: String, blend: = 0.3, speed: = 1.0) -> void :
	var n: String = ANIM_MAP.get(n0, n0)
	if anim == null or not anim.has_animation(n):
		return
	if _cur == n:
		anim.speed_scale = speed
		return
	anim.play(n, blend, speed)
	_cur = n

func face_point(p: Vector3) -> void :

	var par: = get_parent() as Node3D
	var lp: = par.to_local(p) if par else p
	var d: = lp - position
	d.y = 0
	if d.length() > 0.01:
		rotation.y = atan2(d.x, d.z)

func face_yaw(y: float) -> void :
	rotation.y = y


func hold_lantern(on_back: = true) -> Node3D:
	if lantern == null:
		lantern = load("res://scripts/lantern.gd").new()
		lantern.set("glow_range", 4.0)
	if lantern.get_parent():
		lantern.get_parent().remove_child(lantern)
	var bone: = "Spine2" if on_back else "RightHand"
	var ba: = BoneAttachment3D.new()
	ba.bone_name = bone
	skel.add_child(ba)
	ba.add_child(lantern)
	if on_back:
		lantern.position = Vector3(0.0, 0.02, -0.17)
		lantern.rotation = Vector3(0.12, 0, 0)
		lantern.scale = Vector3.ONE * 0.8
	else:
		# hangs from the fingers of the lowered hand
		lantern.position = Vector3(0.0, -0.33, 0.0)
		lantern.rotation = Vector3.ZERO
		lantern.scale = Vector3.ONE * 0.8
	return lantern


func set_ghost(on: bool, fade: = 1.2, tint: = Color(1.0, 0.78, 0.42)) -> void :
	if on and _ghost_mat == null:
		if _ghost_shader == null:
			_ghost_shader = load("res://shaders/memory_ghost.gdshader")
		_ghost_mat = ShaderMaterial.new()
		_ghost_mat.shader = _ghost_shader
		for mi in find_children("*", "MeshInstance3D", true, false):
			if mi.visible:
				(mi as MeshInstance3D).material_override = _ghost_mat
				(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add_motes(tint)
	if _ghost_mat:
		_ghost_mat.set_shader_parameter("tint", tint)
	ghost = on
	_ghost_target = 1.0 if on else 0.0
	_ghost_rate = 1.0 / maxf(fade, 0.01)
	if fade <= 0.01:
		_ghost_alpha = _ghost_target
	if _motes:
		_motes.emitting = on

func _add_motes(tint: Color) -> void :
	_motes = GPUParticles3D.new()
	_motes.amount = 40
	_motes.lifetime = 2.6
	_motes.position = Vector3(0, 0.9, 0)
	var pm: = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.6
	pm.direction = Vector3.UP
	pm.spread = 30.0
	pm.initial_velocity_min = 0.15
	pm.initial_velocity_max = 0.45
	pm.gravity = Vector3(0, 0.12, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	var g: = Gradient.new()
	g.set_color(0, Color(tint.r, tint.g, tint.b, 0.0))
	g.add_point(0.25, Color(tint.r, tint.g, tint.b, 0.9))
	g.set_color(g.get_point_count() - 1, Color(tint.r, tint.g, tint.b, 0.0))
	var gt: = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	_motes.process_material = pm
	var qm: = QuadMesh.new()
	qm.size = Vector2(0.07, 0.07)
	var sm: = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.vertex_color_use_as_albedo = true
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_texture = load("res://assets/particle.png")
	qm.material = sm
	_motes.draw_pass_1 = qm
	add_child(_motes)

func _process(delta: float) -> void :
	if _ghost_mat:
		_ghost_alpha = move_toward(_ghost_alpha, _ghost_target, delta * _ghost_rate)
		_ghost_mat.set_shader_parameter("alpha", _ghost_alpha)
		_ghost_mat.set_shader_parameter("time", Time.get_ticks_msec() * 0.001)
