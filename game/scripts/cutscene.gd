extends Node













signal finished(skipped: bool)

const WHO: = {
	"grandma": ["ستّي", Color(1.0, 0.8, 0.42)], 
	"hero": ["سليم", Color(0.62, 0.84, 1.0)], 
	"child": ["سليم", Color(0.72, 0.9, 1.0)], 
	"musahhir": ["المسحّراتي", Color(0.95, 0.8, 0.6)], 
	"": ["", Color(1, 1, 1)], 
}

var cam: Camera3D
var active: = false
var _layer: CanvasLayer
var _bar_top: ColorRect
var _bar_bot: ColorRect
var _black: ColorRect
var _sub_who: Label
var _sub_text: Label
var _sub_box: VBoxContainer
var _title: Label
var _title_sub: Label
var _skip_label: Label
var _skip_fill: ColorRect
var _shots: Array = []
var _i: = -1
var _t: = 0.0
var _shot: Dictionary
var _fired: = {}
var _lines_shown: = {}
var _skip_hold: = 0.0
var _on_done: Callable
var _restore_cam: Camera3D
var _sub_tw: Tween
var _title_tw: Tween
var _black_tw: Tween
var _bars_tw: Tween
var _noise_t: = 0.0
var _ending: = false
var _skip_armed: = false
var voice

func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	cam = Camera3D.new()
	cam.name = "CineCam"
	cam.near = 0.05
	cam.far = 6000.0
	cam.fov = 50.0
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(cam)
	_layer = CanvasLayer.new()
	_layer.layer = 30
	add_child(_layer)
	var root: = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	_bar_top = _bar(root, true)
	_bar_bot = _bar(root, false)

	_sub_box = VBoxContainer.new()
	_sub_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sub_box.anchor_left = 0.5
	_sub_box.anchor_right = 0.5
	_sub_box.anchor_top = 1.0
	_sub_box.anchor_bottom = 1.0
	_sub_box.offset_left = -820
	_sub_box.offset_right = 820
	_sub_box.offset_top = -250
	_sub_box.offset_bottom = -135
	_sub_box.alignment = BoxContainer.ALIGNMENT_END
	_sub_box.add_theme_constant_override("separation", -4)
	_sub_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_box.modulate.a = 0.0
	root.add_child(_sub_box)
	var cairo: Font = load("res://assets/fonts/Cairo.ttf")
	var bold: = FontVariation.new()
	bold.base_font = cairo
	bold.variation_opentype = {"wght": 800}
	var body: = FontVariation.new()
	body.base_font = cairo
	body.variation_opentype = {"wght": 600}
	_sub_who = _mk_label(bold, 28, Color(1, 0.8, 0.4))
	_sub_box.add_child(_sub_who)
	_sub_text = _mk_label(body, 38, Color(1, 1, 1))
	_sub_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_box.add_child(_sub_text)

	_title = _mk_label(load("res://assets/fonts/Lalezar.ttf"), 190, Color(1.0, 0.84, 0.5))
	_title.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02, 0.8))
	_title.add_theme_constant_override("outline_size", 14)
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.anchor_left = 0.5
	_title.anchor_right = 0.5
	_title.anchor_top = 0.5
	_title.anchor_bottom = 0.5
	_title.offset_left = -900
	_title.offset_right = 900
	_title.offset_top = -170
	_title.offset_bottom = 40
	_title.modulate.a = 0.0
	root.add_child(_title)
	_title_sub = _mk_label(body, 60, Color(1, 0.97, 0.9, 1.0))
	_title_sub.set_anchors_preset(Control.PRESET_CENTER)
	_title_sub.anchor_left = 0.5
	_title_sub.anchor_right = 0.5
	_title_sub.anchor_top = 0.5
	_title_sub.anchor_bottom = 0.5
	_title_sub.offset_left = -900
	_title_sub.offset_right = 900
	_title_sub.offset_top = 40
	_title_sub.offset_bottom = 110
	_title_sub.modulate.a = 0.0
	root.add_child(_title_sub)

	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 1)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.modulate.a = 0.0
	root.add_child(_black)

	root.move_child(_title, root.get_child_count() - 1)
	root.move_child(_title_sub, root.get_child_count() - 1)

	_skip_label = _mk_label(body, 22, Color(1, 1, 1, 0.55))
	_skip_label.text = "المس الشاشة مطوّلاً للتخطي" if Game.touch else "اضغط مطوّلاً Space للتخطي"
	_skip_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_skip_label.offset_left = 40
	_skip_label.offset_top = 28
	_skip_label.offset_right = 520
	_skip_label.offset_bottom = 64
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_skip_label.modulate.a = 0.0
	root.add_child(_skip_label)
	voice = load("res://scripts/voice.gd").new()
	voice.name = "Voice"
	add_child(voice)
	_skip_fill = ColorRect.new()
	_skip_fill.color = Color(1.0, 0.8, 0.42, 0.9)
	_skip_fill.position = Vector2(40, 66)
	_skip_fill.size = Vector2(0, 3)
	root.add_child(_skip_fill)
	_layer.visible = false

func _bar(root: Control, top: bool) -> ColorRect:
	var r: = ColorRect.new()
	r.color = Color(0, 0, 0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	if top:
		r.anchor_top = 0.0
		r.anchor_bottom = 0.0
	else:
		r.anchor_top = 1.0
		r.anchor_bottom = 1.0
	r.offset_top = 0
	r.offset_bottom = 0
	root.add_child(r)
	return r

func _mk_label(font: Font, size: int, col: Color) -> Label:
	var l: = Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.text_direction = Control.TEXT_DIRECTION_RTL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func play(shots: Array, on_done: Callable, start_black: = false) -> void :
	_fit_to_voice(shots)
	_shots = shots
	_on_done = on_done
	_i = -1
	active = true
	_ending = false
	_skip_hold = 0.0
	_skip_armed = false
	_restore_cam = get_viewport().get_camera_3d()
	cam.make_current()
	_layer.visible = true
	_set_bars(true, 0.8)
	_black.modulate.a = 1.0 if start_black else 0.0
	var tw: = create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_skip_label, "modulate:a", 1.0, 0.8)
	_next()

func black(to: float, dur: float) -> Tween:
	if _black_tw:
		_black_tw.kill()
	_layer.visible = true
	_black_tw = create_tween()
	_black_tw.tween_property(_black, "modulate:a", to, dur)
	_black_tw.tween_callback( func():
		if not active and _black.modulate.a < 0.01:
			_layer.visible = false)
	return _black_tw

func _fit_to_voice(shots: Array) -> void :

	for sh in shots:
		var lines: Array = sh.get("lines", [])
		if lines.is_empty():
			continue
		var next_free: = 0.0
		var end: = 0.0
		for ln in lines:
			var text: = String(ln[2])
			var base: float = float(ln[3]) if ln.size() > 3 else 1.6 + text.length() * 0.068
			var vl: float = voice.length(text) if voice else 0.0
			var d: = maxf(base, vl + 0.5)
			var t0: = maxf(float(ln[0]), next_free)
			ln[0] = t0
			if ln.size() > 3:
				ln[3] = d
			else:
				ln.append(d)
			next_free = t0 + d + 0.3
			end = maxf(end, t0 + d)
		sh["dur"] = maxf(float(sh.get("dur", 3.0)), end + 0.9)

func say(who: String, text: String, dur: = -1.0) -> void :
	if voice:
		voice.speak(text)
	var info: Array = WHO.get(who, WHO[""])
	_sub_who.text = info[0]
	_sub_who.add_theme_color_override("font_color", info[1])
	_sub_who.visible = info[0] != ""
	_sub_text.text = text
	_sub_text.add_theme_color_override("font_color", Color(1, 1, 1) if who != "" else Color(0.95, 0.92, 0.84))
	if dur < 0.0:
		dur = 1.6 + text.length() * 0.068
	if _sub_tw:
		_sub_tw.kill()
	_sub_tw = create_tween()
	_sub_box.modulate.a = 0.0
	_sub_tw.tween_property(_sub_box, "modulate:a", 1.0, 0.35)
	_sub_tw.tween_interval(dur)
	_sub_tw.tween_property(_sub_box, "modulate:a", 0.0, 0.4)

func show_title(text: String, sub: = "", dur: = 3.0) -> void :
	_title.text = text
	_title_sub.text = sub
	if _title_tw:
		_title_tw.kill()
	_title_tw = create_tween().set_parallel(true)
	_title.modulate.a = 0.0
	_title_sub.modulate.a = 0.0
	_title.scale = Vector2.ONE
	_title_tw.tween_property(_title, "modulate:a", 1.0, 1.0)
	_title_tw.tween_property(_title_sub, "modulate:a", 1.0, 1.0).set_delay(0.5)
	_title_tw.chain().tween_interval(dur)
	_title_tw.chain().tween_property(_title, "modulate:a", 0.0, 1.0)
	_title_tw.parallel().tween_property(_title_sub, "modulate:a", 0.0, 1.0)


func _set_bars(on: bool, dur: float) -> void :
	var h: = get_viewport().get_visible_rect().size.y * 0.115
	if _bars_tw:
		_bars_tw.kill()
	_bars_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bars_tw.tween_property(_bar_top, "offset_bottom", h if on else 0.0, dur)
	_bars_tw.tween_property(_bar_bot, "offset_top", - h if on else 0.0, dur)

func _next() -> void :
	_i += 1
	if _i >= _shots.size():
		_finish(false)
		return
	_shot = _shots[_i]
	_t = 0.0
	_fired.clear()
	_lines_shown.clear()
	var fi: float = _shot.get("fade_in", 0.0)
	if fi > 0.0:
		_black.modulate.a = 1.0
		black(0.0, fi)
	_apply_cam(0.0)

func _ease(k: float) -> float:
	match String(_shot.get("ease", "inout")):
		"linear":
			return k
		"out":
			return 1.0 - pow(1.0 - k, 3.0)
		"in":
			return k * k * k
	return k * k * (3.0 - 2.0 * k) if k < 1.0 else 1.0

func _apply_cam(t: float) -> void :
	var dur: float = maxf(float(_shot.get("dur", 3.0)), 0.01)
	var k: = _ease(clampf(t / dur, 0.0, 1.0))
	var fr: Array = _shot.get("from", [Vector3(0, 10, 10), Vector3.ZERO])
	var to: Array = _shot.get("to", fr)
	var p: Vector3 = (fr[0] as Vector3).lerp(to[0], k)
	var l: Vector3 = (fr[1] as Vector3).lerp(to[1], k)
	if _shot.has("look_node"):
		var nd: Node3D = _shot.look_node
		if is_instance_valid(nd):
			l = nd.global_position + (_shot.get("look_off", Vector3(0, 1.2, 0)) as Vector3)
	var sway: float = _shot.get("sway", 0.035)
	_noise_t += get_process_delta_time()
	var drift: = Vector3(sin(_noise_t * 0.71) + 0.5 * sin(_noise_t * 1.37 + 1.1), sin(_noise_t * 0.53 + 2.0) + 0.4 * sin(_noise_t * 1.9), 0.0) * sway
	cam.global_position = p
	if p.distance_to(l) > 0.01:
		var up: = Vector3.UP
		if absf((l - p).normalized().dot(up)) > 0.98:
			up = Vector3.FORWARD
		cam.look_at(l, up)
	cam.rotate_object_local(Vector3.RIGHT, drift.y * 0.25)
	cam.rotate_object_local(Vector3.UP, drift.x * 0.25)
	var fov = _shot.get("fov", 50.0)
	if fov is Array:
		cam.fov = lerpf(float(fov[0]), float(fov[1]), k)
	else:
		cam.fov = float(fov)

func _process(delta: float) -> void :
	if not active:
		return

	var held: = Input.is_action_pressed("jump") or Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_ESCAPE)
	if not held:
		_skip_armed = true
	if held and _skip_armed:
		_skip_hold += delta
	else:
		_skip_hold = maxf(_skip_hold - delta * 2.0, 0.0)
	_skip_fill.size = Vector2(clampf(_skip_hold / 0.9, 0.0, 1.0) * 300.0, 3)
	if _skip_hold > 0.9 and not _ending:
		_skip()
		return
	if _ending:
		return
	_t += delta
	var dur: float = _shot.get("dur", 3.0)

	var evs: Array = _shot.get("ev", [])
	for j in evs.size():
		if not _fired.has(j) and _t >= float(evs[j][0]):
			_fired[j] = true
			var c: Callable = evs[j][1]
			if c.is_valid():
				c.call()
	var lines: Array = _shot.get("lines", [])
	for j in lines.size():
		if not _lines_shown.has(j) and _t >= float(lines[j][0]):
			_lines_shown[j] = true
			var ln: Array = lines[j]
			say(String(ln[1]), String(ln[2]), float(ln[3]) if ln.size() > 3 else -1.0)
	if _shot.has("title") and not _fired.has("title") and _t >= float(_shot.title[0]):
		_fired["title"] = true
		show_title(_shot.title[1], _shot.title[2], float(_shot.title[3]))
	var fo: float = _shot.get("fade_out", 0.0)
	if fo > 0.0 and not _fired.has("fo") and _t >= dur - fo:
		_fired["fo"] = true
		black(1.0, fo)
	_apply_cam(_t)
	if _t >= dur:
		_next()

func _skip() -> void :
	_ending = true
	Sfx.play("swell", -6.0)
	black(1.0, 0.35).tween_callback( func():
		_finish(true))

func _finish(skipped: bool) -> void :

	active = false
	_ending = true
	if skipped and voice:
		voice.stop()
	if _sub_tw:
		_sub_tw.kill()
	_sub_box.modulate.a = 0.0
	if _title_tw:
		_title_tw.kill()
	_title.modulate.a = 0.0
	_title_sub.modulate.a = 0.0
	_skip_label.modulate.a = 0.0
	_skip_fill.size = Vector2(0, 3)
	_set_bars(false, 0.6)
	if is_instance_valid(_restore_cam):
		_restore_cam.make_current()
	var cb: = _on_done
	_on_done = Callable()
	if cb.is_valid():
		cb.call(skipped)
	finished.emit(skipped)
	var tw: = create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback( func():
		if not active:
			_layer.visible = _black.modulate.a > 0.01)

func hide_layer_if_idle() -> void :
	if not active:
		_layer.visible = false
