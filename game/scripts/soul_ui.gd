extends CanvasLayer



signal replay_memory(z: int)

const GOLD: = Color(1.0, 0.8, 0.38)
const PAPER: = Color(0.97, 0.93, 0.83)
const INK: = Color(0.22, 0.14, 0.08)
const PHOTO_DIR: = "user://photos"

var main
var font_title: Font
var font_body: FontVariation
var root: Control

var _letter: Control
var _letter_text: Label
var _letter_count: Label
var _letter_tw: Tween

var _say_box: PanelContainer
var _say_who: Label
var _say_text: Label
var _say_tw: Tween
var _hint: Label
var _hint_tw: Tween

var album: Control
var _album_body: VBoxContainer
var _album_tab: = "memories"
var _viewer: TextureRect

var photo: Control
var _frame: Control
var _photo_btns: Control
var _flash: ColorRect
var photo_on: = false
var _frame_style: = 0
var _drag_idx: = -1
var _drag_last: = Vector2.ZERO
var _mouse_drag: = false
var _saved_rig: = {}

const MEMORY_TITLES: = {
	2: ["راديو الصبح", "السلّم والراديو، وأول مرة خفت فيها من العلو"], 
	3: ["الغرزة العوجة", "الإشي اللي بيستاهل بياخذ وقت"], 
	4: ["ليلة الحرارة", "بخاف من اليوم اللي ما تعود تحتاجني فيه"], 
	5: ["زيتونة يوم ميلادي", "بتشرب، وبتسكت، وبتطلع لفوق"], 
	6: ["آخر صيف", "العصفور اللي بيضل بالعش بينسى إنه إله جناحات"], 
}

func _ready() -> void :
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	font_title = load("res://assets/fonts/Lalezar.ttf")
	font_body = FontVariation.new()
	font_body.base_font = load("res://assets/fonts/Cairo.ttf")
	font_body.variation_opentype = {"wght": 600}
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_letter()
	_build_say()
	_build_album()
	_build_photo()

func _lbl(text: String, size: int, font: Font, col: Color, align: = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l: = Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _btn(text: String, cb: Callable, w: = 300.0) -> Button:
	var b: = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 76 if Game.touch else 60)
	b.add_theme_font_override("font", font_body)
	b.add_theme_font_size_override("font_size", 32 if Game.touch else 26)
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.16, 0.82)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(2)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	var sbh: = sb.duplicate() as StyleBoxFlat
	sbh.border_color = GOLD
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("focus", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.pressed.connect( func():
		Sfx.play("click", -6.0)
		cb.call())
	return b


func _build_letter() -> void :
	_letter = Control.new()
	_letter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letter.visible = false
	root.add_child(_letter)
	var card: = PanelContainer.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(6)
	sb.border_color = Color(0.72, 0.1, 0.12)
	sb.set_border_width_all(5)
	sb.content_margin_left = 46
	sb.content_margin_right = 46
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 18
	card.add_theme_stylebox_override("panel", sb)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -470
	card.offset_right = 470
	card.offset_top = -210
	card.offset_bottom = 190
	card.rotation_degrees = -1.5
	card.pivot_offset = Vector2(470, 200)
	_letter.add_child(card)
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	_letter_count = _lbl("", 24, font_body, Color(0.55, 0.12, 0.1))
	v.add_child(_letter_count)
	_letter_text = _lbl("", 34 if Game.touch else 31, font_body, INK)
	_letter_text.custom_minimum_size = Vector2(840, 0)
	v.add_child(_letter_text)
	var sig: = _lbl("— ستّك", 30, font_title, Color(0.55, 0.12, 0.1), HORIZONTAL_ALIGNMENT_LEFT)
	v.add_child(sig)

func show_letter(id: int, text: String, total: int) -> void :
	_letter_text.text = text
	var found: = 0
	for k in range(1, total + 1):
		if Game.story.get("L%d" % k, false):
			found += 1
	_letter_count.text = "رسالة من ستّك (%d من %d)" % [found, total]
	_letter.visible = true
	_letter.modulate.a = 0.0
	if _letter_tw:
		_letter_tw.kill()
	_letter_tw = create_tween()
	_letter_tw.tween_property(_letter, "modulate:a", 1.0, 0.5)
	_letter_tw.tween_interval(maxf(6.0, text.length() * 0.085))
	_letter_tw.tween_property(_letter, "modulate:a", 0.0, 0.9)
	_letter_tw.tween_callback( func(): _letter.visible = false)


func _build_say() -> void :
	_say_box = PanelContainer.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.09, 0.72)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	_say_box.add_theme_stylebox_override("panel", sb)
	_say_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_say_box.anchor_left = 0.5
	_say_box.anchor_right = 0.5
	_say_box.anchor_top = 1.0
	_say_box.anchor_bottom = 1.0
	_say_box.offset_left = -640
	_say_box.offset_right = 640
	_say_box.offset_top = -330 if Game.touch else -230
	_say_box.offset_bottom = -200 if Game.touch else -120
	_say_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_say_box.modulate.a = 0.0
	_say_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_say_box)
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_say_box.add_child(v)
	_say_who = _lbl("", 24, font_body, GOLD)
	v.add_child(_say_who)
	_say_text = _lbl("", 32 if Game.touch else 29, font_body, Color(0.97, 0.96, 0.93))
	v.add_child(_say_text)
	_hint = _lbl("", 24, font_body, Color(1, 1, 1, 0.8))
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -500
	_hint.offset_right = 500
	_hint.offset_top = -120 if Game.touch else -80
	_hint.offset_bottom = -80 if Game.touch else -40
	_hint.modulate.a = 0.0
	root.add_child(_hint)

func say(who: String, text: String, dur: = 4.5) -> void :
	_say_who.text = who
	_say_who.visible = who != ""
	_say_text.text = text
	if _say_tw:
		_say_tw.kill()
	_say_tw = create_tween()
	_say_tw.tween_property(_say_box, "modulate:a", 1.0, 0.35)
	_say_tw.tween_interval(dur)
	_say_tw.tween_property(_say_box, "modulate:a", 0.0, 0.7)

func show_hint_small(text: String) -> void :
	_hint.text = text
	if _hint_tw:
		_hint_tw.kill()
	_hint_tw = create_tween()
	_hint_tw.tween_property(_hint, "modulate:a", 1.0, 0.4)
	_hint_tw.tween_interval(3.5)
	_hint_tw.tween_property(_hint, "modulate:a", 0.0, 0.8)


func _build_album() -> void :
	album = Control.new()
	album.set_anchors_preset(Control.PRESET_FULL_RECT)
	album.layout_direction = Control.LAYOUT_DIRECTION_RTL
	album.visible = false
	album.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(album)
	var bg: = ColorRect.new()
	bg.color = Color(0.03, 0.035, 0.06, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	album.add_child(bg)
	var outer: = VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 60
	outer.offset_right = -60
	outer.offset_top = 30
	outer.offset_bottom = -30
	outer.add_theme_constant_override("separation", 14)
	album.add_child(outer)
	outer.add_child(_lbl("الألبوم", 84, font_title, GOLD))
	var tabs: = HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 14)
	outer.add_child(tabs)
	tabs.add_child(_btn("الذكريات", func(): _fill_album("memories"), 260))
	tabs.add_child(_btn("رسائل ستّي", func(): _fill_album("letters"), 260))
	tabs.add_child(_btn("صوري", func(): _fill_album("photos"), 260))
	var sc: = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(sc)
	_album_body = VBoxContainer.new()
	_album_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_album_body.add_theme_constant_override("separation", 12)
	sc.add_child(_album_body)
	var back: = _btn("رجوع", close_album, 300)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.add_child(back)
	_viewer = TextureRect.new()
	_viewer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_viewer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_viewer.visible = false
	_viewer.mouse_filter = Control.MOUSE_FILTER_STOP
	_viewer.gui_input.connect( func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_viewer.visible = false)
	album.add_child(_viewer)

func open_album() -> void :
	album.visible = true
	_fill_album(_album_tab)

func close_album() -> void :
	album.visible = false
	_viewer.visible = false
	if main and main.ui:
		main.ui.show_menu(Game.has_save())

func _card(title: String, sub: String, locked: bool) -> HBoxContainer:
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var pc: = PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.17, 0.9) if locked else Color(0.16, 0.13, 0.1, 0.92)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(1, 1, 1, 0.08) if locked else Color(GOLD.r, GOLD.g, GOLD.b, 0.5)
	sb.set_border_width_all(2)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	pc.add_theme_stylebox_override("panel", sb)
	var v: = VBoxContainer.new()
	pc.add_child(v)
	v.add_child(_lbl(title, 34, font_title, Color(0.6, 0.62, 0.7) if locked else GOLD, HORIZONTAL_ALIGNMENT_RIGHT))
	var s: = _lbl(sub, 25, font_body, Color(0.6, 0.62, 0.7) if locked else Color(0.95, 0.93, 0.88), HORIZONTAL_ALIGNMENT_RIGHT)
	v.add_child(s)
	row.add_child(pc)
	return row

func _fill_album(tab: String) -> void :
	_album_tab = tab
	for c in _album_body.get_children():
		c.queue_free()
	match tab:
		"memories":
			for z in MEMORY_TITLES.keys():
				var seen: bool = Game.album_has("memories", str(z))
				var row: = _card(MEMORY_TITLES[z][0] if seen else "؟ ذكرى ما لقيتها بعد", MEMORY_TITLES[z][1] if seen else "بتلاقيها بمحطة المرحلة %d" % z, not seen)
				if seen:
					var zz: int = z
					row.add_child(_btn("شوف", func():
						album.visible = false
						replay_memory.emit(zz), 170))
				_album_body.add_child(row)
		"letters":
			var texts: Array = main.soul.LETTERS if main and main.soul else []
			for k in texts.size():
				var got: bool = Game.album_has("letters", str(k + 1))
				_album_body.add_child(_card("الرسالة %d" % (k + 1), String(texts[k][1]) if got else "حمامة بتستناك بمكان واسع… دوّر عليها.", not got))
		"photos":
			var files: = _photo_files()
			if files.is_empty():
				_album_body.add_child(_lbl("لسّا ما صوّرت إشي. من قائمة الاستراحة اختار «وضع التصوير».", 28, font_body, Color(0.85, 0.86, 0.9)))
			var grid: = GridContainer.new()
			grid.columns = 3
			grid.add_theme_constant_override("h_separation", 14)
			grid.add_theme_constant_override("v_separation", 14)
			_album_body.add_child(grid)
			for f in files:
				var img: = Image.load_from_file(PHOTO_DIR + "/" + f)
				if img == null or img.is_empty():
					continue
				var full: = ImageTexture.create_from_image(img)
				img.resize(480, int(480.0 * img.get_height() / maxf(img.get_width(), 1)))
				var tex: = ImageTexture.create_from_image(img)
				var tb: = TextureButton.new()
				tb.texture_normal = tex
				tb.ignore_texture_size = true
				tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
				tb.custom_minimum_size = Vector2(480, 270)
				tb.pressed.connect( func():
					_viewer.texture = full
					_viewer.visible = true)
				grid.add_child(tb)

func _photo_files() -> Array:
	var out: = []
	var d: = DirAccess.open(PHOTO_DIR)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".png"):
			out.append(f)
	out.sort()
	out.reverse()
	return out.slice(0, 30)


func _build_photo() -> void :
	photo = Control.new()
	photo.set_anchors_preset(Control.PRESET_FULL_RECT)
	photo.visible = false
	photo.mouse_filter = Control.MOUSE_FILTER_STOP
	photo.gui_input.connect(_photo_input)
	root.add_child(photo)
	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	photo.add_child(_frame)
	_photo_btns = HBoxContainer.new()
	_photo_btns.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_photo_btns.anchor_left = 0.5
	_photo_btns.anchor_right = 0.5
	_photo_btns.anchor_top = 1.0
	_photo_btns.anchor_bottom = 1.0
	_photo_btns.offset_left = -560
	_photo_btns.offset_right = 560
	_photo_btns.offset_top = -150
	_photo_btns.offset_bottom = -60
	(_photo_btns as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	(_photo_btns as HBoxContainer).add_theme_constant_override("separation", 14)
	photo.add_child(_photo_btns)
	_photo_btns.add_child(_btn("رجوع", exit_photo, 170))
	_photo_btns.add_child(_btn("إطار", func():
		_frame_style = (_frame_style + 1) % 3
		_frame.queue_redraw(), 170))
	_photo_btns.add_child(_btn("−", func(): _zoom(1.0), 90))
	_photo_btns.add_child(_btn("+", func(): _zoom(-1.0), 90))
	var shoot: = _btn("التقط", take_photo, 230)
	_photo_btns.add_child(shoot)
	var tip: = _lbl("اسحب لتلف الكاميرا", 22, font_body, Color(1, 1, 1, 0.7))
	tip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tip.anchor_top = 1.0
	tip.anchor_bottom = 1.0
	tip.anchor_left = 0.5
	tip.anchor_right = 0.5
	tip.offset_left = -300
	tip.offset_right = 300
	tip.offset_top = -52
	tip.offset_bottom = -20
	tip.name = "Tip"
	photo.add_child(tip)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.add_child(_flash)

func enter_photo() -> void :
	if main == null or photo_on:
		return
	photo_on = true
	var rig = main.rig
	_saved_rig = {"distance": rig.distance, "pitch": rig.pitch, "yaw": rig.yaw}
	main.get_tree().paused = false
	main.ui._show_only(null)
	main.ui.show_hud(false)
	if main.touch:
		main.touch.set_mode("off")
	main.photo_mode(true)
	photo.visible = true
	_frame.queue_redraw()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func exit_photo() -> void :
	if not photo_on:
		return
	photo_on = false
	photo.visible = false
	var rig = main.rig
	rig.distance = _saved_rig.get("distance", 6.0)
	main.photo_mode(false)

func _zoom(d: float) -> void :
	var rig = main.rig
	rig.distance = clampf(rig.distance + d * 1.2, 1.6, 16.0)

func _photo_input(e: InputEvent) -> void :
	var rig = main.rig if main else null
	if rig == null:
		return
	if e is InputEventScreenTouch:
		if e.pressed and _drag_idx < 0:
			_drag_idx = e.index
			_drag_last = e.position
		elif not e.pressed and e.index == _drag_idx:
			_drag_idx = -1
	elif e is InputEventScreenDrag and e.index == _drag_idx:
		rig.touch_look(e.position - _drag_last)
		_drag_last = e.position
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			_mouse_drag = e.pressed
			_drag_last = e.position
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			_zoom(-0.5)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			_zoom(0.5)
	elif e is InputEventMouseMotion and _mouse_drag and not Game.touch:
		rig.touch_look((e.position - _drag_last) * 0.8)
		_drag_last = e.position

func _unhandled_input(e: InputEvent) -> void :
	if photo_on and e.is_action_pressed("pause"):
		exit_photo()
		get_viewport().set_input_as_handled()

func take_photo() -> void :
	_photo_btns.visible = false
	photo.get_node("Tip").visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	_photo_btns.visible = true
	photo.get_node("Tip").visible = true
	DirAccess.make_dir_recursive_absolute(PHOTO_DIR)
	var stamp: = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var fname: = "talaa_%s.png" % stamp
	img.save_png(PHOTO_DIR + "/" + fname)
	var where: = "بالألبوم"

	if not OS.has_feature("mobile"):
		var pics: = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
		if pics != "":
			var dir: = pics.path_join("Talaa")
			if DirAccess.make_dir_recursive_absolute(dir) == OK and img.save_png(dir.path_join(fname)) == OK:
				where = "بالألبوم وبمجلد الصور (Talaa)"
	Sfx.play("shutter", -2.0)
	Game.haptic(25, 0.5)
	_flash.color = Color(1, 1, 1, 0.85)
	var tw: = create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.45)
	say("", "انحفظت الصورة " + where, 2.2)

func _draw_frame() -> void :
	var s: = _frame.get_viewport_rect().size
	var gold: = GOLD
	var m: = 26.0
	if _frame_style == 2:
		return

	var dark: = Color(0.02, 0.02, 0.04, 0.55)
	_frame.draw_rect(Rect2(0, 0, s.x, m), dark)
	_frame.draw_rect(Rect2(0, s.y - m, s.x, m), dark)
	_frame.draw_rect(Rect2(0, 0, m, s.y), dark)
	_frame.draw_rect(Rect2(s.x - m, 0, m, s.y), dark)

	_frame.draw_rect(Rect2(m, m, s.x - 2 * m, s.y - 2 * m), gold, false, 4.0)
	_frame.draw_rect(Rect2(m + 12, m + 12, s.x - 2 * m - 24, s.y - 2 * m - 24), Color(gold.r, gold.g, gold.b, 0.6), false, 2.0)

	for c in [Vector2(m + 12, m + 12), Vector2(s.x - m - 12, m + 12), Vector2(m + 12, s.y - m - 12), Vector2(s.x - m - 12, s.y - m - 12)]:
		_star8(c, 34.0, gold)
	if _frame_style == 0:

		var fx: = s.x * 0.12
		_frame.draw_line(Vector2(fx, m), Vector2(fx, m + 70), gold, 3.0)
		var top: = m + 70.0
		var body: = PackedVector2Array([Vector2(fx - 26, top + 20), Vector2(fx + 26, top + 20), Vector2(fx + 34, top + 70), Vector2(fx + 22, top + 110), Vector2(fx - 22, top + 110), Vector2(fx - 34, top + 70)])
		_frame.draw_colored_polygon(body, Color(1.0, 0.72, 0.3, 0.85))
		_frame.draw_polyline(body + PackedVector2Array([body[0]]), gold, 3.0)
		_frame.draw_colored_polygon(PackedVector2Array([Vector2(fx - 26, top + 20), Vector2(fx, top - 4), Vector2(fx + 26, top + 20)]), gold)
		_frame.draw_colored_polygon(PackedVector2Array([Vector2(fx - 22, top + 110), Vector2(fx + 22, top + 110), Vector2(fx, top + 130)]), gold)
		_frame.draw_circle(Vector2(fx, top + 65), 10.0, Color(1, 0.95, 0.8, 0.95))
		_crescent(Vector2(s.x * 0.88, m + 90.0), 36.0, gold)

	var h: = 0
	if main and main.player:
		h = int(main.player.global_position.y)
	var zname: = ""
	if main and main.level:
		var z: int = main.level.zone_at(main.player.global_position.y)
		zname = String(main.level.zones[z - 1].name)
	var cap: = "طَلْعة  •  %s  •  %d م" % [zname, h]
	var fs: = 34
	var tw: = font_title.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_frame.draw_rect(Rect2(s.x * 0.5 - tw * 0.5 - 24, m + 18, tw + 48, 52), Color(0.02, 0.02, 0.04, 0.6))
	_frame.draw_string(font_title, Vector2(s.x * 0.5 - tw * 0.5, m + 58), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, gold)

func _star8(c: Vector2, r: float, col: Color) -> void :
	var pts: = PackedVector2Array()
	for k in 16:
		var a: = k * TAU / 16.0 - PI * 0.5
		var rr: = r if k % 2 == 0 else r * 0.55
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	_frame.draw_colored_polygon(pts, col)
	_frame.draw_circle(c, r * 0.25, Color(0.02, 0.02, 0.04, 0.9))

func _crescent(c: Vector2, r: float, col: Color) -> void :
	var off: = Vector2(0.42, -0.2) * r
	var ri: = r * 0.86
	var phi: = ( - off).angle()
	var pts: = PackedVector2Array()
	for k in 65:
		var a: = phi - PI + TAU * k / 64.0
		var q: = c + Vector2(cos(a), sin(a)) * r
		if q.distance_to(c + off) > ri:
			pts.append(q)
	for k in 65:
		var a2: = phi + PI - TAU * k / 64.0
		var q2: = c + off + Vector2(cos(a2), sin(a2)) * ri
		if q2.distance_to(c) < r:
			pts.append(q2)
	if pts.size() >= 3:
		_frame.draw_colored_polygon(pts, col)
