extends Node3D


const ZONE_SUBTITLES: = {
	1: "المغرب. البيوت بتفطر… وأنا طالع من سطحها", 
	2: "السطوح بعد العشا: خزانات، صحون، وغسيل ما حدا جمعه", 
	3: "نص الليل. حديد بارد… ولا صوت غير صوت الريح", 
	4: "فوق الغيم. القمر شاهد، والسقطة ما إلها قاع", 
	5: "وقت السحور… وطبل المسحّراتي بعيد", 
	6: "قبل الفجر بشوي. الهوا خفيف… والهلال قريب", 
}
const NUMS: = ["", "الأولى", "الثانية", "الثالثة", "الرابعة", "الخامسة", "السادسة"]

enum Mode{LOADING, MENU, PLAYING, PAUSED, ENDING, CUTSCENE}

var mode: Mode = Mode.LOADING
var level
var scenery
var envm
var player
var rig
var touch: Node = null
var ui
var story
var soul
var soul_ui
var atmos
var village
var in_village: = false
var _photo: = false
var start_pos: = Vector3(0, 0.1, 0)
var start_yaw: = 0.0
var _save_t: = 0.0
var _zone: = 0
var _menu_t: = 0.0
var _menu_yaw: = 0.0
var _finish_r: = 3.5
var _best_zone_seen: = 0
var _hubs: = {}
var _cp_zone: = 1
var _cp_busy: = false
var _tips: = []
const TIP_TEXT_TOUCH: = {
	"sprint": "بعض القفزات طويلة… ادفع العصا لآخرها عشان تركض قبل ما تقفز", 
	"walk": "العوارض ضيقة… ادفع العصا شوي بس عشان تمشي ببطء", 
	"zip": "امشِ لتحت المسكة وامسك الحبل… وانزلق! (زر القفز لتفلت)", 
}
const TIP_TEXT: = {
	"sprint": "بعض القفزات طويلة… اركض بـ Shift قبل ما تقفز", 
	"bounce": "الترامبولين الوردي بطيّرك لفوق! انزل عليه ووجّه حالك بالهوا", 
	"updraft": "ادخل بعمود الهوا فوق المروحة وخليه يرفعك", 
	"move": "المنصة بتتحرك… استنى اللحظة المناسبة واقفز", 
	"crumble": "هاي بتنهار بعد لحظة من ما توقف عليها… لا تطوّل!", 
	"wind": "انتبه للريح! استنى الهبّة تخلص وبعدين قطع", 
	"walk": "العوارض ضيقة… اضغط Ctrl لتمشي ببطء", 
	"zip": "امشِ لتحت المسكة وامسك الحبل… وانزلق! (Space لتفلت)", 
	"rest": "استراحة… خذ نفَس وتمتّع بالمنظر", 
	"mantle": "إذا ما وصلت القفزة، ضلّك ماسك باتجاه الحافة وبتتسلق بإيديك", 
}

func _ready() -> void :
	Game.main = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui = load("res://scripts/ui.gd").new()
	add_child(ui)
	ui.play_pressed.connect(_on_play)
	ui.resume_pressed.connect( func(): _set_paused(false))
	ui.quit_to_menu_pressed.connect(_to_menu)
	ui.character_changed.connect( func(): player.set_character(Game.character_path()))
	await get_tree().process_frame
	await get_tree().process_frame
	_build_world()

func _build_world() -> void :
	level = load("res://scripts/level_builder.gd").new()
	level.name = "Level"
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	level.load_route()
	Game.route_sig = "%d-%d-%.1f" % [level.nodes.size(), level.route.pieces.size(), float(level.nodes[-1].p[1])]
	if Game.has_save():
		var old: = Game.load_game()
		if old.get("route", "") != Game.route_sig:
			var mig: Dictionary = level.route.get("migrate", {})
			if String(old.get("route", "")) == String(mig.get("from_sig", "-")) and old.has("pos"):
				_migrate_save(old)
			else:
				Game.delete_save()
				Game.reset_stats()
	level.build()
	scenery = load("res://scripts/scenery.gd").new()
	scenery.name = "Scenery"
	scenery.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(scenery)
	scenery.build(level)
	Surf.dress(level, level)
	Surf.dress(scenery, level)
	envm = load("res://scripts/environment_manager.gd").new()
	envm.name = "Env"
	add_child(envm)
	envm.setup(level)
	player = load("res://scenes/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.set_character(Game.character_path())
	player.hard_landing.connect(_on_hard_landing)
	rig = load("res://scenes/camera_rig.tscn").instantiate()
	rig.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(rig)
	rig.target = player
	if Game.mobile:
		var dr: Node = load("res://scripts/dynres.gd").new()
		dr.name = "DynRes"
		add_child(dr)
	if Game.touch:
		touch = load("res://scripts/touch_controls.gd").new()
		touch.name = "Touch"
		add_child(touch)
		touch.rig = rig
		rig.touch = touch
		touch.pause_pressed.connect( func():
			if mode == Mode.PLAYING:
				_set_paused(true))
	var n0: Dictionary = level.nodes[0]
	start_pos = Vector3(float(n0.p[0]), float(n0.p[1]) + 0.1, float(n0.p[2]))
	var n1: Dictionary = level.nodes[1]
	start_yaw = atan2(float(n1.p[0]) - start_pos.x, float(n1.p[2]) - start_pos.z)
	for n in level.nodes:
		if n.get("finish", false):
			_finish_r = float(n.r) + 0.2
	story = load("res://scripts/story.gd").new()
	story.name = "Story"
	story.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(story)
	story.setup(self)
	Surf.dress(story, level)
	soul_ui = load("res://scripts/soul_ui.gd").new()
	soul_ui.name = "SoulUI"
	soul_ui.main = self
	add_child(soul_ui)
	soul = load("res://scripts/soul.gd").new()
	soul.name = "Soul"
	soul.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(soul)
	soul.ui = soul_ui
	soul.setup(self)
	soul_ui.replay_memory.connect(replay_memory)
	atmos = load("res://scripts/atmosphere.gd").new()
	atmos.name = "Atmosphere"
	add_child(atmos)
	atmos.setup(self)
	ui.album_pressed.connect( func():
		ui._show_only(null)
		soul_ui.open_album())
	ui.photo_pressed.connect( func(): soul_ui.enter_photo())
	for i in level.nodes.size():
		var hn: Dictionary = level.nodes[i]
		if hn.has("hub") and int(hn.hub) >= 2:
			var hp: = Vector3(float(hn.p[0]), float(hn.p[1]) + 0.1, float(hn.p[2]))
			var nx: Dictionary = level.nodes[mini(i + 1, level.nodes.size() - 1)]
			_hubs[int(hn.hub)] = [hp, atan2(float(nx.p[0]) - hp.x, float(nx.p[2]) - hp.z), float(hn.r)]
	for n in level.nodes:
		if n.get("sp", "") == "tower":
			_tower_top = Vector3(float(n.p[0]), float(n.p[1]), float(n.p[2]))
	Game.achievement_unlocked.connect(_on_achievement)
	_build_tips()
	var top: = float(level.nodes[-1].p[1])
	ui.set_zone_ticks(level.zones, top)
	player.teleport(start_pos, start_yaw)
	rig.yaw = start_yaw + PI
	rig.snap_to_target()
	_enter_menu()
	ui.hide_loading()
	Sfx.start_ambience()


func _enter_menu() -> void :
	mode = Mode.MENU
	Game.playing = false
	Game.input_blocked = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var d: = Game.load_game()
	if not d.is_empty() and d.has("pos"):
		var p: = Vector3(d.pos[0], d.pos[1], d.pos[2])
		player.teleport(p, float(d.get("yaw", 0.0)))
	else:
		player.teleport(start_pos, start_yaw)
	player.freeze(true)
	player.set_lantern(Game.story.get("prologue", false))
	rig.cinematic = true
	rig.collide_always = true
	rig.distance = 5.2
	rig.pitch = -0.1
	_menu_yaw = _pick_menu_yaw()
	rig.yaw = _menu_yaw
	rig.snap_to_target()
	ui.show_menu(Game.has_save())
	Sfx.play_music("music_menu")

func _pick_menu_yaw() -> float:

	var face: float = player._facing
	var pivot: Vector3 = player.global_position + Vector3(0, 1.45, 0)
	var space: = get_viewport().world_3d.direct_space_state
	var best: = face
	var best_score: = -1000000000.0
	for i in 16:
		var yw: = face + TAU * i / 16.0
		var off: = Basis(Vector3.UP, yw) * Basis(Vector3.RIGHT, -0.1) * Vector3(0, 0, 5.6)
		var q: = PhysicsRayQueryParameters3D.create(pivot, pivot + off, 1)
		q.exclude = [player.get_rid()]
		var h: = space.intersect_ray(q)
		var clear: = 5.6 if h.is_empty() else pivot.distance_to(h.position)
		var front: = cos(wrapf(yw - face, - PI, PI))
		var score: = clear * 2.0 + front * 1.5
		if score > best_score:
			best_score = score
			best = yw
	return best

func _on_play(new_game: bool) -> void :
	story.reset_after_ending()
	if new_game:
		Game.delete_save()
		Game.reset_stats()
		if soul:
			soul.reset_run()
		player.teleport(start_pos, start_yaw)
		rig.yaw = start_yaw + PI
	else:
		Game.load_game()
	ui.fade_to(1.0, 0.35).tween_callback( func():
		if new_game and not Game.story.get("prologue", false):
			_play_prologue()
		else:
			_start_playing(new_game)
			ui.fade_to(0.0, 0.8))

func _play_prologue() -> void :
	mode = Mode.CUTSCENE
	rig.collide_always = false
	rig.frame_x = 0.0
	ui._show_only(null)
	ui.show_hud(false)
	Game.input_blocked = true
	Game.playing = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	player.freeze(true)
	story.play_prologue( func():
		_start_playing(true)
		story.cs.black(0.0, 1.4))
	ui.fade_to(0.0, 0.3)

func _play_memory(z: int) -> void :
	_breath_reset()
	Game.album_add("memories", str(z))
	mode = Mode.CUTSCENE
	Game.playing = false
	Game.input_blocked = true
	player.velocity = Vector3.ZERO
	player.freeze(true)
	ui.show_hud(false)
	story.play_memory(z, func():
		mode = Mode.PLAYING
		Game.playing = true
		Game.input_blocked = false
		player.freeze(false)
		player.state = player.State.NORMAL
		ui.show_hud(true)
		rig.snap_to_target()
		Sfx.zone_music(level.zones[_zone - 1].music)
		_save())

func _start_playing(new_game: bool) -> void :
	mode = Mode.PLAYING
	rig.collide_always = false
	rig.frame_x = 0.0
	ui._show_only(null)
	ui.show_hud(true)
	player.freeze(false)
	player.state = player.State.NORMAL
	player.set_lantern(true)
	rig.cinematic = false
	rig.distance = 6.0
	rig.pitch = -0.3
	rig.snap_to_target()
	Game.playing = true
	Game.input_blocked = false
	_capture_mouse(true)
	_zone = level.zone_at(player.global_position.y)
	_best_zone_seen = _zone
	_cp_zone = 1
	for zk in _hubs.keys():
		if (_hubs[zk][0] as Vector3).y <= player.global_position.y + 1.0 and int(zk) > _cp_zone:
			_cp_zone = int(zk)
	if new_game:
		ui.show_hint()
		_show_zone_card(1)
	Sfx.zone_music(level.zones[_zone - 1].music)
	_save_t = 0.0

func photo_mode(on: bool) -> void :

	_photo = on
	if on:
		mode = Mode.PLAYING
		get_tree().paused = false
		Game.playing = false
		Game.input_blocked = true
		player.velocity = Vector3.ZERO
		if player.state == player.State.NORMAL:
			player.freeze(true)
		rig.cinematic = false
		rig.enabled = true
	else:
		if player.state == player.State.FROZEN:
			player.freeze(false)
			player.state = player.State.NORMAL
		Game.playing = not in_village
		Game.input_blocked = false
		ui.show_hud( not in_village)
		_capture_mouse(true)

func replay_memory(z: int) -> void :

	if not story.memories.has(z):
		ui.show_menu(Game.has_save())
		return
	var saved: Dictionary = Game.story.duplicate(true)
	ui.fade_to(1.0, 0.35).tween_callback( func():
		ui._show_only(null)
		mode = Mode.CUTSCENE
		rig.collide_always = false
		rig.frame_x = 0.0
		var m: Dictionary = story.memories[z]
		player.teleport((m.center as Vector3) + Vector3(0, 0.1, 0), 0.0)
		player.freeze(true)
		story.play_memory(z, func():
			Game.story = saved
			_enter_menu()
			ui.fade_to(0.0, 0.8))
		ui.fade_to(0.0, 0.6))

func _migrate_save(old: Dictionary) -> void :

	var off_of: = func(p: Vector3) -> Vector3:
		var best: = 1e+18
		var off: = Vector3.ZERO
		for n in level.nodes:
			if int(n.get("oid", 0)) < 0:
				continue
			var o: Array = n.get("off", [0, 0, 0])
			var ov: = Vector3(float(o[0]), float(o[1]), float(o[2]))
			var q: = Vector3(float(n.p[0]), float(n.p[1]), float(n.p[2])) - ov
			var dd: = q.distance_squared_to(p)
			if dd < best:
				best = dd
				off = ov
		return off
	var pos: = Vector3(float(old.pos[0]), float(old.pos[1]), float(old.pos[2]))
	var np: Vector3 = pos + off_of.call(pos)
	var marks: = []
	for q in Game.fall_marks:
		var fp: = Vector3(float(q[0]), float(q[1]), float(q[2]))
		var fn: Vector3 = fp + off_of.call(fp)
		marks.append([fn.x, fn.y, fn.z])
	Game.fall_marks = marks
	Game.stats_max_height = maxf(Game.stats_max_height, np.y)
	Game.save_game(np, float(old.get("yaw", 0.0)))
	print("save migrated to the 1.2 climb: ", pos, " -> ", np)

func _set_paused(on: bool) -> void :
	_breath_reset()
	if on and in_village and village.mp.session:

		village.open_menu()
		return
	if on:
		mode = Mode.PAUSED
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui.in_village = in_village
		ui.show_pause(true)
		_save()
	else:
		mode = Mode.PLAYING
		get_tree().paused = false
		_capture_mouse(true)
		ui.show_pause(false)

func _to_menu() -> void :
	_breath_reset()
	if mode == Mode.PLAYING or mode == Mode.PAUSED:
		_save()
	get_tree().paused = false
	ui.fade_to(1.0, 0.35).tween_callback( func():
		if in_village:
			village.leave_now()
		ui.show_hud(false)
		story.reset_after_ending()
		_enter_menu()
		ui.fade_to(0.0, 0.8))

func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("pause"):
		if _photo:
			soul_ui.exit_photo()
			get_viewport().set_input_as_handled()
			return
		if mode == Mode.PLAYING:
			_set_paused(true)
		elif mode == Mode.PAUSED:
			if ui.settings_panel.visible:
				ui._settings_back()
			else:
				_set_paused(false)
		get_viewport().set_input_as_handled()
	elif mode == Mode.PLAYING and not Game.touch and event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_capture_mouse(true)

func _capture_mouse(on: bool) -> void :
	if Game.touch:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE

func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:

		if soul_ui and soul_ui.photo_on:
			soul_ui.exit_photo()
			return
		if soul_ui and soul_ui.album.visible:
			soul_ui.close_album()
			return
		if village and village.ui.visible and village.back_pressed():
			return
		if mode == Mode.PLAYING:
			_set_paused(true)
		elif mode == Mode.PAUSED:
			if ui.settings_panel.visible:
				ui._settings_back()
			else:
				_set_paused(false)
		elif mode == Mode.MENU:
			if ui.settings_panel.visible:
				ui._settings_back()
			elif ui.has_method("back_or_quit"):
				ui.back_or_quit()
			else:
				get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		if mode == Mode.PLAYING or mode == Mode.PAUSED:
			_save()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if mode == Mode.PLAYING or mode == Mode.PAUSED:
			_save()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if mode == Mode.PLAYING:
			_set_paused(true)


func _process(delta: float) -> void :
	if level == null or player == null:
		return
	if touch:
		var tm: = "play" if mode == Mode.PLAYING and not _photo else ("cutscene" if mode == Mode.CUTSCENE else "off")
		if village and village.ui.visible and village.ui.modal_open():
			tm = "off"
		touch.set_mode(tm)
	if soul:
		soul.update(delta)
	if atmos:
		atmos.update(delta, rig.cam.global_position, rig.cam.global_transform.basis)
	var y: float = player.global_position.y
	envm.update_for_height(rig.cam.global_position.y)
	scenery.update(rig.cam.global_position)

	var fall_speed: float = max( - player.velocity.y, 0.0)
	Sfx.wind_level = clamp(0.15 + y / 700.0, 0.15, 0.95)
	Sfx.fall_level = clamp((fall_speed - 8.0) / 35.0, 0.0, 1.0)
	Sfx.amb_level = clamp(1.0 - y / 90.0, 0.0, 1.0)
	if mode != Mode.PLAYING or in_village:
		Sfx.heart_level = 0.0
		ui.set_vignette(0.0)
		rig.danger = 0.0
	if in_village:
		if mode == Mode.PLAYING and not _photo:
			village.update(delta)
		return

	var hold: = false
	if story and mode == Mode.PLAYING:
		for rp in story.radio_points:
			if rp.distance_to(player.global_position) < 34.0:
				hold = true
				break
	if story and mode == Mode.PLAYING and not hold:
		for rn in get_tree().get_nodes_in_group("live_radio"):
			if rn.is_on() and rn.radio_position().distance_to(player.global_position) < 48.0:
				hold = true
				break
	Sfx.music_hold = hold
	match mode:
		Mode.MENU:


			_menu_t += delta
			rig.yaw = _menu_yaw + sin(_menu_t * 0.13) * 0.28
			rig.pitch = lerpf(rig.pitch, -0.1 + sin(_menu_t * 0.09) * 0.04, 1.0 - exp(-2.0 * delta))
			var char_view: bool = ui.char_panel.visible
			rig.distance = 3.9 if char_view else 5.2
			rig.frame_x = 0.0 if char_view else (1.25 if not Game.touch else 1.05)
		Mode.PLAYING:
			if village:
				village.check_door(delta)
			_update_checkpoint()
			Game.stats_max_height = max(Game.stats_max_height, y)
			ui.update_hud(y, Game.stats_max_height, Game.stats_time)
			_update_fear(delta)
			_update_breath(delta)
			var z: int = level.zone_at(y)
			if z != _zone:
				_zone = z
				Sfx.zone_music(level.zones[z - 1].music)
				if z > _best_zone_seen:
					_best_zone_seen = z
					_show_zone_card(z)
					if z >= 2:
						var sp: Array = Game.record_split(z)
						if not sp.is_empty():
							ui.show_split(z, float(sp[0]), float(sp[1]))
			_save_t += delta
			if _save_t > 3.0 and player.is_on_floor() and player.floor_is_static and player.state == player.State.NORMAL:
				_save_t = 0.0
				_save()
			_check_finish()
			_check_tips()
			_ach_t += delta
			if _ach_t > 0.25:
				_ach_t = 0.0
				_check_achievements()
			if mode == Mode.PLAYING and player.is_on_floor():
				var mz: int = story.memory_at(player.global_position)
				if mz > 0:
					_play_memory(mz)
		Mode.ENDING:
			rig.yaw += delta * 0.12
			rig.pitch = lerp(rig.pitch, -0.12, delta * 0.5)

var _breath_said: = 0
var _breath_k: = 0.0
func _update_breath(delta: float) -> void :
	var want: bool = Input.is_action_pressed("breath") and not Game.input_blocked and not _photo
	var real_dt: float = delta / maxf(Engine.time_scale, 0.05)
	player.update_breath(real_dt, want)
	var target: float = 0.3 if player.breath_active else 1.0
	_breath_k = lerpf(_breath_k, 1.0 if player.breath_active else 0.0, 1.0 - exp(-8.0 * real_dt))
	Engine.time_scale = lerpf(Engine.time_scale, target, 1.0 - exp(-10.0 * real_dt))
	if absf(Engine.time_scale - 1.0) < 0.01 and not player.breath_active:
		Engine.time_scale = 1.0
	ui.set_breath(player.breath / player.BREATH_MAX, _breath_k)
	Sfx.breath_level = _breath_k
	if player.breath_active and _breath_said < 3 and Game.stats_time > 20.0 and randf() < real_dt * 0.5:
		_breath_said += 1
		if soul_ui:
			soul_ui.say("ستّي", ["خُد نفَس يا سليم.", "شوف قدّامك… مش تحت.", "ما في عجلة. أنا هون."][_breath_said - 1], 2.6)

func _breath_reset() -> void :
	Engine.time_scale = 1.0
	_breath_k = 0.0
	Sfx.breath_level = 0.0
	if ui:
		ui.set_breath(1.0, 0.0)

var _danger_s: = 0.0
func _update_fear(delta: float) -> void :
	var fear_on: bool = Game.settings.get("fear_fx", true)
	_danger_s = lerp(_danger_s, float(player.danger), 1.0 - exp(-1.5 * delta))
	rig.danger = _danger_s
	var fall: float = player.fall_distance()
	var fall_k: float = clamp((fall - 6.0) / 40.0, 0.0, 1.0)
	ui.update_fall_live(fall)
	if fear_on:
		var pulse: float = pow(0.5 + 0.5 * sin(Game.world_time * TAU * 1.17 * (0.95 + _danger_s * 0.4)), 8.0) * _danger_s
		ui.set_vignette(maxf(_danger_s * 0.5, fall_k * 0.8), pulse)
		Sfx.heart_level = maxf(smoothstep(0.35, 1.0, _danger_s), fall_k * 0.8)
	else:
		ui.set_vignette(0.0)
		Sfx.heart_level = 0.0

func _build_tips() -> void :
	var seen: = {}
	for n in level.nodes:
		var key: = ""
		var piece: Dictionary = level.route.pieces[int(n.piece)]
		var mt: String = piece.get("m", {}).get("type", "")
		if mt in ["bounce", "updraft", "move", "crumble", "wind"]:
			key = mt
		elif n.link == "zip":
			key = "zip"
		elif piece.get("tag", "") == "promenade":
			key = "rest"
		elif n.get("sprint", false):
			key = "sprint"
		elif n.link == "walk" and float(n.get("w", 1.0)) < 0.5:
			key = "walk"
		if key != "" and not seen.has(key):
			seen[key] = true
			var tp: = Vector3(float(n.p[0]), float(n.p[1]), float(n.p[2]))
			if key == "zip":
				tp = Vector3(float(n.handle[0]), float(n.handle[1]), float(n.handle[2]))
			_tips.append([tp, (TIP_TEXT_TOUCH[key] if Game.touch and TIP_TEXT_TOUCH.has(key) else TIP_TEXT[key]), false])

	if level.nodes.size() > 4:
		var n3: Dictionary = level.nodes[3]
		_tips.append([Vector3(float(n3.p[0]), float(n3.p[1]), float(n3.p[2])), TIP_TEXT["mantle"], false])

func _check_tips() -> void :
	var p: Vector3 = player.global_position
	for tip in _tips:
		if not tip[2] and p.distance_to(tip[0]) < 9.0:
			tip[2] = true
			ui.show_tip(tip[1])

func _show_zone_card(z: int) -> void :
	var zd: Dictionary = level.zones[z - 1]
	ui.show_zone("المرحلة %s: %s" % [NUMS[z], zd.name], ZONE_SUBTITLES.get(z, ""))
	if z > 1:
		Sfx.play("zone", -4.0)

var _ach_t: = 0.0
var _tower_top: = Vector3(1000000000.0, 0, 0)

func _check_achievements() -> void :
	var p: Vector3 = player.global_position
	if Game.stats_max_height >= 500.0:
		Game.unlock("half")
	if player.is_on_floor():
		if p.distance_to(_tower_top) < 3.2:
			Game.unlock("tower")
		for v in level.vehicles:
			if not is_instance_valid(v):
				continue
			var vel: Vector3 = v.velocity_now
			if vel.length() > 0.8 and p.distance_to(v.global_position) < 5.0 and p.y > v.global_position.y - 0.5:
				Game.unlock(String(v.kind))
	var all_m: = true
	for z in range(2, 7):
		if story.memories.has(z) and not Game.story.get("m%d" % z, false):
			all_m = false
	if all_m and not story.memories.is_empty():
		Game.unlock("memories")

func _on_achievement(id: String) -> void :
	var a: Dictionary = Game.achievement_info(id)
	if not a.is_empty():
		ui.toast(a.t, a.d)

func _on_hard_landing(fall: float) -> void :
	if in_village:
		rig.add_shake(clamp(fall / 25.0, 0.25, 1.0))
		return
	if fall >= 100.0:
		Game.unlock("big_fall")
	if fall >= 10.0:
		if soul:
			soul.on_big_fall(fall)
		Game.stats_falls += 1
		Game.stats_biggest_fall = max(Game.stats_biggest_fall, fall)
		ui.show_fall(fall)
		if envm:
			envm.punch(clampf(fall / 60.0, 0.35, 1.0))
	rig.add_shake(clamp(fall / 25.0, 0.25, 1.0))
	if fall >= player.HARD_FALL:
		rig.add_shake(1.0)

func _check_finish() -> void :
	var fp: Vector3 = level.finish_pos
	var p: Vector3 = player.global_position
	if player.is_on_floor() and p.y > fp.y - 0.6 and Vector2(p.x - fp.x, p.z - fp.z).length() < _finish_r:
		_finish()

func _finish() -> void :
	mode = Mode.CUTSCENE
	Game.finished = true
	Game.playing = false
	if Game.best_time <= 0.0 or Game.stats_time < Game.best_time:
		Game.best_time = Game.stats_time
	_save()
	Game.input_blocked = true
	player.velocity = Vector3.ZERO
	player.freeze(true)
	ui.show_hud(false)
	Sfx.play("finish", -4.0)
	Game.best_time_ever = Game.stats_time if Game.best_time_ever <= 0.0 else minf(Game.best_time_ever, Game.stats_time)
	Game.unlock("finish")
	if Game.stats_falls < 10:
		Game.unlock("brave")
	if Game.stats_time < 40.0 * 60.0:
		Game.unlock("fast")
	story.play_ending( func():
		Game.story["ending"] = true
		_show_ending())

func _show_ending() -> void :
	mode = Mode.ENDING
	player.cheer()
	rig.cinematic = true
	rig.distance = 11.0
	rig.snap_to_target()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_ending()
	_fireworks()
	get_tree().create_timer(32.0).timeout.connect( func():
		if mode == Mode.ENDING:

			Sfx.play("radio_click", -4.0)
			Sfx.play_music("song_end", 2.5, false))

func _fireworks() -> void :
	var colors: = [Color(1.0, 0.8, 0.3), Color(0.4, 0.8, 1.0), Color(1.0, 0.4, 0.5), Color(0.6, 1.0, 0.5), Color(0.9, 0.6, 1.0)]
	for i in 14:
		var fw: = GPUParticles3D.new()
		fw.one_shot = true
		fw.amount = 90
		fw.lifetime = 1.8
		fw.explosiveness = 1.0
		var pm: = ParticleProcessMaterial.new()
		pm.direction = Vector3.UP
		pm.spread = 180.0
		pm.initial_velocity_min = 7.0
		pm.initial_velocity_max = 10.0
		pm.gravity = Vector3(0, -3.0, 0)
		pm.damping_min = 1.5
		pm.damping_max = 2.5
		var c: Color = colors[i % colors.size()]
		var g: = Gradient.new()
		g.set_color(0, Color(c.r, c.g, c.b, 1.0))
		g.set_color(1, Color(c.r, c.g, c.b, 0.0))
		var gt: = GradientTexture1D.new()
		gt.gradient = g
		pm.color_ramp = gt
		fw.process_material = pm
		var qm: = QuadMesh.new()
		qm.size = Vector2(0.25, 0.25)
		var sm: = StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.vertex_color_use_as_albedo = true
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		sm.albedo_texture = load("res://assets/particle.png")
		sm.emission_enabled = true
		sm.emission = c
		sm.emission_energy_multiplier = 3.0
		qm.material = sm
		fw.draw_pass_1 = qm
		var a: = randf() * TAU
		fw.position = level.finish_pos + Vector3(cos(a) * randf_range(8, 18), randf_range(10, 22), sin(a) * randf_range(8, 18))
		add_child(fw)
		get_tree().create_timer(0.35 * i + randf() * 0.3).timeout.connect( func():
			fw.restart()
			Sfx.play("whoosh", -8.0, 0.2))

func _save() -> void :
	if player == null or in_village:
		return
	var yaw: float = player.get_node("Visual").rotation.y
	Game.save_game(player.global_position, yaw)


func _update_checkpoint() -> void :
	var pp: Vector3 = player.global_position

	for zk in _hubs.keys():
		var z: = int(zk)
		if z > _cp_zone and player.is_on_floor():
			var hp: Vector3 = _hubs[zk][0]
			if absf(pp.y - hp.y) < 1.5 and Vector2(pp.x - hp.x, pp.z - hp.z).length() < float(_hubs[zk][2]) + 1.5:
				_cp_zone = z
				if Game.settings.get("checkpoints", false):
					ui.show_tip("نقطة حفظ: إذا وقعت، بترجع لهون")
	if not Game.settings.get("checkpoints", false) or _cp_busy or not _hubs.has(_cp_zone):
		return
	var cp: Vector3 = _hubs[_cp_zone][0]
	if pp.y < cp.y - 10.0 and not player.is_on_floor() and player.velocity.y < -4.0:
		_cp_busy = true
		ui.fade_to(1.0, 0.3).tween_callback( func():
			var yaw: float = _hubs[_cp_zone][1]
			player.teleport(cp, yaw)
			rig.yaw = yaw + PI
			rig.snap_to_target()
			_save()
			ui.fade_to(0.0, 0.6)
			_cp_busy = false)

func respawn_at_start() -> void :
	player.teleport(start_pos, start_yaw)
	rig.snap_to_target()
