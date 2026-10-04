extends CanvasLayer







signal pause_pressed

const JOY_R: = 120.0
const SPRINT_K: = 1.3
const FOLLOW_K: = 1.75
const DEAD: = 0.1
const FULL: = 0.82
const JUMP_R: = 112.0

var mode: = "off"
var force: = ""
var blockers: Callable
var rig: Node = null

var _pad: Control
var _joy_idx: = -1
var _joy_center: = Vector2.ZERO
var _joy_finger: = Vector2.ZERO
var _joy_vec: = Vector2.ZERO
var _sprint: = false
var _cam_idx: = -1
var _cam_last: = Vector2.ZERO
var _jump_idx: = -1
var _jump_last: = Vector2.ZERO
var _jump_press_t: = 0.0
var _hold_idx: = -1
var _t: = 0.0
var _last_cam_touch: = -10.0
var font: Font

func _ready() -> void :
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pad = Control.new()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.draw.connect(_draw_pad)
	add_child(_pad)
	font = load("res://assets/fonts/Cairo-Bold.ttf") if ResourceLoader.exists("res://assets/fonts/Cairo-Bold.ttf") else ThemeDB.fallback_font

func set_mode(m: String) -> void :
	if force != "":
		m = force
	if m == mode:
		return
	mode = m
	_release_all()
	_pad.queue_redraw()

func seconds_since_camera_touch() -> float:
	return _t - _last_cam_touch

func _size() -> Vector2:
	return _pad.get_viewport_rect().size

func _jump_center() -> Vector2:
	var s: = _size()
	return Vector2(s.x - 205.0, s.y - 215.0)

func _breath_center() -> Vector2:
	var s: = _size()
	return Vector2(s.x - 205.0 - JUMP_R - 95.0, s.y - 150.0)

var _breath_idx: = -1

func _pause_center() -> Vector2:

	return Vector2(_size().x * 0.5 + 150.0, 58.0)

func _joy_rest() -> Vector2:
	var s: = _size()
	return Vector2(250.0, s.y - 250.0)

func _release_all() -> void :
	_breath_idx = -1
	for a in ["move_left", "move_right", "move_forward", "move_back", "sprint", "jump", "breath"]:
		Input.action_release(a)
	_joy_idx = -1
	_cam_idx = -1
	_jump_idx = -1
	_hold_idx = -1
	_joy_vec = Vector2.ZERO
	_sprint = false

func _process(delta: float) -> void :
	_t += delta
	if mode != "off":
		_pad.queue_redraw()

func _input(event: InputEvent) -> void :
	if OS.is_debug_build() and "--touch-debug" in OS.get_cmdline_user_args():
		print("TC input ", event.get_class(), " ", event.position if "position" in event else "", " mode ", mode)
	if mode == "off":
		return
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)

func _blocked(p: Vector2) -> bool:
	if not blockers.is_valid():
		return false
	for r in blockers.call():
		if (r as Rect2).has_point(p):
			return true
	return false

func _on_touch(e: InputEventScreenTouch) -> void :
	var p: = e.position
	if e.pressed and mode == "play" and _blocked(p):
		return
	if e.pressed:
		if mode == "cutscene":
			if _hold_idx < 0:
				_hold_idx = e.index
				Input.action_press("jump")
			_eat()
			return
		if p.distance_to(_pause_center()) < 70.0:
			_release_all()
			pause_pressed.emit()
			_eat()
			return
		if _breath_idx < 0 and p.distance_to(_breath_center()) < 78.0:
			_breath_idx = e.index
			Input.action_press("breath")
			Game.haptic(8, 0.25)
			_eat()
			return
		if _jump_idx < 0 and p.distance_to(_jump_center()) < JUMP_R * 1.3:
			_jump_idx = e.index
			_jump_last = p
			_jump_press_t = _t
			Input.action_press("jump")
			Game.haptic(10, 0.35)
			_eat()
			return
		if p.x < _size().x * 0.42 and p.y > _size().y * 0.22 and _joy_idx < 0:
			_joy_idx = e.index

			_joy_center = Vector2(clampf(p.x, JOY_R + 30.0, _size().x * 0.42), clampf(p.y, JOY_R + 30.0, _size().y - JOY_R - 30.0))
			_joy_finger = p
			_update_joy()
			_eat()
			return
		if _cam_idx < 0:
			_cam_idx = e.index
			_cam_last = p
			_last_cam_touch = _t
			_eat()
			return
	else:
		if e.index == _joy_idx:
			_joy_idx = -1
			_joy_vec = Vector2.ZERO
			_sprint = false
			_apply_move()
		elif e.index == _jump_idx:
			_jump_idx = -1
			Input.action_release("jump")
		elif e.index == _breath_idx:
			_breath_idx = -1
			Input.action_release("breath")
		elif e.index == _cam_idx:
			_cam_idx = -1
		elif e.index == _hold_idx:
			_hold_idx = -1
			Input.action_release("jump")
		_eat()

func _on_drag(e: InputEventScreenDrag) -> void :
	if e.index == _joy_idx:
		_joy_finger = e.position
		_update_joy()
		_eat()
	elif e.index == _cam_idx:
		var d: = e.position - _cam_last
		_cam_last = e.position
		_last_cam_touch = _t
		if rig:
			rig.touch_look(d)
		_eat()
	elif e.index == _jump_idx:

		var d2: = e.position - _jump_last
		_jump_last = e.position
		if rig and (_t - _jump_press_t > 0.06 or d2.length() > 6.0):
			rig.touch_look(d2)
			_last_cam_touch = _t
		_eat()

func _update_joy() -> void :
	var off: = _joy_finger - _joy_center
	var L: = off.length()
	if L > JOY_R * FOLLOW_K:

		_joy_center += off.normalized() * (L - JOY_R * FOLLOW_K)
		off = _joy_finger - _joy_center
		L = off.length()
	var m: = clampf(L / JOY_R, 0.0, 1.0)
	m = clampf((m - DEAD) / (FULL - DEAD), 0.0, 1.0)
	_joy_vec = off.normalized() * m if L > 0.001 else Vector2.ZERO
	_sprint = L > JOY_R * SPRINT_K
	_apply_move()

func _apply_move() -> void :
	var v: = _joy_vec
	Game.touch_stick_active = _joy_idx >= 0
	_set_action("move_right", maxf(v.x, 0.0))
	_set_action("move_left", maxf( - v.x, 0.0))
	_set_action("move_back", maxf(v.y, 0.0))
	_set_action("move_forward", maxf( - v.y, 0.0))
	if _sprint:
		Input.action_press("sprint")
	else:
		Input.action_release("sprint")

func _set_action(a: String, k: float) -> void :
	if k > 0.001:
		Input.action_press(a, k)
	else:
		Input.action_release(a)

func _eat() -> void :
	get_viewport().set_input_as_handled()


func _draw_pad() -> void :
	if mode == "cutscene":
		return
	if mode != "play":
		return
	var gold: = Color(1.0, 0.82, 0.42)

	var c: = _joy_center if _joy_idx >= 0 else _joy_rest()
	var a: = 0.55 if _joy_idx >= 0 else 0.22
	_pad.draw_circle(c, JOY_R + 18.0, Color(0, 0, 0, 0.18 * a / 0.55))
	_pad.draw_arc(c, JOY_R + 18.0, 0.0, TAU, 64, Color(1, 1, 1, a * 0.7), 3.0, true)
	if _sprint:
		_pad.draw_arc(c, JOY_R * SPRINT_K + 8.0, 0.0, TAU, 64, Color(gold.r, gold.g, gold.b, 0.85), 5.0, true)
	var kp: = c + _joy_vec.normalized() * minf((_joy_finger - c).length(), JOY_R) if _joy_idx >= 0 and _joy_vec.length() > 0.0 else c
	_pad.draw_circle(kp, 52.0, Color(1, 1, 1, a * 0.9))
	_pad.draw_arc(kp, 52.0, 0.0, TAU, 48, Color(0, 0, 0, a * 0.35), 2.0, true)

	var jc: = _jump_center()
	var pressed: = _jump_idx >= 0
	var jr: = JUMP_R * (0.93 if pressed else 1.0)
	_pad.draw_circle(jc, jr, Color(0, 0, 0, 0.28) if not pressed else Color(gold.r, gold.g, gold.b, 0.45))
	_pad.draw_arc(jc, jr, 0.0, TAU, 64, Color(1, 1, 1, 0.75), 4.0, true)
	var w: = 34.0
	var chev: = PackedVector2Array([jc + Vector2( - w, 14), jc + Vector2(0, -22), jc + Vector2(w, 14)])
	_pad.draw_polyline(chev, Color(1, 1, 1, 0.95), 9.0, true)
	var chev2: = PackedVector2Array([jc + Vector2( - w * 0.7, 40), jc + Vector2(0, 12), jc + Vector2(w * 0.7, 40)])
	_pad.draw_polyline(chev2, Color(1, 1, 1, 0.55), 7.0, true)

	var bc: = _breath_center()
	var bp: = _breath_idx >= 0
	_pad.draw_circle(bc, 62.0, Color(0.55, 0.75, 1.0, 0.45) if bp else Color(0, 0, 0, 0.26))
	_pad.draw_arc(bc, 62.0, 0.0, TAU, 48, Color(1, 1, 1, 0.7), 3.0, true)
	# breath icon: three soft waves
	for k in 3:
		var yy: = bc.y - 16.0 + k * 16.0
		var pts: = PackedVector2Array()
		for q in 13:
			var x: = bc.x - 26.0 + q * 52.0 / 12.0
			pts.append(Vector2(x, yy + sin(q * 0.8 + k) * 4.0))
		_pad.draw_polyline(pts, Color(1, 1, 1, 0.85), 4.0, true)

	var pc: = _pause_center()
	_pad.draw_circle(pc, 40.0, Color(0, 0, 0, 0.3))
	_pad.draw_rect(Rect2(pc + Vector2(-13, -15), Vector2(9, 30)), Color(1, 1, 1, 0.9))
	_pad.draw_rect(Rect2(pc + Vector2(4, -15), Vector2(9, 30)), Color(1, 1, 1, 0.9))
