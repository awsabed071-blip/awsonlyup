extends CharacterBody3D



signal landed(fall_height: float)
signal jumped
signal hard_landing(fall_height: float)

const WALK_SPEED: = 2.4
const RUN_SPEED: = 5.6
const SPRINT_SPEED: = 8.2
const ACC_GROUND: = 50.0
const DEC_GROUND: = 62.0
const ACC_AIR: = 24.0
const JUMP_VELOCITY: = 10.0
const G_UP: = 24.0
const G_CUT: = 52.0
const G_DOWN: = 32.0
const TERMINAL: = 52.0
const COYOTE_TIME: = 0.2
const JUMP_BUFFER: = 0.2
const STEP_HEIGHT: = 0.36
const HARD_FALL: = 14.0
const MEDIUM_FALL: = 5.0
const MANTLE_MIN: = 0.38
const MANTLE_MAX_AIR: = 1.15
const MANTLE_MAX_GROUND: = 1.3

const MANTLE_MAX_AIR_ASSIST: = 1.3
const MANTLE_MIN_AIR_ASSIST: = -0.12
const MANTLE_REACH: = 0.72
const MANTLE_REACH_ASSIST: = 0.95
const EDGE_DROP: = 1.4
const ZIP_MAX: = 15.0

enum State{NORMAL, STUN, FROZEN, CHEER, MANTLE, ZIP, CARRY}

var state: State = State.NORMAL
var gravity_scale: = 1.0
var wind_push: = Vector3.ZERO
var last_wind: = Vector3.ZERO
var updraft_speed: = 0.0
var camera_basis: = Basis.IDENTITY


var bot_enabled: = false
var bot_move: = Vector3.ZERO
var bot_jump_pressed: = false
var bot_jump_held: = false
var bot_sprint: = false

var _coyote: = 0.0
var _buffer: = 0.0
var _jump_held: = false
var _was_on_floor: = true
var _air_apex_y: = 0.0
var _stun_t: = 0.0
var _land_anim_t: = 0.0
var _jump_anim_t: = 0.0
var _step_t: = 0.0
var _just_jumped: = false
var _last_floor_collider: Object = null
var _model: Node3D
const MODEL_SCALE: = 0.96
const HEAD_SCALE: = 1.0
var _anim: AnimationPlayer
var _cur_anim: = ""
var _facing: = 0.0
var _bounce_lock: = 0.0
var _rise_forced: = false
var floor_is_static: = false
var time_in_air: = 0.0

var _m_from: = Vector3.ZERO
var _m_to: = Vector3.ZERO
var _m_t: = 0.0
var _m_dur: = 0.4
var _m_body: Node3D = null
var _m_local: = Vector3.ZERO
var _mantle_cool: = 0.0

var _z_a: = Vector3.ZERO
var _z_b: = Vector3.ZERO
var _z_s: = 0.0
var _z_v: = 0.0
var _zip_cool: = 0.0

var _skel: Skeleton3D
var _bones: = {}
var _rest_global: = {}
var _w_balance: = 0.0
var _w_up: = 0.0
var _w_flail: = 0.0
var _head_yaw: = 0.0
var _head_pitch: = 0.0
var _anim_t: = 0.0
var _squash: = Vector3.ONE
var _squash_v: = Vector3.ZERO
var _lean: = 0.0
var _last_facing: = 0.0
var on_narrow: = false
var force_pose: = ""
var danger: = 0.0

var _edge_t: = 0.0
var _edge_hv: = Vector3.ZERO
var _edge_hold: = 0.0
var _edge_recent: = 0.0
var _guarding: = false
var teeter: = 0.0
var _front_void: = false
var _beam_pull: = Vector3.ZERO
var _pull_top: = 0.0
var _pull_r: = 0.0
var _floor_body: Object = null
var assists_used: = 0

var _dip: = 0.0
var _crouch: = 0.0
var _tuck: = 0.0
var _acc_f: = 0.0
var _prev_hv: = Vector3.ZERO
var _acc_lean: = 0.0
var _leg_len: = 0.3
var _thigh_frac: = 0.6

var _cape_mat: ShaderMaterial
var _cape_a: = Vector2.ZERO
var _cape_v: = Vector2.ZERO
var _cape_flutter: = 0.0
var _idle_t: = 0.0
# logical bone names used by the procedural layers -> bones of the realistic rig
const BONE_MAP: = {
	"upperarm.l": "LeftArm", "upperarm.r": "RightArm", "lowerarm.l": "LeftForeArm", "lowerarm.r": "RightForeArm", 
	"hand.l": "LeftHand", "hand.r": "RightHand", "upperleg.l": "LeftUpLeg", "upperleg.r": "RightUpLeg", 
	"lowerleg.l": "LeftLeg", "lowerleg.r": "RightLeg", "foot.l": "LeftFoot", "foot.r": "RightFoot", 
	"chest": "Spine2", "spine": "Spine", "neck": "Neck", "head": "Head", 
}
# clip names other scripts still ask for -> clips of the realistic character
const ANIM_MAP: = {
	"Walking_A": "Walk", "Walking_B": "Walk", "Walking_C": "Walk", "Running_A": "Run", "Running_B": "Run", 
	"Jump_Idle": "Hang", "Jump_Land": "Land", "Lie_StandUp": "Stun_GetUp", "Sit_Chair_Idle": "Sit_Chair", 
	"Sit_Floor_Idle": "Sit_Floor", "Lie_Idle": "Lie", "Unarmed_Idle": "Idle", "Spellcasting": "Grief", "Hit_A": "Land_Hard", 
}
const LOOP_CLIPS: = ["Idle", "Walk", "Run", "Sprint", "Jump_Air", "Fall", "Hang", "Sit_Chair", "Sit_Floor", "Lie", "Balance", "Zip", "LookUp", "Grief"]
const ONESHOT_CLIPS: = ["Jump_Start", "Land", "Land_Hard", "Stun_GetUp", "Mantle", "Cheer", "PickUp"]

static func anim_name(n: String) -> String:
	return ANIM_MAP.get(n, n)

static func bone_name(b: String) -> String:
	return BONE_MAP.get(b, b)

@onready var shape: CollisionShape3D = $Collision

var _dust: GPUParticles3D

func _make_dust() -> void :
	_dust = GPUParticles3D.new()
	_dust.one_shot = true
	_dust.emitting = false
	_dust.amount = 18
	_dust.lifetime = 0.6
	_dust.explosiveness = 0.95
	var pm: = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.35
	pm.emission_ring_inner_radius = 0.2
	pm.emission_ring_height = 0.05
	pm.direction = Vector3(0, 0.3, 0)
	pm.spread = 80.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.6
	pm.gravity = Vector3(0, 0.5, 0)
	pm.damping_min = 3.0
	pm.damping_max = 5.0
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	var g: = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.55))
	g.set_color(1, Color(1, 1, 1, 0.0))
	var gt: = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	_dust.process_material = pm
	var qm: = QuadMesh.new()
	qm.size = Vector2(0.35, 0.35)
	var sm: = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = load("res://assets/particle.png")
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.albedo_color = Color(0.95, 0.92, 0.85)
	qm.material = sm
	_dust.draw_pass_1 = qm
	_dust.position = Vector3(0, 0.05, 0)
	add_child(_dust)

func puff(strength: = 1.0) -> void :
	if _dust:
		_dust.amount_ratio = clamp(strength, 0.2, 1.0)
		_dust.restart()

var _pose: Node3D
var lantern_on: = false
var _lantern: Node3D

# "نَفَس": holding the breath button slows the world for a moment, the way she told him to stop and
# breathe before every step that scared him. The meter refills only with both feet on something solid.
const BREATH_MAX: = 2.2
var breath: = BREATH_MAX
var breath_active: = false
var _breath_cool: = 0.0

func update_breath(delta_real: float, want: bool) -> void :
	_breath_cool = maxf(_breath_cool - delta_real, 0.0)
	var can: = state == State.NORMAL and (not is_on_floor() or velocity.length() > 0.5) and _breath_cool <= 0.0
	if want and can and breath > 0.05:
		breath = maxf(breath - delta_real, 0.0)
		breath_active = true
		if breath <= 0.0:
			_breath_cool = 0.8
	else:
		breath_active = false
		if is_on_floor() and state == State.NORMAL and floor_is_static:
			breath = minf(breath + delta_real * 0.55, BREATH_MAX)

func _ready() -> void :
	_pose = Node3D.new()
	_pose.name = "Pose"
	_pose.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	$Visual.add_child(_pose)
	_make_dust()
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.35
	floor_constant_speed = true
	floor_stop_on_slope = true
	max_slides = 6
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_VELOCITY
	_air_apex_y = global_position.y

func set_character(path: String) -> void :
	if _model:
		_model.queue_free()
	var scene: PackedScene = load(path)
	_model = scene.instantiate()
	_pose.add_child(_model)

	_model.scale = Vector3.ONE * MODEL_SCALE
	for att in _model.find_children("*", "BoneAttachment3D", true, false):
		var bn: = String(att.bone_name)
		if bn.begins_with("handslot"):
			att.visible = false
	_setup_materials()
	_anim = _model.find_child("AnimationPlayer", true, false)
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_skel = _model.find_child("Skeleton3D", true, false)
	_bones.clear()
	_rest_global.clear()
	if _skel:
		for b in BONE_MAP.keys():
			var bi: = _skel.find_bone(BONE_MAP[b])
			if bi >= 0:
				_bones[b] = bi
				_rest_global[b] = _skel.get_bone_global_rest(bi).basis
		if _bones.has("upperleg.l") and _bones.has("foot.l"):
			var hy: = _skel.get_bone_global_rest(_bones["upperleg.l"]).origin.y
			var ky: = _skel.get_bone_global_rest(_bones["lowerleg.l"]).origin.y
			var fy: = _skel.get_bone_global_rest(_bones["foot.l"]).origin.y
			_leg_len = (hy - fy) * _model.scale.y
			_thigh_frac = clampf((hy - ky) / maxf(hy - fy, 0.01), 0.3, 0.8)
	for n in LOOP_CLIPS:
		if _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	for n in ONESHOT_CLIPS:
		if _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_NONE
	_cur_anim = ""
	_play("Idle", 0.0)
	_anim.advance(0.0)
	_lantern = null
	if lantern_on:
		set_lantern(true)

func _play(n0: String, blend: = 0.15, speed: = 1.0) -> void :
	if _anim == null:
		return
	var n: = anim_name(n0)
	if not _anim.has_animation(n):
		return
	if _cur_anim != n:
		_anim.play(n, blend, speed)
		_cur_anim = n
	else:
		_anim.speed_scale = speed



func _setup_materials() -> void :
	_cape_mat = null
	CharMaterials.apply(_model, 2)

func _update_cape(delta: float, hs: float, turn: float) -> void :
	if _cape_mat == null:
		return
	var fdir: = Vector3(sin(_facing), 0.0, cos(_facing))
	var sdir: = Vector3(cos(_facing), 0.0, - sin(_facing))
	var fwd: = velocity.dot(fdir)
	var side: = velocity.dot(sdir)
	var air: = not is_on_floor() and state == State.NORMAL
	var tb: = 0.06 + clampf(fwd * 0.062, -0.05, 0.55)
	if air:
		tb += clampf( - velocity.y * 0.045, -0.15, 0.8)
	if state == State.ZIP:
		tb += 0.45
	var ts: = clampf(side * 0.07 - turn * 0.05, -0.55, 0.55)
	var tgt: = Vector2(clampf(tb, -0.15, 1.2), ts)
	_cape_v += ((tgt - _cape_a) * 58.0 - _cape_v * 7.5) * delta
	_cape_a += _cape_v * delta
	var want_f: = clampf(hs / 7.0 + maxf( - velocity.y, 0.0) / 9.0, 0.0, 1.0) + clampf(global_position.y / 900.0, 0.0, 0.35) + 0.08
	_cape_flutter = lerpf(_cape_flutter, clampf(want_f, 0.0, 1.0), 1.0 - exp(-3.0 * delta))
	_cape_mat.set_shader_parameter("swing_back", _cape_a.x)
	_cape_mat.set_shader_parameter("swing_side", _cape_a.y)
	_cape_mat.set_shader_parameter("flutter", _cape_flutter)
	_cape_mat.set_shader_parameter("flutter_speed", 6.0 + _cape_flutter * 7.0)

func teleport(pos: Vector3, yaw: = 0.0) -> void :
	global_position = pos
	velocity = Vector3.ZERO
	_facing = yaw
	$Visual.rotation.y = yaw
	_air_apex_y = pos.y
	_was_on_floor = false
	reset_physics_interpolation()

func freeze(on: bool) -> void :
	state = State.FROZEN if on else State.NORMAL
	if on:
		velocity = Vector3.ZERO

func cheer() -> void :
	state = State.CHEER
	velocity = Vector3.ZERO
	_play("Cheer", 0.25)

func _get_input_dir() -> Vector3:
	if bot_enabled:
		return bot_move.limit_length(1.0)

	var v: = Input.get_vector("move_left", "move_right", "move_forward", "move_back", 0.0 if Game.touch_stick_active else 0.2)
	if Game.input_blocked:
		v = Vector2.ZERO
	var fwd: = - camera_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right: = camera_basis.x
	right.y = 0
	right = right.normalized()
	return (right * v.x - fwd * v.y).limit_length(1.0)

func _physics_process(delta: float) -> void :
	_mantle_cool = maxf(_mantle_cool - delta, 0.0)
	_zip_cool = maxf(_zip_cool - delta, 0.0)
	if state == State.FROZEN or state == State.CHEER:
		velocity = Vector3.ZERO
		if state == State.CHEER:
			move_and_slide()
		return
	if state == State.MANTLE:
		_do_mantle(delta)
		return
	if state == State.ZIP:
		_do_zip(delta)
		return
	if state == State.CARRY:
		_do_carry(delta)
		return

	var dir: = _get_input_dir()
	var jump_pressed: = false
	var sprint: = false
	var walk: = false
	if bot_enabled:
		jump_pressed = bot_jump_pressed
		bot_jump_pressed = false
		_jump_held = bot_jump_held
		sprint = bot_sprint
	elif not Game.input_blocked:
		jump_pressed = Input.is_action_just_pressed("jump")
		_jump_held = Input.is_action_pressed("jump")
		sprint = Input.is_action_pressed("sprint") != Game.settings.get("auto_sprint", false)
		walk = Input.is_action_pressed("walk")
	else:
		_jump_held = false

	var on_floor: = is_on_floor()
	if state == State.STUN:
		_stun_t -= delta
		dir = Vector3.ZERO
		jump_pressed = false
		if _stun_t <= 0.0:
			state = State.NORMAL


	if on_floor:
		_coyote = COYOTE_TIME
	else:
		_coyote = max(_coyote - delta, 0.0)
	if jump_pressed:
		_buffer = JUMP_BUFFER
	else:
		_buffer = max(_buffer - delta, 0.0)
	_bounce_lock = max(_bounce_lock - delta, 0.0)

	var assist: = _assist()
	if on_floor and state == State.NORMAL and assist:
		dir = _beam_dir(dir)
	else:
		_beam_pull = Vector3.ZERO


	var target_speed: = RUN_SPEED
	if sprint:
		target_speed = SPRINT_SPEED
	if walk:
		target_speed = WALK_SPEED
	var hv: = Vector3(velocity.x, 0, velocity.z)
	var desired: = dir * target_speed
	if on_floor:
		desired += _beam_pull

		var acc: = ACC_GROUND if dir.length() > 0.05 else DEC_GROUND
		hv = hv.move_toward(desired, acc * delta)
	else:

		if dir.length() > 0.05:
			var cur_speed: = hv.length()
			var nv: = hv.move_toward(desired, ACC_AIR * delta)
			var cap: = maxf(cur_speed, target_speed)
			hv = nv.limit_length(cap)
		else:
			hv = hv.move_toward(Vector3.ZERO, 2.0 * delta)



	_guarding = false
	_edge_recent = maxf(_edge_recent - delta, 0.0)
	if on_floor and state == State.NORMAL and assist and dir.length() > 0.1:
		var hvd: = hv if hv.length() > 0.3 else dir
		var n: = _edge_normal(Vector3(hvd.x, 0, hvd.z).normalized(), 0.1 + hv.length() * delta * 1.5)
		if n != Vector3.ZERO and dir.dot(n) > 0.15:
			if _edge_t == 0.0:
				_edge_hv = hv
				_edge_hold = 0.2 if _drop_depth(n) < 7.0 else 0.36
			_edge_t += delta
			_edge_recent = COYOTE_TIME
			if _edge_t < _edge_hold:
				_guarding = true
				var outv: = hv.dot(n)
				if outv > 0.0:
					hv -= n * outv
		else:
			_edge_t = 0.0
	elif not on_floor or dir.length() <= 0.1:
		_edge_t = 0.0

	if not on_floor and state == State.NORMAL and assist and velocity.y < -0.5 and _air_apex_y - global_position.y < 6.0:
		var pull: = _landing_pull(dir, hv)
		if pull != Vector3.ZERO:

			var g_d: = G_DOWN * gravity_scale
			var dy: = global_position.y - _pull_top
			var vy0: = velocity.y
			var t_hit: = (vy0 + sqrt(maxf(vy0 * vy0 + 2.0 * g_d * maxf(dy, 0.0), 0.0))) / g_d
			var along: = hv.dot(pull)
			var need: = maxf(_pull_r - 0.18, 0.0) / maxf(t_hit, 0.05)
			var want: = minf(maxf(need, 2.0), along + 2.6)
			if along < want:
				hv += pull * minf(40.0 * delta, want - along)


	gravity_scale = 0.6 if global_position.y > Game.low_gravity_y else 1.0
	var vy: = velocity.y
	if vy <= 0.0:
		_rise_forced = false
	var g: = G_DOWN
	if vy > 0.0:
		g = G_UP if (_jump_held or _rise_forced) else G_CUT
	vy -= g * gravity_scale * delta
	if updraft_speed > 0.0:
		vy = move_toward(vy, updraft_speed, 38.0 * delta)
		_rise_forced = true
	vy = max(vy, - TERMINAL)

	_just_jumped = false
	if _buffer > 0.0 and _coyote > 0.0 and state == State.NORMAL:
		vy = JUMP_VELOCITY
		if (_edge_t > 0.0 or _edge_recent > 0.0) and _edge_hv.length() > hv.length():
			hv = _edge_hv
		_edge_recent = 0.0
		_edge_t = 0.0
		_buffer = 0.0
		_coyote = 0.0
		_just_jumped = true
		_jump_anim_t = 0.35
		_air_apex_y = global_position.y
		jumped.emit()
		puff(0.4)
		kick_squash(Vector3(-2.5, 4.0, -2.5))
		Game.stats_jumps += 1
		Sfx.play("jump", -6.0, 0.08)

	velocity = Vector3(hv.x, vy, hv.z)
	if on_floor and not _just_jumped:
		_try_step_up(delta)
	var push: = wind_push
	last_wind = push
	velocity += push
	move_and_slide()
	velocity -= push
	wind_push = Vector3.ZERO
	updraft_speed = 0.0


	on_floor = is_on_floor()
	floor_is_static = false
	for i in get_slide_collision_count():
		var c: = get_slide_collision(i)
		var col: = c.get_collider()
		if col == null:
			continue
		if c.get_normal().y > 0.65:
			_floor_body = col
			if col.has_meta("bounce") and _bounce_lock <= 0.0:
				velocity.y = float(col.get_meta("bounce"))
				_bounce_lock = 0.25
				_rise_forced = true
				_air_apex_y = global_position.y
				on_floor = false
				if col.has_method("on_bounced"):
					col.on_bounced()
				Sfx.play("bounce", -3.0, 0.1)
			elif col.has_method("player_standing"):
				col.player_standing(self)
			if col is StaticBody3D and not col.has_meta("moving"):
				floor_is_static = true

	if on_floor:
		time_in_air = 0.0
	else:
		time_in_air += delta
		_floor_body = null
		_air_apex_y = max(_air_apex_y, global_position.y)

	var hv_now: = Vector3(velocity.x, 0, velocity.z)
	var fwd: = Vector3(sin(_facing), 0, cos(_facing))
	var a_f: = (hv_now - _prev_hv).dot(fwd) / maxf(delta, 0.001) if on_floor else 0.0
	_prev_hv = hv_now
	_acc_f = lerpf(_acc_f, a_f, 1.0 - exp(-12.0 * delta))
	var want_teeter: = 0.0
	if _guarding:
		want_teeter = 1.0
	elif on_floor and state == State.NORMAL and _front_void and hv_now.length() < 0.4 and danger > 0.12:
		want_teeter = 0.45
	if force_pose == "teeter":
		want_teeter = 1.0
	teeter = move_toward(teeter, want_teeter, delta * (7.0 if want_teeter > teeter else 2.5))

	if on_floor and not _was_on_floor:
		var fall: = _air_apex_y - global_position.y
		_on_landed(fall)
	if on_floor:
		_air_apex_y = global_position.y
	_was_on_floor = on_floor

	if state == State.NORMAL and not _just_jumped:
		_try_mantle(dir, on_floor)
	_update_footing(on_floor)

	_update_facing(delta, dir)
	_update_anim(delta, on_floor)
	_update_steps(delta, on_floor)

	if global_position.y < -60.0:
		Game.respawn_at_start()


var _foot_t: = 0.0
func _update_footing(on_floor: bool) -> void :
	_foot_t -= get_physics_process_delta_time()
	if _foot_t > 0.0:
		return
	_foot_t = 0.1
	if not on_floor:
		on_narrow = false
		_front_void = false
		return
	var fb: = global_position + Vector3(0, 0.5, 0)
	var ff: = Vector3(sin(_facing), 0, cos(_facing))
	var fp: = fb + ff * 0.5
	_front_void = _ray(fp, fp + Vector3(0, -3.0, 0)).is_empty() and _ray(fb, fp).is_empty()
	var pos: = global_position + Vector3(0, 0.3, 0)
	var basis_f: = Vector3(sin(_facing), 0, cos(_facing))
	var side: = basis_f.cross(Vector3.UP).normalized()
	var misses: = 0
	var miss_off: = Vector3.ZERO
	for off in [side * 0.55, - side * 0.55, basis_f * 0.55, - basis_f * 0.55]:
		var h: = _ray(pos + off, pos + off + Vector3(0, -1.2, 0))
		if h.is_empty():
			misses += 1
			if miss_off == Vector3.ZERO:
				miss_off = off
	on_narrow = misses >= 2
	var drop: = 0.0
	if misses > 0:
		var probe: = _ray(pos + miss_off * 2.0, pos + miss_off * 2.0 + Vector3(0, -150, 0))
		drop = 150.0 if probe.is_empty() else pos.y - probe.position.y
	var d_h: float = clamp((drop - 4.0) / 50.0, 0.0, 1.0)
	danger = clamp(d_h * (1.0 if on_narrow else 0.45) * clamp(global_position.y / 160.0, 0.25, 1.0), 0.0, 1.0)


func _process(delta: float) -> void :
	if _anim == null:
		return
	_anim.advance(delta)
	_anim_t += delta
	_procedural(delta)

func _bone_to_global(bname: String, target: Basis, w: float) -> void :
	if w <= 0.001 or not _bones.has(bname):
		return
	var bi: int = _bones[bname]
	var parent: = _skel.get_bone_parent(bi)
	var pg: = _skel.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var local_target: = (pg.inverse() * target).orthonormalized().get_rotation_quaternion()
	var cur: = _skel.get_bone_pose_rotation(bi)
	_skel.set_bone_pose_rotation(bi, cur.slerp(local_target, clamp(w, 0.0, 1.0)))

func _bone_rest_local(bname: String, w: float) -> void :
	if w <= 0.001 or not _bones.has(bname):
		return
	var bi: int = _bones[bname]
	var cur: = _skel.get_bone_pose_rotation(bi)
	_skel.set_bone_pose_rotation(bi, cur.slerp(_skel.get_bone_rest(bi).basis.get_rotation_quaternion(), clamp(w, 0.0, 1.0)))

func _arm_target(side: float, lift_deg: float, fwd_deg: = 0.0) -> Basis:

	var rest: Basis = _rest_global["upperarm.l" if side > 0.0 else "upperarm.r"]
	var r: = Basis(Vector3.BACK, deg_to_rad(lift_deg) * side) * rest
	return Basis(Vector3.UP, - deg_to_rad(fwd_deg) * side) * r

func _procedural(delta: float) -> void :
	if _skel == null or _bones.is_empty():
		return
	var in_air: = not is_on_floor() and state == State.NORMAL
	var falling_long: = in_air and velocity.y < -6.0 and time_in_air > 0.55

	var want_bal: = 1.0 if (on_narrow and state == State.NORMAL and is_on_floor()) else 0.0
	var want_up: = 1.0 if (state == State.ZIP or state == State.MANTLE or (state == State.CARRY and carry_pose == "hang")) else 0.0
	var want_flail: = 1.0 if falling_long else 0.0
	if force_pose != "":
		want_bal = 1.0 if force_pose == "balance" else 0.0
		want_up = 1.0 if force_pose == "up" else 0.0
		want_flail = 1.0 if force_pose == "flail" else 0.0
	_w_balance = move_toward(_w_balance, want_bal, delta * 4.0)
	_w_up = move_toward(_w_up, want_up, delta * (10.0 if want_up > 0.0 else 4.0))
	_w_flail = move_toward(_w_flail, want_flail, delta * 3.0)

	if _w_balance > 0.0:
		var sway: = sin(_anim_t * 2.2) * 9.0
		_bone_to_global("upperarm.l", _arm_target(1.0, -8.0 + sway, 10.0), _w_balance * 0.85)
		_bone_to_global("upperarm.r", _arm_target(-1.0, -8.0 - sway, 10.0), _w_balance * 0.85)
		_bone_rest_local("lowerarm.l", _w_balance * 0.6)
		_bone_rest_local("lowerarm.r", _w_balance * 0.6)

	if _w_up > 0.0:
		var reach: = 62.0
		if state == State.MANTLE:
			var k: float = clamp(_m_t / maxf(_m_dur, 0.01), 0.0, 1.0)
			reach = lerp(80.0, -20.0, smoothstep(0.35, 1.0, k))
		_bone_to_global("upperarm.l", _arm_target(1.0, reach, 25.0), _w_up)
		_bone_to_global("upperarm.r", _arm_target(-1.0, reach, 25.0), _w_up)
		_bone_rest_local("lowerarm.l", _w_up * 0.85)
		_bone_rest_local("lowerarm.r", _w_up * 0.85)

	_w_ride = move_toward(_w_ride, 1.0 if (state == State.CARRY and carry_pose == "ride") else 0.0, delta * 3.0)
	if _w_ride > 0.0:
		_ride_pose(_w_ride)

	_w_swing = move_toward(_w_swing, 1.0 if (state == State.CARRY and carry_pose == "swing") else 0.0, delta * 4.0)
	if _w_swing > 0.0:
		var ws: = _w_swing
		_bone_to_global("upperarm.l", _arm_target(1.0, 68.0, 12.0), ws)
		_bone_to_global("upperarm.r", _arm_target(-1.0, 68.0, 12.0), ws)
		_bone_rest_local("lowerarm.l", ws * 0.7)
		_bone_rest_local("lowerarm.r", ws * 0.7)
		var kick: = clampf(ride_crank * 0.6, -0.5, 0.7)
		for sd in ["l", "r"]:
			_rot_local("upperleg." + sd, Vector3.RIGHT, LEG_SIGN * kick * 0.4 * ws)
			_rot_local("lowerleg." + sd, Vector3.RIGHT, LEG_SIGN * - kick * 0.9 * ws)

	if _w_flail > 0.0:
		var t: = _anim_t * 11.0
		_bone_to_global("upperarm.l", _arm_target(1.0, 55.0 + sin(t) * 35.0, sin(t * 0.7) * 30.0), _w_flail)
		_bone_to_global("upperarm.r", _arm_target(-1.0, 55.0 + sin(t + 2.0) * 35.0, sin(t * 0.7 + 1.5) * 30.0), _w_flail)
		_bone_rest_local("lowerarm.l", _w_flail * 0.5)
		_bone_rest_local("lowerarm.r", _w_flail * 0.5)
		for side in ["l", "r"]:
			var bname: String = "upperleg." + side
			if _bones.has(bname):
				var bi: int = _bones[bname]
				var q: = _skel.get_bone_pose_rotation(bi)
				var kick: = sin(t * 0.9 + (0.0 if side == "l" else PI)) * 0.45 * _w_flail
				_skel.set_bone_pose_rotation(bi, q * Quaternion(Vector3.RIGHT, kick))

	if teeter > 0.01 and state == State.NORMAL:
		var tt: = _anim_t * 8.5
		var lift: = 62.0 + sin(tt) * 36.0
		var sw: = cos(tt) * 60.0
		_bone_to_global("upperarm.l", _arm_target(1.0, lift, sw), teeter)
		_bone_to_global("upperarm.r", _arm_target(-1.0, lift, sw), teeter)
		_bone_rest_local("lowerarm.l", teeter * 0.6)
		_bone_rest_local("lowerarm.r", teeter * 0.6)

	var hs1: = Vector2(velocity.x, velocity.z).length()
	_dip = move_toward(_dip, 0.0, delta * 3.0)
	var want_c: = _dip
	var on_f: = is_on_floor() and state == State.NORMAL
	if on_f:
		if on_narrow:
			want_c = maxf(want_c, 0.14)
		if teeter > 0.0:
			want_c = maxf(want_c, 0.26 * teeter)
		if danger > 0.45 and hs1 < 0.5:
			want_c = maxf(want_c, 0.12)
	elif state != State.STUN:
		want_c = 0.0
	if force_pose == "crouch":
		want_c = 0.8
	_crouch = lerpf(_crouch, want_c, 1.0 - exp(-22.0 * delta))
	var want_tuck: = 0.0
	if in_air and not falling_long:
		want_tuck = clampf(velocity.y / 7.0, 0.0, 1.0) * 0.5 + 0.12
		if velocity.y < -3.0:
			want_tuck = 0.0
	if state == State.MANTLE:
		var km: float = clampf(_m_t / maxf(_m_dur, 0.01), 0.0, 1.0)
		want_tuck = 0.9 * (1.0 - smoothstep(0.55, 1.0, km))
	if force_pose == "tuck":
		want_tuck = 0.9
	_tuck = lerpf(_tuck, want_tuck, 1.0 - exp(-14.0 * delta))
	var legw: = maxf(_crouch, _tuck)
	if legw > 0.005:
		_bend_legs(legw)
		_rot_local("spine", Vector3.RIGHT, 0.32 * legw)

	if on_f and hs1 < 0.25 and _bones.has("chest"):
		_rot_local("chest", Vector3.RIGHT, sin(_anim_t * 1.8) * 0.035)

	if _bones.has("head"):
		var want_y: = 0.0
		var want_p: = 0.0
		var hs0: = Vector2(velocity.x, velocity.z).length()
		if state == State.NORMAL and is_on_floor() and hs0 < RUN_SPEED + 0.5 and camera_basis != Basis():
			var f: = - camera_basis.z
			var rel: = wrapf(atan2(f.x, f.z) - _facing, - PI, PI)
			if absf(rel) < 2.1:
				want_y = clampf(rel, -1.0, 1.0) * (1.0 if hs0 < 1.0 else 0.4)
				want_p = clampf( - f.y * 0.9, -0.35, 0.55) * (1.0 if hs0 < 1.0 else 0.4)

		if on_f and hs1 < 0.25:
			_idle_t += delta
		else:
			_idle_t = 0.0
		var il: = smoothstep(6.0, 8.0, _idle_t)
		if il > 0.0:
			want_y += (sin(_idle_t * 0.45) * 0.7 + sin(_idle_t * 1.13) * 0.2) * il
			want_p += maxf(sin(_idle_t * 0.31 + 1.0), 0.0) * 0.35 * danger * il
			want_y = clampf(want_y, -1.1, 1.1)
		_head_yaw = lerpf(_head_yaw, want_y, 1.0 - exp(-5.0 * delta))
		_head_pitch = lerpf(_head_pitch, want_p, 1.0 - exp(-5.0 * delta))
		var hb: int = _bones["head"]
		var hq: = _skel.get_bone_pose_rotation(hb)
		_skel.set_bone_pose_rotation(hb, hq * Quaternion(Vector3.UP, _head_yaw * 0.8) * Quaternion(Vector3.RIGHT, _head_pitch))
		if _bones.has("chest"):
			var cb: int = _bones["chest"]
			_skel.set_bone_pose_rotation(cb, _skel.get_bone_pose_rotation(cb) * Quaternion(Vector3.UP, _head_yaw * 0.25))
		_skel.set_bone_pose_scale(hb, Vector3.ONE * HEAD_SCALE)

	_squash_v += (Vector3.ONE - _squash) * 220.0 * delta
	_squash_v *= exp(-16.0 * delta)
	_squash += _squash_v * delta

	var turn: = wrapf(_facing - _last_facing, - PI, PI) / maxf(delta, 0.001)
	_last_facing = _facing
	var hs: = Vector2(velocity.x, velocity.z).length()
	_update_cape(delta, hs, turn)
	var want_lean: float = clamp( - turn * 0.035 * clamp(hs / 6.0, 0.0, 1.0), -0.22, 0.22) if is_on_floor() else 0.0
	_lean = lerp(_lean, want_lean, 1.0 - exp(-8.0 * delta))
	var pitch: = 0.0
	if is_on_floor() and state == State.NORMAL:
		pitch = clamp((hs - RUN_SPEED) / (SPRINT_SPEED - RUN_SPEED), 0.0, 1.0) * 0.09

		_acc_lean = lerpf(_acc_lean, clampf(_acc_f * 0.0045, -0.15, 0.12), 1.0 - exp(-9.0 * delta))
		pitch += _acc_lean

		pitch += teeter * (-0.13 + sin(_anim_t * 5.0) * 0.05)
	else:
		_acc_lean = lerpf(_acc_lean, 0.0, 1.0 - exp(-9.0 * delta))
	if state == State.MANTLE:
		var km2: float = clampf(_m_t / maxf(_m_dur, 0.01), 0.0, 1.0)
		pitch = 0.32 * sin(km2 * PI)
	if _w_ride > 0.0:
		pitch = lerpf(pitch, - ride_pitch * 0.9, _w_ride)
		_lean = lerpf(_lean, ride_lean, _w_ride)
	if _w_swing > 0.0:
		pitch = lerpf(pitch, ride_pitch, _w_swing)
	_pose.scale = _squash
	_pose.rotation.z = _lean
	_pose.rotation.x = lerp(_pose.rotation.x, pitch, 1.0 - exp(-10.0 * delta))

	var a: = deg_to_rad(62.0) * _crouch
	var b: = deg_to_rad(112.0) * _crouch
	var l1: = _leg_len * _thigh_frac
	var l2: = _leg_len - l1

	_pose.position.y = - ((l1 + l2) - (l1 * cos(a) + l2 * cos(b - a))) * 1.5 * _squash.y

func _ride_pose(w: float) -> void :

	for sd in ["l", "r"]:
		var ph: = ride_crank + (0.0 if sd == "l" else PI)
		var drop: = (0.3 + 0.28 * sin(ph)) * w
		_rot_local("upperleg." + sd, Vector3.RIGHT, - LEG_SIGN * drop)
		_rot_local("lowerleg." + sd, Vector3.RIGHT, LEG_SIGN * (0.2 + 0.3 * cos(ph)) * w)
	_rot_local("spine", Vector3.RIGHT, 0.2 * w)
	var hand: = ride_hand
	_bone_to_global("upperarm.l", _arm_target(1.0, -38.0, 58.0), w)
	_bone_to_global("upperarm.r", _arm_target(-1.0, lerpf(-38.0, 70.0, hand), lerpf(58.0, 30.0, hand)), w)
	_bone_rest_local("lowerarm.l", w * 0.5)
	_bone_rest_local("lowerarm.r", w * lerpf(0.5, 0.2, hand))

	var g: = ride_groove * w
	var tt: = ride_time
	_rot_local("chest", Vector3.FORWARD, sin(tt * 2.1) * 0.07 * g)
	_rot_local("head", Vector3.FORWARD, sin(tt * 2.1 - 0.6) * 0.16 * g)
	_rot_local("head", Vector3.RIGHT, (0.05 + 0.07 * sin(tt * 4.2)) * g)
	if hand > 0.01:
		_rot_local("lowerarm.r", Vector3.UP, sin(tt * 3.2) * 0.9 * hand * w)
		_rot_local("head", Vector3.RIGHT, -0.12 * hand * w)

const LEG_SIGN: = 1.0
func _rot_local(bname: String, axis: Vector3, ang: float) -> void :
	if not _bones.has(bname):
		return
	var bi: int = _bones[bname]
	_skel.set_bone_pose_rotation(bi, _skel.get_bone_pose_rotation(bi) * Quaternion(axis, ang))

func _bend_legs(w: float) -> void :

	var a: = deg_to_rad(62.0) * w
	var b: = deg_to_rad(112.0) * w
	for sd in ["l", "r"]:
		_rot_local("upperleg." + sd, Vector3.RIGHT, LEG_SIGN * a)
		_rot_local("lowerleg." + sd, Vector3.RIGHT, - LEG_SIGN * b)
		_rot_local("foot." + sd, Vector3.RIGHT, LEG_SIGN * (b - a))

func set_lantern(on: bool) -> void :

	lantern_on = on
	if on:
		if _lantern == null or not is_instance_valid(_lantern):
			if _skel == null:
				return
			var ba: = BoneAttachment3D.new()
			ba.bone_name = bone_name("chest")
			_skel.add_child(ba)
			_lantern = load("res://scripts/lantern.gd").new()
			_lantern.set("glow_range", 3.2)
			_lantern.set("glow_energy", 0.7)
			ba.add_child(_lantern)
			# hangs from a strap on the back, between the shoulder blades
			_lantern.position = Vector3(0.0, 0.02, -0.17)
			_lantern.rotation = Vector3(0.12, 0, 0)
			_lantern.scale = Vector3.ONE * 0.8
			for gi in _lantern.find_children("*", "GeometryInstance3D", true, false):
				(gi as GeometryInstance3D).layers = 2
		_lantern.visible = true
	elif _lantern and is_instance_valid(_lantern):
		_lantern.visible = false

func fall_distance() -> float:
	if is_on_floor() or velocity.y > -1.0 or state != State.NORMAL:
		return 0.0
	return maxf(_air_apex_y - global_position.y, 0.0)

func kick_squash(amount: Vector3) -> void :
	_squash_v += amount


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q: = PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)


func _assist() -> bool:
	return bool(Game.settings.get("assist", true))

func _beam_dir(dir: Vector3) -> Vector3:


	_beam_pull = Vector3.ZERO
	if dir.length() < 0.1 or _floor_body == null or not is_instance_valid(_floor_body):
		return dir
	var fb: = _floor_body as Node3D
	if fb == null or not fb.has_meta("beam_w"):
		return dir
	var a: = fb.global_basis.x
	a.y = 0.0
	if a.length() < 0.3:
		return dir
	a = a.normalized()
	var mag: = dir.length()
	var along: = dir.dot(a)
	if absf(along) < mag * 0.6:
		return dir
	var lat: = dir - a * along
	var nd: = (a * signf(along) * mag + lat * 0.2).normalized() * mag
	var side: = Vector3( - a.z, 0, a.x)
	var lo: = (global_position - fb.global_position).dot(side)
	if absf(lo) > 0.04:
		_beam_pull = - side * clampf(lo * 3.0, -1.2, 1.2)
	return nd

func _edge_normal(hdir: Vector3, look: = 0.2) -> Vector3:


	if hdir.length() < 0.5:
		return Vector3.ZERO
	var base: = global_position + Vector3(0, 0.5, 0)
	var down: = Vector3(0, - (0.5 + EDGE_DROP), 0)
	var p0: = base + hdir * look
	if not _ray(p0, p0 + down).is_empty():
		return Vector3.ZERO
	if not _ray(base, p0 + hdir * 0.2).is_empty():
		return Vector3.ZERO
	var p1: = base + hdir * (look + 0.5)
	if not _ray(p1, p1 + down).is_empty():
		return Vector3.ZERO
	var n: = Vector3.ZERO
	for i in [-3, -2, -1, 0, 1, 2, 3]:
		var d: = hdir.rotated(Vector3.UP, float(i) * 0.45)
		var p: = base + d * look
		if _ray(p, p + down).is_empty():
			n += d
	return n.normalized() if n.length() > 0.05 else hdir

func _drop_depth(n: Vector3) -> float:
	var p: = global_position + n * 0.9 + Vector3(0, 0.3, 0)
	var h: = _ray(p, p + Vector3(0, -60.0, 0))
	return 60.0 if h.is_empty() else global_position.y - h.position.y

func _landing_pull(dir: Vector3, hv: Vector3) -> Vector3:
	var base: = global_position + Vector3(0, 0.2, 0)
	if not _ray(base, base + Vector3(0, -2.6, 0)).is_empty():
		return Vector3.ZERO
	var mv: = hv.normalized() if hv.length() > 1.0 else Vector3.ZERO
	var best: = Vector3.ZERO
	var best_r: = 99.0
	for i in 8:
		var a: = TAU * float(i) / 8.0
		var d: = Vector3(sin(a), 0, cos(a))
		if dir.length() > 0.3 and d.dot(dir) < -0.2:
			continue
		if mv != Vector3.ZERO and d.dot(mv) < -0.35 and dir.length() <= 0.3:
			continue
		for r in [0.5, 0.85]:
			if r >= best_r:
				break
			var p: Vector3 = base + d * r
			if not _ray(base, p).is_empty():
				break
			var h: = _ray(p, p + Vector3(0, -2.4, 0))
			if not h.is_empty() and h.normal.y > 0.75:
				best = d
				best_r = r
				_pull_top = h.position.y
				break
	if best != Vector3.ZERO:
		assists_used += 1
		_pull_r = best_r
	return best

func _try_mantle(dir: Vector3, on_floor: bool) -> void :
	if _mantle_cool > 0.0:
		return
	var assist: = _assist()
	var f: = Vector3(dir.x, 0, dir.z)
	if f.length() < 0.3:

		var hvm: = Vector3(velocity.x, 0, velocity.z)
		if assist and not on_floor and hvm.length() > 1.2:
			f = hvm
		else:
			return
	if on_floor and not is_on_wall():
		return
	if not on_floor and velocity.y > 3.5:
		return
	f = f.normalized()
	var pos: = global_position
	var hit: = {}

	var ext: = assist and not on_floor and (_air_apex_y - pos.y) < 7.0
	var reach: = MANTLE_REACH_ASSIST if ext else MANTLE_REACH
	var heights: = [1.05, 0.62, 0.3, 0.1, -0.15] if ext else [1.05, 0.62, 0.3]
	for h in heights:
		var from: Vector3 = pos + Vector3(0, h, 0)
		hit = _ray(from, from + f * reach)
		if not hit.is_empty():
			break
	if hit.is_empty():
		return
	var n: Vector3 = hit.normal
	if n.y > 0.5:
		return
	var wall_n: = Vector3(n.x, 0, n.z).normalized()
	if wall_n.dot(f) > -0.35:
		return
	var maxh: = MANTLE_MAX_GROUND if on_floor else (MANTLE_MAX_AIR_ASSIST if ext else MANTLE_MAX_AIR)
	var minh: = MANTLE_MIN_AIR_ASSIST if ext else MANTLE_MIN
	var probe: Vector3 = hit.position - wall_n * 0.32
	probe.y = pos.y + maxh + 0.25
	var top: = _ray(probe, Vector3(probe.x, pos.y + minh - 0.05, probe.z))
	if top.is_empty() or top.normal.y < 0.75:
		return
	var ledge_h: float = top.position.y - pos.y
	if ledge_h < minh or ledge_h > maxh:
		return
	var target: Vector3 = top.position - wall_n * 0.12 + Vector3(0, 0.04, 0)

	var sq: = PhysicsShapeQueryParameters3D.new()
	sq.shape = shape.shape
	sq.transform = Transform3D(Basis.IDENTITY, target + Vector3(0, 0.88, 0))
	sq.collision_mask = 1
	sq.exclude = [get_rid()]
	sq.margin = 0.02
	if not get_world_3d().direct_space_state.intersect_shape(sq, 1).is_empty():
		return
	state = State.MANTLE
	_m_from = pos
	_m_to = target
	_m_t = 0.0
	_m_dur = 0.24 + 0.14 * maxf(ledge_h, 0.0) + 0.1 * Vector2(target.x - pos.x, target.z - pos.z).length()
	if ext:
		assists_used += 1
	_m_body = top.collider as Node3D
	_m_local = _m_body.global_transform.affine_inverse() * target if _m_body else target
	velocity = Vector3.ZERO
	_facing = atan2( - wall_n.x, - wall_n.z)
	$Visual.rotation.y = _facing
	_play("Mantle", 0.06, 0.7 / maxf(_m_dur, 0.2))
	Sfx.play("grab", -6.0, 0.1)
	Game.haptic(14, 0.4)

func _do_mantle(delta: float) -> void :
	_m_t += delta
	if _m_body and is_instance_valid(_m_body):
		_m_to = _m_body.global_transform * _m_local
	var k: float = clamp(_m_t / _m_dur, 0.0, 1.0)
	var up_k: = 1.0 - pow(1.0 - clamp(k / 0.65, 0.0, 1.0), 2.0)
	var fw_k: = smoothstep(0.3, 1.0, k)
	global_position = Vector3(lerp(_m_from.x, _m_to.x, fw_k), lerp(_m_from.y, _m_to.y, up_k), lerp(_m_from.z, _m_to.z, fw_k))
	if k >= 1.0:
		state = State.NORMAL
		velocity = Vector3.ZERO
		_air_apex_y = global_position.y
		_was_on_floor = true
		_mantle_cool = 0.25
		_coyote = COYOTE_TIME
		_land_anim_t = 0.15
		_cur_anim = ""
		_play("Land", 0.08, 1.4)
		_dip = 0.35
		kick_squash(Vector3(1.5, -2.5, 1.5))


func start_zip(a: Vector3, b: Vector3) -> void :
	if state != State.NORMAL or _zip_cool > 0.0:
		return
	var d: = b - a
	var L: = d.length()
	var u: = d / L
	var hands: = global_position + Vector3(0, 1.95, 0)
	_z_s = clamp((hands - a).dot(u), 0.3, L - 2.0)
	_z_a = a
	_z_b = b
	var hs: = Vector3(velocity.x, 0, velocity.z).dot(Vector3(u.x, 0, u.z).normalized())
	_z_v = clamp(hs, 4.0, ZIP_MAX)
	state = State.ZIP
	velocity = Vector3.ZERO
	_air_apex_y = global_position.y
	_play("Zip", 0.1)
	Sfx.play("grab", -4.0, 0.1)
	Sfx.play("zip", -6.0, 0.05)


var _carrier: Node3D = null
var _carry_prev: = Vector3.ZERO
var carry_pose: = "hang"

var ride_crank: = 0.0
var ride_groove: = 0.0
var ride_hand: = 0.0
var ride_pitch: = 0.0
var ride_lean: = 0.0
var ride_time: = 0.0
var _w_ride: = 0.0
var _w_swing: = 0.0
var _hand_att: BoneAttachment3D = null

func start_carry(carrier: Node3D, pose: = "hang") -> bool:
	if state != State.NORMAL:
		return false
	_carrier = carrier
	carry_pose = pose
	state = State.CARRY
	velocity = Vector3.ZERO
	_carry_prev = global_position
	_air_apex_y = global_position.y
	if pose == "hang":
		_play("Hang", 0.12)
		Sfx.play("grab", -4.0, 0.1)
	Game.haptic(16, 0.45)
	return true

func play_anim(n: String, blend: = 0.15, speed: = 1.0) -> void :
	if _anim and _anim.has_animation(n):
		_play(n, blend, speed)

func hand_anchor() -> Node3D:

	if _hand_att and is_instance_valid(_hand_att):
		return _hand_att
	if _skel == null:
		return $Visual
	_hand_att = BoneAttachment3D.new()
	_hand_att.bone_name = bone_name("hand.r")
	_skel.add_child(_hand_att)
	return _hand_att

func end_carry(push: Vector3) -> void :
	if state != State.CARRY:
		return
	state = State.NORMAL
	_carrier = null
	carry_pose = "hang"
	velocity = push
	_air_apex_y = global_position.y
	_was_on_floor = false
	_cur_anim = ""
	_zip_cool = 0.5

func _do_carry(delta: float) -> void :
	if _carrier == null or not is_instance_valid(_carrier):
		end_carry(Vector3.ZERO)
		return
	if _carrier.has_method("carry_transform"):

		var xf: Transform3D = _carrier.call("carry_transform")
		global_position = xf.origin
		velocity = (global_position - _carry_prev) / maxf(delta, 0.001)
		_carry_prev = global_position
		var z: = xf.basis.z
		_facing = atan2(z.x, z.z)
		$Visual.rotation.y = _facing
		_air_apex_y = global_position.y
		return

	var hold: Vector3 = _carrier.call("hold_point")
	global_position = hold - Vector3(0, 1.95, 0)
	var v: = (global_position - _carry_prev) / maxf(delta, 0.001)
	_carry_prev = global_position
	var hv: = Vector3(v.x, 0, v.z)
	if hv.length() > 0.4:
		_facing = lerp_angle(_facing, atan2(hv.x, hv.z), 1.0 - exp(-4.0 * delta))
		$Visual.rotation.y = _facing
	_air_apex_y = global_position.y

func _do_zip(delta: float) -> void :
	var d: = _z_b - _z_a
	var L: = d.length()
	var u: = d / L
	var remaining: = L - _z_s
	var acc: = - u.y * 18.0 + 1.5
	_z_v = clamp(_z_v + acc * delta, 4.0, ZIP_MAX)
	if remaining < 6.0:
		_z_v = move_toward(_z_v, 5.0, 14.0 * delta)
	_z_s += _z_v * delta
	var p: = _z_a + u * _z_s - Vector3(0, 1.95, 0)
	global_position = p
	_facing = atan2(u.x, u.z)
	$Visual.rotation.y = _facing
	_air_apex_y = global_position.y
	var jump: = bot_jump_pressed if bot_enabled else (Input.is_action_just_pressed("jump") and not Game.input_blocked)
	bot_jump_pressed = false
	if jump or remaining <= 1.6:
		state = State.NORMAL
		velocity = Vector3(u.x, 0, u.z).normalized() * _z_v * 0.75 + Vector3(0, 2.5 if jump else 1.0, 0)
		_zip_cool = 0.8
		_was_on_floor = false
		_cur_anim = ""

func _on_landed(fall: float) -> void :
	landed.emit(fall)
	if fall > 0.6:
		_dip = clampf(fall / 4.5, 0.22, 0.85)
		puff(clamp(fall / 6.0, 0.3, 1.0))
		var k: float = clamp(fall / 6.0, 0.25, 1.6)
		kick_squash(Vector3(3.0, -5.5, 3.0) * k)
	if fall >= HARD_FALL and state == State.NORMAL:
		state = State.STUN
		_stun_t = 1.25 + clampf((fall - HARD_FALL) / 40.0, 0.0, 1.4)
		_play("Stun_GetUp", 0.05, 1.6 / (1.0 + clampf((fall - HARD_FALL) / 40.0, 0.0, 1.1)))
		velocity.x = 0
		velocity.z = 0
		hard_landing.emit(fall)
		Sfx.play("thud", 0.0, 0.05)
		Game.haptic(90, 0.9)
	elif fall >= MEDIUM_FALL:
		_land_anim_t = 0.28
		hard_landing.emit(fall)
		Game.haptic(30, 0.55)
		Sfx.play("land", -2.0, 0.1)
	elif fall > 0.6:
		_land_anim_t = 0.12
		Sfx.play("land", -9.0, 0.12)

func _try_step_up(delta: float) -> void :
	var hmove: = Vector3(velocity.x, 0, velocity.z) * delta
	if hmove.length() < 0.0005:
		return
	var col: = KinematicCollision3D.new()
	var t: = global_transform
	if not test_move(t, hmove, col, 0.001, true):
		return
	if col.get_normal().y > 0.7:
		return
	var up: = Vector3(0, STEP_HEIGHT, 0)
	if test_move(t, up, null, 0.001, true):
		return
	var raised: = t
	raised.origin += up

	var probe: = hmove.normalized() * maxf(hmove.length(), 0.12)
	if test_move(raised, probe, null, 0.001, true):
		return
	raised.origin += probe
	var dcol: = KinematicCollision3D.new()
	if test_move(raised, - up, dcol, 0.001, true):
		if dcol.get_normal().y > 0.7:
			var new_y: = raised.origin.y + dcol.get_travel().y
			if new_y > global_position.y + 0.02:

				global_position = Vector3(raised.origin.x, new_y + 0.005, raised.origin.z)

func _update_facing(delta: float, dir: Vector3) -> void :
	if state != State.NORMAL:
		return
	var hv: = Vector3(velocity.x, 0, velocity.z)
	var face_dir: = dir if dir.length() > 0.1 else Vector3.ZERO
	if face_dir == Vector3.ZERO and hv.length() > 1.0 and not is_on_floor():
		face_dir = hv.normalized()
	if face_dir != Vector3.ZERO:
		var target: = atan2(face_dir.x, face_dir.z)
		_facing = lerp_angle(_facing, target, 1.0 - exp(-14.0 * delta))
		$Visual.rotation.y = _facing

func _update_anim(delta: float, on_floor: bool) -> void :
	if _anim == null or state == State.CHEER:
		return
	if state == State.STUN or state == State.MANTLE or state == State.ZIP or state == State.CARRY:
		return
	_land_anim_t = max(_land_anim_t - delta, 0.0)
	_jump_anim_t = max(_jump_anim_t - delta, 0.0)
	var hs: = Vector2(velocity.x, velocity.z).length()
	if on_floor:
		if _land_anim_t > 0.0 and hs < 3.0:
			_play("Land_Hard" if _land_anim_t > 0.2 else "Land", 0.05, 1.4)
		elif hs < 0.25:
			_play("Balance" if on_narrow else "Idle", 0.3)
		elif hs < 3.2:
			_play("Walk", 0.22, clampf(hs / 1.5, 0.7, 1.9))
		elif hs < RUN_SPEED + 1.2:
			_play("Run", 0.18, clampf(hs / 4.6, 0.9, 1.5))
		else:
			_play("Sprint", 0.18, clampf(hs / 7.0, 0.9, 1.35))
	else:
		if _jump_anim_t > 0.0 and velocity.y > 0.0:
			_play("Jump_Start", 0.06, 2.2)
		elif velocity.y < -6.0 and time_in_air > 0.55:
			_play("Fall", 0.35)
		else:
			_play("Jump_Air", 0.25)

func _update_steps(delta: float, on_floor: bool) -> void :
	if not on_floor:
		_step_t = 0.0
		return
	var hs: = Vector2(velocity.x, velocity.z).length()
	if hs < 0.8:
		_step_t = 0.0
		return
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = clamp(1.9 / hs, 0.24, 0.55)
		Sfx.play("step", -14.0, 0.15)
