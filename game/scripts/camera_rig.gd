extends Node3D


var target: CharacterBody3D
var yaw: = 0.0
var pitch: = -0.28
var distance: = 5.5
var _dist_cur: = 6.0
var _shake: = 0.0
var _fov_extra: = 0.0
var enabled: = true
var cinematic: = false
var collide_always: = false
var frame_x: = 0.0
var _frame_cur: = 0.0
var danger: = 0.0
var _len_cur: = 6.0
var _t: = 0.0
var _roll: = 0.0
var _touch_acc: = Vector2.ZERO
var touch: Node = null
var ride_follow: = false
var _manual_t: = 10.0
var _ride_dist: = 0.0

@onready var yaw_node: Node3D = $Yaw
@onready var pitch_node: Node3D = $Yaw / Pitch
@onready var arm: SpringArm3D = $Yaw / Pitch / Arm
@onready var cam: Camera3D = $Yaw / Pitch / Camera

func _ready() -> void :
	top_level = true

	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	arm.spring_length = distance
	arm.margin = 0.25
	var sph: = SphereShape3D.new()
	sph.radius = 0.25
	arm.shape = sph
	if Game.mobile:
		cam.far = 1800.0

func snap_to_target() -> void :
	if target:
		global_position = target.global_position + Vector3(0, 1.62, 0)
		reset_physics_interpolation()

func add_shake(amount: float) -> void :
	_shake = max(_shake, amount)

func _unhandled_input(event: InputEvent) -> void :
	if not enabled or cinematic:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = Game.settings.get("mouse_sens", 1.0) * 0.0022
		var inv: float = -1.0 if Game.settings.get("invert_y", false) else 1.0
		yaw -= event.relative.x * sens
		pitch -= event.relative.y * sens * inv
		_manual_t = 0.0
		pitch = clamp(pitch, -1.35, 0.75)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clamp(distance - 0.5, 2.5, 11.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clamp(distance + 0.5, 2.5, 11.0)

func touch_look(d: Vector2) -> void :
	if not enabled or cinematic:
		return
	_touch_acc += d
	_manual_t = 0.0

func _process(delta: float) -> void :
	if target == null:
		return
	if enabled and not cinematic and _touch_acc != Vector2.ZERO:

		var k: = 1.0 - exp(-30.0 * delta)
		var d: = _touch_acc * k
		_touch_acc -= d
		if _touch_acc.length() < 0.05:
			d += _touch_acc
			_touch_acc = Vector2.ZERO
		var ts: float = Game.settings.get("touch_sens", 1.0) * 0.0034
		var inv: float = -1.0 if Game.settings.get("invert_y", false) else 1.0
		yaw -= d.x * ts
		pitch -= d.y * ts * 0.8 * inv
		pitch = clamp(pitch, -1.35, 0.75)
	elif cinematic:
		_touch_acc = Vector2.ZERO
	if enabled and not cinematic and touch and Game.settings.get("cam_follow", true) and touch.seconds_since_camera_touch() > 1.2:

		var hv: = Vector3(target.velocity.x, 0, target.velocity.z)
		if target.is_on_floor() and hv.length() > 2.5:
			var want: = atan2( - hv.x, - hv.z)
			var diff: = wrapf(want - yaw, - PI, PI)
			if absf(diff) < 2.4:
				yaw += diff * (1.0 - exp(-0.6 * delta)) * clampf(hv.length() / 5.6, 0.0, 1.0)
	_manual_t += delta
	if enabled and not cinematic and ride_follow and _manual_t > 1.6:
		var hv2: = Vector3(target.velocity.x, 0, target.velocity.z)
		if hv2.length() > 1.0:
			var want2: = atan2( - hv2.x, - hv2.z) + 0.35
			yaw += wrapf(want2 - yaw, - PI, PI) * (1.0 - exp(-1.1 * delta))
			pitch = lerpf(pitch, -0.2, 1.0 - exp(-0.8 * delta))
	_ride_dist = lerpf(_ride_dist, 2.2 if ride_follow else 0.0, 1.0 - exp(-1.5 * delta))
	if enabled and not cinematic:
		var look: = Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
		if look.length() > 0.0:
			_manual_t = 0.0
			var gs: float = Game.settings.get("pad_sens", 1.0) * 2.6
			var inv: float = -1.0 if Game.settings.get("invert_y", false) else 1.0
			yaw -= look.x * gs * delta
			pitch -= look.y * gs * delta * 0.7 * inv
			pitch = clamp(pitch, -1.35, 0.75)
	var tpos: = target.get_global_transform_interpolated().origin + Vector3(0, 1.62, 0)
	var p: = global_position
	var kx: = 1.0 - exp(-16.0 * delta)
	var ky: = 1.0 - exp(-9.0 * delta)
	if target.velocity.y < -14.0:
		ky = 1.0 - exp(-22.0 * delta)
	p.x = lerp(p.x, tpos.x, kx)
	p.z = lerp(p.z, tpos.z, kx)
	p.y = lerp(p.y, tpos.y, ky)
	if p.distance_to(tpos) > 25.0:
		p = tpos
	global_position = p
	yaw_node.rotation.y = yaw
	pitch_node.rotation.x = pitch
	_dist_cur = lerp(_dist_cur, distance + _ride_dist, 1.0 - exp(-8.0 * delta))
	arm.spring_length = _dist_cur

	var hit: float = arm.get_hit_length() if ( not cinematic or collide_always) else _dist_cur
	if hit < _len_cur:
		_len_cur = lerp(_len_cur, hit, 1.0 - exp(-28.0 * delta))
		if _len_cur - hit > 1.5:
			_len_cur = hit + 1.5
	else:
		_len_cur = lerp(_len_cur, hit, 1.0 - exp(-3.5 * delta))
	cam.position = Vector3(0, 0, _len_cur)
	_t += delta

	var base_fov: float = Game.settings.get("fov", 75.0)
	var want: = 0.0
	if target.velocity.y < -12.0:
		want = clamp(( - target.velocity.y - 12.0) * 0.45, 0.0, 14.0)
	var hs: = Vector2(target.velocity.x, target.velocity.z).length()
	if hs > 7.0:
		want += 3.0
	_fov_extra = lerp(_fov_extra, want, 1.0 - exp(-3.0 * delta))
	cam.fov = base_fov + _fov_extra

	var fx: bool = Game.settings.get("camera_fx", true)
	if _shake > 0.0:
		_shake = max(_shake - delta * 1.8, 0.0)
		var s: = _shake * _shake * 0.22
		cam.h_offset = (sin(_t * 37.0) * 0.6 + sin(_t * 23.0 + 1.3) * 0.4) * s
		cam.v_offset = (sin(_t * 41.0 + 0.7) * 0.6 + sin(_t * 29.0 + 2.1) * 0.4) * s
	else:
		cam.h_offset = lerp(cam.h_offset, 0.0, 1.0 - exp(-10.0 * delta))
		cam.v_offset = lerp(cam.v_offset, 0.0, 1.0 - exp(-10.0 * delta))
	_frame_cur = lerpf(_frame_cur, frame_x, 1.0 - exp(-3.0 * delta))
	cam.h_offset += _frame_cur

	var want_roll: = 0.0
	if fx and not cinematic:
		want_roll = (sin(_t * 0.53) * 0.7 + sin(_t * 0.31 + 1.7) * 0.3) * 0.014 * danger
	_roll = lerp(_roll, want_roll, 1.0 - exp(-2.0 * delta))
	cam.rotation.z = _roll
	target.camera_basis = cam.global_transform.basis

	var vis: Node3D = target.get_node("Visual")
	vis.visible = _len_cur > 0.9
