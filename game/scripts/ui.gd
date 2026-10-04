extends CanvasLayer


signal play_pressed(new_game: bool)
signal resume_pressed
signal quit_to_menu_pressed
signal character_changed
signal album_pressed
signal photo_pressed
signal village_pressed
signal village_leave_pressed

const GOLD: = Color(1.0, 0.8, 0.38)
const PANEL_BG: = Color(0.05, 0.06, 0.1, 0.72)

var theme_main: Theme
var font_title: Font
var font_body: FontVariation
var font_bold: FontVariation

var root: Control
var fade: ColorRect
var loading: Control
var menu: Control
var pause_menu: Control
var settings_panel: Control
var confirm_panel: Control
var hud: Control
var ending: Control
var char_panel: Control
var ach_panel: Control
var _ach_list: VBoxContainer
var _toast: PanelContainer
var _toast_title: Label
var _toast_desc: Label
var _toast_q: Array = []
var _toast_busy: = false
var split_label: Label
var _split_tw: Tween

var alt_label: Label
var alt_unit: Label
var time_label: Label
var zone_card: Label
var zone_sub: Label
var fall_label: Label
var hint_label: Label
var tip_label: Label
var _tip_tw: Tween
var bar: Control
var bar_marker: ColorRect
var bar_best: ColorRect
var btn_continue: Button
var ending_stats: Label
var char_name: Label
var _settings_back_to: = ""
var _zone_tw: Tween
var _fall_tw: Tween
var max_height: = 1000.0
var zones: Array = []
var vignette: ColorRect
var _vig_amt: = 0.0
var _fall_live: = false

func _ready() -> void :
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_theme()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme_main
	add_child(root)
	_build_vignette()
	_build_hud()
	_build_menu()
	_build_pause()
	_build_settings()
	_build_confirm()
	_build_ending()
	_build_characters()
	_build_loading()
	_build_achievements()
	_build_toast()
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)


func _make_theme() -> void :
	font_title = load("res://assets/fonts/Lalezar.ttf")
	var cairo: Font = load("res://assets/fonts/Cairo.ttf")
	font_body = FontVariation.new()
	font_body.base_font = cairo
	font_body.variation_opentype = {"wght": 500}
	font_bold = FontVariation.new()
	font_bold.base_font = cairo
	font_bold.variation_opentype = {"wght": 800}
	theme_main = Theme.new()
	theme_main.default_font = font_body
	theme_main.default_font_size = 26
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.16, 0.78)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(2)
	var sbh: = sb.duplicate() as StyleBoxFlat
	sbh.bg_color = Color(0.16, 0.18, 0.26, 0.9)
	sbh.border_color = GOLD
	var sbp: = sb.duplicate() as StyleBoxFlat
	sbp.bg_color = Color(0.9, 0.68, 0.28, 0.95)
	var sbf: = sbh.duplicate() as StyleBoxFlat
	theme_main.set_stylebox("normal", "Button", sb)
	theme_main.set_stylebox("hover", "Button", sbh)
	theme_main.set_stylebox("pressed", "Button", sbp)
	theme_main.set_stylebox("focus", "Button", sbf)
	theme_main.set_stylebox("disabled", "Button", sb)
	theme_main.set_font("font", "Button", font_bold)
	theme_main.set_font_size("font_size", "Button", 30)
	theme_main.set_color("font_color", "Button", Color(0.95, 0.95, 0.97))
	theme_main.set_color("font_hover_color", "Button", GOLD)
	theme_main.set_color("font_focus_color", "Button", GOLD)
	theme_main.set_color("font_pressed_color", "Button", Color(0.1, 0.08, 0.05))
	var panel: = StyleBoxFlat.new()
	panel.bg_color = PANEL_BG
	panel.set_corner_radius_all(24)
	panel.content_margin_left = 40
	panel.content_margin_right = 40
	panel.content_margin_top = 30
	panel.content_margin_bottom = 30
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 24
	theme_main.set_stylebox("panel", "PanelContainer", panel)
	theme_main.set_color("font_color", "Label", Color(0.97, 0.97, 0.98))
	theme_main.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	theme_main.set_constant("shadow_offset_x", "Label", 0)
	theme_main.set_constant("shadow_offset_y", "Label", 2)
	theme_main.set_constant("shadow_outline_size", "Label", 6)

	var grab: = StyleBoxFlat.new()
	grab.bg_color = GOLD
	grab.set_corner_radius_all(8)
	var track: = StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.15)
	track.set_corner_radius_all(6)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	theme_main.set_stylebox("slider", "HSlider", track)
	theme_main.set_stylebox("grabber_area", "HSlider", grab)
	theme_main.set_stylebox("grabber_area_highlight", "HSlider", grab)
	theme_main.set_font_size("font_size", "CheckButton", 26)
	var empty: = StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		theme_main.set_stylebox(st, "CheckButton", empty)
	theme_main.set_font_size("font_size", "OptionButton", 24)
	theme_main.set_stylebox("normal", "OptionButton", sb)
	theme_main.set_stylebox("hover", "OptionButton", sbh)
	theme_main.set_stylebox("pressed", "OptionButton", sbh)
	theme_main.set_stylebox("focus", "OptionButton", sbf)
	theme_main.set_font_size("font_size", "PopupMenu", 24)

func _label(text: String, size: = 26, font: Font = null, color: = Color.WHITE) -> Label:
	var l: = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _button(text: String, cb: Callable) -> Button:
	var b: = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(480, 80) if Game.touch else Vector2(420, 66)
	if Game.touch:
		b.add_theme_font_size_override("font_size", 36)
	b.pressed.connect( func():
		Sfx.play("click", -6.0)
		cb.call())
	b.mouse_entered.connect( func(): Sfx.play("hover", -16.0))
	return b

func _center_box(parent: Control) -> VBoxContainer:
	var cc: = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	var v: = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	cc.add_child(v)
	return v

func _full(name_: String) -> Control:
	var c: = Control.new()
	c.name = name_
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.layout_direction = Control.LAYOUT_DIRECTION_RTL
	c.visible = false
	root.add_child(c)
	return c


func _build_loading() -> void :
	loading = _full("Loading")
	loading.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg: = ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading.add_child(bg)
	var v: = _center_box(loading)
	v.add_child(_label("طَلْعة", 140, font_title, GOLD))
	v.add_child(_label("جاري بناء الطريق إلى السماء...", 30, font_body, Color(0.8, 0.82, 0.88)))
	loading.visible = true

func hide_loading() -> void :
	var tw: = create_tween()
	tw.tween_property(loading, "modulate:a", 0.0, 0.8)
	tw.tween_callback( func(): loading.visible = false)


func _build_menu() -> void :
	menu = _full("Menu")
	menu.layout_direction = Control.LAYOUT_DIRECTION_LTR
	var grad: = TextureRect.new()
	var gt: = GradientTexture2D.new()
	var g: = Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0, 0, 0, 0.65))
	gt.gradient = g
	gt.fill_from = Vector2(0.35, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	grad.texture = gt
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(grad)
	var box: = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -620
	box.offset_right = -110
	box.offset_top = -500 if Game.touch else -440
	box.offset_bottom = 500 if Game.touch else 440
	box.add_theme_constant_override("separation", 10 if Game.touch else 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_child(box)
	var title: = _label("طَلْعة", 130 if Game.touch else 150, font_title, GOLD)
	box.add_child(title)
	var sub: = _label("كل ما تطلع أعلى… السقطة أطول. وما في طريق غير لفوق", 30, font_body, Color(0.92, 0.92, 0.96))
	box.add_child(sub)
	var sp: = Control.new()
	sp.custom_minimum_size = Vector2(0, 26)
	box.add_child(sp)
	btn_continue = _button("متابعة", func(): play_pressed.emit(false))
	box.add_child(btn_continue)
	box.add_child(_button("لعبة جديدة", _on_new_game))
	box.add_child(_button("الألبوم", func(): album_pressed.emit()))
	box.add_child(_button("الإنجازات", func():
		_refresh_achievements()
		_show_only(ach_panel)))
	box.add_child(_button("الإعدادات", func(): open_settings("menu")))
	box.add_child(_button("خروج", func(): get_tree().quit()))
	var credit: = _label("صُنعت بمحرك Godot • الشخصيات مبنية على MakeHuman (CC0)", 18, font_body, Color(1, 1, 1, 0.55))
	credit.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	credit.anchor_top = 1.0
	credit.anchor_bottom = 1.0
	credit.offset_left = 30
	credit.offset_top = -50
	credit.offset_right = 800
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	menu.add_child(credit)

func show_menu(has_save: bool) -> void :
	btn_continue.visible = has_save
	_show_only(menu)
	hud.visible = false
	(btn_continue if has_save else menu.find_children("*", "Button", true, false)[1]).grab_focus.call_deferred()

func _show_only(c: Control) -> void :
	for x in [menu, pause_menu, settings_panel, confirm_panel, ending, char_panel, ach_panel]:
		x.visible = x == c

func _on_new_game() -> void :
	if Game.has_save():
		_show_only(confirm_panel)
	else:
		play_pressed.emit(true)


func _build_confirm() -> void :
	confirm_panel = _full("Confirm")
	var v: = _center_box(confirm_panel)
	var pc: = PanelContainer.new()
	v.add_child(pc)
	var inner: = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 18)
	pc.add_child(inner)
	inner.add_child(_label("بدك تبلّش من الأول؟", 40, font_bold, GOLD))
	inner.add_child(_label("رح ينمسح مكانك الحالي وكل إحصائياتك.", 26))
	var h: = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	inner.add_child(h)
	var yes: = _button("آه، من الأول", func(): play_pressed.emit(true))
	yes.custom_minimum_size = Vector2(260, 62)
	var no: = _button("لا، رجوع", func(): _show_only(menu))
	no.custom_minimum_size = Vector2(260, 62)
	h.add_child(yes)
	h.add_child(no)


func _build_characters() -> void :
	char_panel = _full("Characters")
	char_panel.layout_direction = Control.LAYOUT_DIRECTION_LTR
	var box: = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -360
	box.offset_right = 360
	box.offset_top = -260
	box.offset_bottom = -60
	box.add_theme_constant_override("separation", 14)
	char_panel.add_child(box)
	char_name = _label("", 54, font_title, GOLD)
	box.add_child(char_name)
	var h: = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	box.add_child(h)
	var prev: = _button("السابق", func(): _cycle_char(-1))
	prev.custom_minimum_size = Vector2(200, 62)
	var ok: = _button("اختيار", func(): _show_only(menu))
	ok.custom_minimum_size = Vector2(200, 62)
	var nxt: = _button("التالي", func(): _cycle_char(1))
	nxt.custom_minimum_size = Vector2(200, 62)
	h.add_child(nxt)
	h.add_child(ok)
	h.add_child(prev)
	_update_char_name()

func _cycle_char(d: int) -> void :
	var ids: = []
	for c in Game.CHARACTERS:
		ids.append(c.id)
	var i: = ids.find(Game.settings.character)
	i = (i + d + ids.size()) % ids.size()
	Game.settings.character = ids[i]
	Game.save_settings()
	_update_char_name()
	character_changed.emit()

func _update_char_name() -> void :
	for c in Game.CHARACTERS:
		if c.id == Game.settings.character:
			char_name.text = c.name


func _build_pause() -> void :
	pause_menu = _full("Pause")
	var dim: = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(dim)
	var v: = _center_box(pause_menu)
	v.add_child(_label("استراحة", 90, font_title, GOLD))
	v.add_child(_button("استئناف", func(): resume_pressed.emit()))
	v.add_child(_button("وضع التصوير", func(): photo_pressed.emit()))
	btn_village_leave = _button("العودة إلى طلعة", func(): village_leave_pressed.emit())
	v.add_child(btn_village_leave)
	v.add_child(_button("الإعدادات", func(): open_settings("pause")))
	v.add_child(_button("القائمة الرئيسية", func(): quit_to_menu_pressed.emit()))
	v.add_child(_button("حفظ وخروج", func(): get_tree().quit()))

var btn_village_leave: Button
var in_village: = false

func show_pause(on: bool) -> void :
	if btn_village_leave:
		btn_village_leave.visible = in_village
	if on:
		_show_only(pause_menu)
		pause_menu.find_children("*", "Button", true, false)[0].grab_focus.call_deferred()
	else:
		_show_only(null)


var _s_controls: = {}

func _build_settings() -> void :
	settings_panel = _full("Settings")
	var dim: = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.add_child(dim)
	var v: = _center_box(settings_panel)
	var pc: = PanelContainer.new()
	pc.custom_minimum_size = Vector2(880, 0)
	v.add_child(pc)
	var inner: = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	pc.add_child(inner)
	inner.add_child(_label("الإعدادات", 52, font_title, GOLD))
	var grid: = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 2)
	if Game.touch:

		_row_h = 84.0
		_row_font = 34
		pc.custom_minimum_size = Vector2(1000, 0)
		var sc: = ScrollContainer.new()
		sc.custom_minimum_size = Vector2(960, 720)
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		inner.add_child(sc)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(grid)
		_opt_row(grid, "جودة الرسوميات", "quality", ["منخفضة", "متوسطة", "عالية", "فائقة"])
		_slider_row(grid, "دقة العرض", "render_scale", 0.5, 1.0, 0.05, true)
		_fps_row(grid)
		_check_row(grid, "دقة تلقائية (تحافظ على السلاسة)", "dyn_res")
		_slider_row(grid, "حساسية اللمس للكاميرا", "touch_sens", 0.3, 3.0, 0.05, false)
		_check_row(grid, "الكاميرا تلحقك وانت راكض", "cam_follow")
		_check_row(grid, "اهتزاز خفيف", "haptics")
		_check_row(grid, "مساعدة الحواف والتسلّق", "assist")
		_check_row(grid, "نقاط حفظ عند بداية كل مرحلة", "checkpoints")
		_slider_row(grid, "مجال الرؤية", "fov", 60.0, 100.0, 1.0, false)
		_check_row(grid, "عكس المحور العمودي", "invert_y")
		_check_row(grid, "ركض دائماً (بدون دفع العصا لآخرها)", "auto_sprint")
		_check_row(grid, "إظهار المؤقت", "show_timer")
		_check_row(grid, "مؤثرات الخوف (نبض وتعتيم)", "fear_fx")
		_check_row(grid, "تمايل الكاميرا بالأماكن العالية", "camera_fx")
		_slider_row(grid, "الصوت العام", "master_vol", 0.0, 1.0, 0.05, true)
		_slider_row(grid, "الموسيقى", "music_vol", 0.0, 1.0, 0.05, true)
		_slider_row(grid, "المؤثرات", "sfx_vol", 0.0, 1.0, 0.05, true)
		_slider_row(grid, "صوت الحكاية", "voice_vol", 0.0, 1.0, 0.05, true)
		var back_t: = _button("رجوع", _settings_back)
		back_t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inner.add_child(back_t)
		return
	inner.add_child(grid)
	_opt_row(grid, "جودة الرسوميات", "quality", ["منخفضة", "متوسطة", "عالية", "فائقة"])
	_slider_row(grid, "دقة العرض", "render_scale", 0.5, 1.0, 0.05, true)
	_check_row(grid, "ملء الشاشة", "fullscreen")
	_check_row(grid, "المزامنة العمودية", "vsync")
	_slider_row(grid, "مجال الرؤية", "fov", 60.0, 100.0, 1.0, false)
	_slider_row(grid, "حساسية الماوس", "mouse_sens", 0.2, 3.0, 0.05, false)
	_check_row(grid, "عكس المحور العمودي", "invert_y")
	_check_row(grid, "ركض تلقائي (Shift للمشي)", "auto_sprint")
	_check_row(grid, "مساعدة الحواف والتسلّق", "assist")
	_check_row(grid, "نقاط حفظ عند بداية كل مرحلة", "checkpoints")
	_check_row(grid, "إظهار المؤقت", "show_timer")
	_check_row(grid, "مؤثرات الخوف (نبض وتعتيم)", "fear_fx")
	_check_row(grid, "تمايل الكاميرا بالأماكن العالية", "camera_fx")
	_slider_row(grid, "الصوت العام", "master_vol", 0.0, 1.0, 0.05, true)
	_slider_row(grid, "الموسيقى", "music_vol", 0.0, 1.0, 0.05, true)
	_slider_row(grid, "المؤثرات", "sfx_vol", 0.0, 1.0, 0.05, true)
	_slider_row(grid, "صوت الحكاية", "voice_vol", 0.0, 1.0, 0.05, true)
	var back: = _button("رجوع", _settings_back)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(back)

var _row_h: = 37.0
var _row_font: = 26

func _fps_row(grid: GridContainer) -> void :
	_row_label(grid, "عدد الإطارات بالثانية")
	var ob: = OptionButton.new()
	var vals: = [30, 60, 90, 120]
	for v in vals:
		ob.add_item(str(v))
	ob.custom_minimum_size = Vector2(380, maxf(48.0, _row_h - 8.0))
	ob.selected = maxi(vals.find(int(Game.settings.get("fps_cap", 60))), 0)
	ob.item_selected.connect( func(i):
		Game.settings.fps_cap = vals[i]
		Game.apply_window_settings()
		Game.save_settings())
	grid.add_child(ob)
	_s_controls["fps_cap"] = ob

func back_or_quit() -> void :

	if menu.visible:
		get_tree().quit()
	else:
		show_menu(Game.has_save())

func _row_label(grid: GridContainer, text: String) -> void :
	var l: = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", _row_font)
	l.custom_minimum_size = Vector2(360, _row_h)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(l)

func _opt_row(grid: GridContainer, text: String, key: String, items: Array) -> void :
	_row_label(grid, text)
	var ob: = OptionButton.new()
	for it in items:
		ob.add_item(it)
	ob.custom_minimum_size = Vector2(380, maxf(48.0, _row_h - 8.0))
	ob.selected = int(Game.settings[key])
	ob.item_selected.connect( func(i):
		Game.settings[key] = i
		Game.save_settings())
	grid.add_child(ob)
	_s_controls[key] = ob

func _slider_row(grid: GridContainer, text: String, key: String, mn: float, mx: float, step: float, pct: bool) -> void :
	_row_label(grid, text)
	var h: = HBoxContainer.new()
	h.custom_minimum_size = Vector2(380, maxf(48.0, _row_h - 8.0))
	var s: = HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = float(Game.settings[key])
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.layout_direction = Control.LAYOUT_DIRECTION_LTR
	var val: = Label.new()
	val.custom_minimum_size = Vector2(80, 0)
	val.add_theme_font_size_override("font_size", 22)
	var fmt: = func(x): return ("%d%%" % int(round(x * 100))) if pct else ("%.2f" % x if mx <= 3.0 else "%d" % int(x))
	val.text = fmt.call(s.value)
	s.value_changed.connect( func(x):
		Game.settings[key] = x
		val.text = fmt.call(x))
	s.drag_ended.connect( func(_c): Game.save_settings())
	h.add_child(s)
	h.add_child(val)
	grid.add_child(h)
	_s_controls[key] = s

func _check_row(grid: GridContainer, text: String, key: String) -> void :
	_row_label(grid, text)
	var c: = CheckButton.new()
	c.custom_minimum_size = Vector2(140.0 if Game.touch else 0.0, maxf(40.0, _row_h - 8.0))
	c.button_pressed = bool(Game.settings[key])
	c.toggled.connect( func(on):
		Game.settings[key] = on
		if key == "fullscreen" or key == "vsync":
			Game.apply_window_settings()
		Game.save_settings())
	grid.add_child(c)
	_s_controls[key] = c

func open_settings(from: String) -> void :
	_settings_back_to = from
	_show_only(settings_panel)

func _settings_back() -> void :
	Game.save_settings()
	if _settings_back_to == "pause":
		_show_only(pause_menu)
	else:
		_show_only(menu)


func _build_hud() -> void :
	hud = _full("HUD")
	hud.layout_direction = Control.LAYOUT_DIRECTION_LTR

	var alt_box: = VBoxContainer.new()
	alt_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	alt_box.anchor_left = 1.0
	alt_box.anchor_right = 1.0
	alt_box.offset_left = -330
	alt_box.offset_right = -90
	alt_box.offset_top = 26
	alt_box.offset_bottom = 170
	alt_box.add_theme_constant_override("separation", -12)
	hud.add_child(alt_box)
	alt_label = _label("0", 72, font_title, Color.WHITE)
	alt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	alt_box.add_child(alt_label)
	alt_unit = _label("متر فوق الأرض", 22, font_body, Color(1, 1, 1, 0.75))
	alt_unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	alt_box.add_child(alt_unit)

	bar = Control.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	bar.anchor_left = 1.0
	bar.anchor_right = 1.0
	bar.anchor_top = 0.5
	bar.anchor_bottom = 0.5
	bar.offset_left = -52
	bar.offset_right = -40
	bar.offset_top = -300
	bar.offset_bottom = 320
	hud.add_child(bar)
	var track: = ColorRect.new()
	track.color = Color(1, 1, 1, 0.18)
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.offset_left = 4
	track.offset_right = -4
	bar.add_child(track)
	bar_best = ColorRect.new()
	bar_best.color = Color(1, 1, 1, 0.45)
	bar_best.size = Vector2(22, 3)
	bar_best.position = Vector2(-5, 0)
	bar.add_child(bar_best)
	bar_marker = ColorRect.new()
	bar_marker.color = GOLD
	bar_marker.size = Vector2(26, 6)
	bar_marker.position = Vector2(-7, 0)
	bar.add_child(bar_marker)

	time_label = _label("00:00", 34, font_bold, Color(1, 1, 1, 0.85))
	time_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	time_label.anchor_left = 0.5
	time_label.anchor_right = 0.5
	time_label.offset_left = -150
	time_label.offset_right = 150
	time_label.offset_top = 20
	time_label.offset_bottom = 70
	hud.add_child(time_label)

	zone_card = _label("", 92, font_title, GOLD)
	zone_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	zone_card.anchor_left = 0.5
	zone_card.anchor_right = 0.5
	zone_card.offset_left = -700
	zone_card.offset_right = 700
	zone_card.offset_top = 150
	zone_card.offset_bottom = 270
	zone_card.modulate.a = 0.0
	hud.add_child(zone_card)
	zone_sub = _label("", 30, font_body, Color(1, 1, 1, 0.9))
	zone_sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	zone_sub.anchor_left = 0.5
	zone_sub.anchor_right = 0.5
	zone_sub.offset_left = -700
	zone_sub.offset_right = 700
	zone_sub.offset_top = 262
	zone_sub.offset_bottom = 310
	zone_sub.modulate.a = 0.0
	hud.add_child(zone_sub)

	split_label = _label("", 26, font_bold, Color(0.6, 1.0, 0.6))
	split_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	split_label.anchor_left = 0.5
	split_label.anchor_right = 0.5
	split_label.offset_left = -300
	split_label.offset_right = 300
	split_label.offset_top = 66
	split_label.offset_bottom = 104
	split_label.modulate.a = 0.0
	hud.add_child(split_label)

	fall_label = _label("", 64, font_title, Color(1.0, 0.35, 0.3))
	fall_label.set_anchors_preset(Control.PRESET_CENTER)
	fall_label.anchor_left = 0.5
	fall_label.anchor_right = 0.5
	fall_label.anchor_top = 0.5
	fall_label.anchor_bottom = 0.5
	fall_label.offset_left = -400
	fall_label.offset_right = 400
	fall_label.offset_top = 90
	fall_label.offset_bottom = 170
	fall_label.modulate.a = 0.0
	hud.add_child(fall_label)

	var hint_text: = "WASD للحركة  •  Space للقفز  •  Shift للركض  •  امسك باتجاه الحافة لتتسلق  •  Esc للقائمة"
	if Game.touch:
		hint_text = "العصا يسار للحركة (ادفعها لآخرها للركض)  •  اسحب يمين لتلف الكاميرا  •  الزر الكبير للقفز"
	hint_label = _label(hint_text, 24, font_body, Color(1, 1, 1, 0.85))
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.anchor_left = 0.5
	hint_label.anchor_right = 0.5
	hint_label.anchor_top = 1.0
	hint_label.anchor_bottom = 1.0
	hint_label.offset_left = -800
	hint_label.offset_right = 800
	hint_label.offset_top = -80
	hint_label.offset_bottom = -30
	hud.add_child(hint_label)
	tip_label = _label("", 30, font_bold, Color(1.0, 0.92, 0.7))
	tip_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tip_label.anchor_left = 0.5
	tip_label.anchor_right = 0.5
	tip_label.anchor_top = 1.0
	tip_label.anchor_bottom = 1.0
	tip_label.offset_left = -800
	tip_label.offset_right = 800
	tip_label.offset_top = -170
	tip_label.offset_bottom = -110
	tip_label.modulate.a = 0.0
	hud.add_child(tip_label)

	_build_breath()

func show_tip(text: String) -> void :
	tip_label.text = text
	if _tip_tw:
		_tip_tw.kill()
	_tip_tw = create_tween()
	_tip_tw.tween_property(tip_label, "modulate:a", 1.0, 0.4)
	_tip_tw.tween_interval(5.0)
	_tip_tw.tween_property(tip_label, "modulate:a", 0.0, 1.0)

func show_hud(on: bool) -> void :
	hud.visible = on

func show_hint() -> void :
	hint_label.modulate.a = 1.0
	var tw: = create_tween()
	tw.tween_interval(12.0)
	tw.tween_property(hint_label, "modulate:a", 0.0, 2.0)

func update_hud(height: float, best: float, time_s: float) -> void :
	alt_label.text = str(int(max(height, 0.0)))
	time_label.visible = bool(Game.settings.show_timer)
	time_label.text = Game.format_time(time_s)
	var h: = bar.size.y
	var k: float = clamp(height / max_height, 0.0, 1.0)
	bar_marker.position.y = h * (1.0 - k) - 3
	var kb: float = clamp(best / max_height, 0.0, 1.0)
	bar_best.position.y = h * (1.0 - kb) - 1

func set_zone_ticks(zs: Array, top: float) -> void :
	zones = zs
	max_height = top
	for z in zs:
		if int(z.id) == 1:
			continue
		var t: = ColorRect.new()
		t.color = Color(1, 1, 1, 0.5)
		t.size = Vector2(14, 2)
		t.position = Vector2(-1, 0)
		t.set_meta("y", float(z.y0))
		bar.add_child(t)
	bar.resized.connect(_layout_ticks)
	_layout_ticks.call_deferred()

func _layout_ticks() -> void :
	for c in bar.get_children():
		if c.has_meta("y"):
			c.position.y = bar.size.y * (1.0 - float(c.get_meta("y")) / max_height)

func show_zone(title: String, subtitle: String) -> void :
	zone_card.text = title
	zone_sub.text = subtitle
	if _zone_tw:
		_zone_tw.kill()
	_zone_tw = create_tween()
	_zone_tw.tween_property(zone_card, "modulate:a", 1.0, 0.8)
	_zone_tw.parallel().tween_property(zone_sub, "modulate:a", 1.0, 1.2)
	_zone_tw.tween_interval(3.0)
	_zone_tw.tween_property(zone_card, "modulate:a", 0.0, 1.2)
	_zone_tw.parallel().tween_property(zone_sub, "modulate:a", 0.0, 1.2)

func _build_vignette() -> void :
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: = Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float amount = 0.0;\nuniform float pulse = 0.0;\nuniform vec4 tint : source_color = vec4(0.02, 0.025, 0.06, 1.0);\nvoid fragment() {\n\tvec2 uv = UV - 0.5;\n\tuv.x *= 1.5;\n\tfloat d = length(uv);\n\tfloat v = smoothstep(0.32 - pulse * 0.05, 0.92, d);\n\tCOLOR = vec4(tint.rgb, clamp(v * amount, 0.0, 0.92));\n}"










	var mat: = ShaderMaterial.new()
	mat.shader = sh
	vignette.material = mat
	vignette.visible = false
	root.add_child(vignette)

var breath_bar: Control
var _breath_fill: = 1.0
var _breath_on: = 0.0
var _breath_hint_shown: = false

func _build_breath() -> void :
	breath_bar = Control.new()
	breath_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	breath_bar.anchor_top = 1.0
	breath_bar.anchor_bottom = 1.0
	breath_bar.offset_left = -110
	breath_bar.offset_right = 110
	breath_bar.offset_top = -64
	breath_bar.offset_bottom = -52
	breath_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breath_bar.draw.connect(_draw_breath)
	hud.add_child(breath_bar)

func _draw_breath() -> void :
	var w: = breath_bar.size.x
	var h: = breath_bar.size.y
	var a: = 0.25 + 0.55 * _breath_on
	if _breath_fill < 0.999:
		a = maxf(a, 0.5)
	breath_bar.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.35 * a))
	var col: = Color(0.78, 0.9, 1.0, a) if _breath_fill > 0.15 else Color(1.0, 0.55, 0.4, a)
	breath_bar.draw_rect(Rect2(2, 2, (w - 4) * _breath_fill, h - 4), col)
	breath_bar.draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.5 * a), false, 1.5)

func set_breath(fill: float, on: float) -> void :
	if breath_bar == null:
		return
	var changed: = absf(fill - _breath_fill) > 0.002 or absf(on - _breath_on) > 0.01
	_breath_fill = fill
	_breath_on = on
	breath_bar.visible = fill < 0.999 or on > 0.01
	if changed:
		breath_bar.queue_redraw()
	if on > 0.5 and not _breath_hint_shown:
		_breath_hint_shown = true

func set_vignette(amount: float, pulse: = 0.0) -> void :
	_vig_amt = lerp(_vig_amt, amount, 0.12)
	vignette.visible = _vig_amt > 0.01
	if vignette.visible:
		var m: = vignette.material as ShaderMaterial
		m.set_shader_parameter("amount", _vig_amt)
		m.set_shader_parameter("pulse", pulse)

func update_fall_live(meters: float) -> void :
	if meters > 9.0:
		if _fall_tw:
			_fall_tw.kill()
			_fall_tw = null
		_fall_live = true
		fall_label.text = "↓ %d م" % int(meters)
		fall_label.modulate.a = clamp((meters - 9.0) / 4.0, 0.0, 1.0)
	elif _fall_live and meters <= 0.01:
		_fall_live = false
		if _fall_tw == null or not _fall_tw.is_valid():
			_fall_tw = create_tween()
			_fall_tw.tween_property(fall_label, "modulate:a", 0.0, 0.6)

func show_fall(meters: float) -> void :
	_fall_live = false
	fall_label.text = "سقطت %d متر" % int(meters)
	if _fall_tw:
		_fall_tw.kill()
	fall_label.modulate.a = 1.0
	fall_label.scale = Vector2.ONE
	_fall_tw = create_tween()
	_fall_tw.tween_interval(1.4)
	_fall_tw.tween_property(fall_label, "modulate:a", 0.0, 1.2)


func _build_ending() -> void :
	ending = _full("Ending")
	var v: = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.anchor_top = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = -520
	v.offset_right = 520
	v.offset_top = -560
	v.offset_bottom = -40
	v.add_theme_constant_override("separation", 12)
	ending.add_child(v)
	v.add_child(_label("الفانوس عالهلال", 120, font_title, GOLD))
	ending_stats = _label("", 32, font_body, Color.WHITE)
	v.add_child(ending_stats)
	var h: = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var cred: = _label("فكرة وتنفيذ: أوس • المحرك: Godot • المجسمات: KayKit (CC0) • الخطوط: Cairo و Lalezar • الموسيقى: مولّدة على المقامات العربية", 20, font_body, Color(1, 1, 1, 0.7))
	v.add_child(cred)
	var again: = _button("العب من جديد", func(): play_pressed.emit(true))
	again.custom_minimum_size = Vector2(320, 64)
	var back: = _button("القائمة الرئيسية", func(): quit_to_menu_pressed.emit())
	back.custom_minimum_size = Vector2(320, 64)
	h.add_child(again)
	h.add_child(back)

func show_ending() -> void :
	var best: = ""
	if Game.best_time > 0.0:
		best = "\nأفضل وقت: %s" % Game.format_time(Game.best_time)
	var got: = 0
	for a in Game.ACHIEVEMENTS:
		if Game.achievements.get(a.id, false):
			got += 1
	var letters: = 0
	for k in range(1, 8):
		if Game.story.get("L%d" % k, false):
			letters += 1
	ending_stats.text = "الوقت: %s   •   السقطات اللي صارت ضو: %d   •   أكبر سقطة: %d م   •   القفزات: %d%s\nرسائل ستّك: %d من 7   •   الإنجازات: %d من %d" % [
		Game.format_time(Game.stats_time), Game.stats_falls, int(Game.stats_biggest_fall), Game.stats_jumps, best, letters, got, Game.ACHIEVEMENTS.size()]
	hud.visible = false
	ending.modulate.a = 0.0
	_show_only(ending)
	var tw: = create_tween()
	tw.tween_property(ending, "modulate:a", 1.0, 2.0)
	ending.find_children("*", "Button", true, false)[1].grab_focus.call_deferred()


func fade_to(a: float, t: = 0.6) -> Tween:
	var tw: = create_tween()
	tw.tween_property(fade, "color:a", a, t)
	return tw



func _build_achievements() -> void :
	ach_panel = _full("Achievements")
	var dim: = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ach_panel.add_child(dim)
	var v: = _center_box(ach_panel)
	var pc: = PanelContainer.new()
	pc.custom_minimum_size = Vector2(980, 0)
	v.add_child(pc)
	var inner: = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	pc.add_child(inner)
	inner.add_child(_label("الإنجازات", 64, font_title, GOLD))
	_ach_list = VBoxContainer.new()
	_ach_list.add_theme_constant_override("separation", 4)
	inner.add_child(_ach_list)
	var back: = _button("رجوع", func(): _show_only(menu))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(back)

func _refresh_achievements() -> void :
	for c in _ach_list.get_children():
		c.queue_free()
	var grid: = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 2)
	_ach_list.add_child(grid)
	for a in Game.ACHIEVEMENTS:
		var on: bool = Game.achievements.get(a.id, false)
		var l: = _label(("★  " if on else "☆  ") + a.t, 28, font_bold, GOLD if on else Color(1, 1, 1, 0.4))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.custom_minimum_size = Vector2(320, 40)
		grid.add_child(l)
		var d: = _label(a.d, 22, font_body, Color(1, 1, 1, 0.85 if on else 0.4))
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(d)
	var zs: = []
	for z in range(2, 7):
		var k: = str(z)
		if Game.best_splits.has(k):
			zs.append("%s %s" % [NUMS_SHORT[z], Game.format_time(float(Game.best_splits[k]))])
	var best: = "أفضل وقت كامل: " + (Game.format_time(Game.best_time_ever) if Game.best_time_ever > 0.0 else "—")
	var info: = _label(best + ("\nأفضل توقيت للمراحل:  " + "   •   ".join(zs) if not zs.is_empty() else ""), 22, font_body, Color(0.85, 0.9, 1.0, 0.9))
	_ach_list.add_child(info)

const NUMS_SHORT: = ["", "١", "٢", "٣", "٤", "٥", "٦"]

func _build_toast() -> void :
	_toast = PanelContainer.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.12, 0.88)
	sb.set_corner_radius_all(18)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	_toast.add_theme_stylebox_override("panel", sb)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -330
	_toast.offset_right = 330
	_toast.offset_top = -140
	_toast.offset_bottom = -40
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast)
	var h: = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 18)
	_toast.add_child(h)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", -6)
	h.add_child(vb)
	_toast_title = _label("", 30, font_bold, GOLD)
	vb.add_child(_toast_title)
	_toast_desc = _label("", 22, font_body, Color(1, 1, 1, 0.85))
	vb.add_child(_toast_desc)
	h.add_child(_label("★", 54, font_title, GOLD))
	_toast.visible = false

func toast(title: String, desc: String) -> void :
	_toast_q.append([title, desc])
	if not _toast_busy:
		_next_toast()

func _next_toast() -> void :
	if _toast_q.is_empty():
		_toast_busy = false
		_toast.visible = false
		return
	_toast_busy = true
	var it: Array = _toast_q.pop_front()
	_toast_title.text = "إنجاز جديد: " + it[0]
	_toast_desc.text = it[1]
	_toast.visible = true
	Sfx.play("achievement", -3.0)
	var tw: = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast.offset_top = -140
	_toast.offset_bottom = -40
	tw.tween_property(_toast, "offset_top", 24.0, 0.5)
	tw.parallel().tween_property(_toast, "offset_bottom", 124.0, 0.5)
	tw.tween_interval(3.2)
	tw.tween_property(_toast, "offset_top", -140.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_toast, "offset_bottom", -40.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(_next_toast)

func show_split(zone: int, t: float, best: float) -> void :
	var txt: = "المرحلة %s  %s" % [NUMS_SHORT[zone], Game.format_time(t)]
	var col: = Color(1, 1, 1, 0.9)
	if best >= 0.0:
		var dlt: = t - best
		var sgn: = "-" if dlt < 0.0 else "+"
		txt += "   (%s%s)" % [sgn, Game.format_time(absf(dlt))]
		col = Color(0.55, 1.0, 0.6) if dlt < 0.0 else Color(1.0, 0.6, 0.5)
	split_label.text = txt
	split_label.add_theme_color_override("font_color", col)
	if _split_tw:
		_split_tw.kill()
	_split_tw = create_tween()
	split_label.modulate.a = 0.0
	_split_tw.tween_property(split_label, "modulate:a", 1.0, 0.4)
	_split_tw.tween_interval(5.0)
	_split_tw.tween_property(split_label, "modulate:a", 0.0, 1.0)
	Sfx.play("split", -6.0)
