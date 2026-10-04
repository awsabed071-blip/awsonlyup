extends Node


signal settings_changed
signal achievement_unlocked(id: String)

const ACHIEVEMENTS: = [
	{"id": "tower", "t": "درج الحارة", "d": "اطلع درج خزّان المي لآخره"}, 
	{"id": "train", "t": "تذكرة ذهاب", "d": "اركب القطار المعلّق فوق السطوح"}, 
	{"id": "crane", "t": "على الخطّاف", "d": "خلّي الرافعة ترفعك"}, 
	{"id": "balloon", "t": "منطاد الغروب", "d": "اركب المنطاد بين الجزر"}, 
	{"id": "rocket", "t": "إطلاق!", "d": "اركب الصاروخ للنجوم"}, 
	{"id": "memories", "t": "ذاكرة كاملة", "d": "شوف كل ذكريات ستّي"}, 
	{"id": "half", "t": "نص الطريق", "d": "اوصل لارتفاع ٥٠٠ متر"}, 
	{"id": "big_fall", "t": "السقطة الكبرى", "d": "اسقط أكثر من ١٠٠ متر بمرّة وحدة"}, 
	{"id": "finish", "t": "الفانوس عالهلال", "d": "علّق فانوس ستّي على القمر"}, 
	{"id": "brave", "t": "قلب حديد", "d": "خلّص الطلعة بأقل من ١٠ سقطات"}, 
	{"id": "fast", "t": "مستعجل", "d": "خلّص الطلعة بأقل من ٤٠ دقيقة"}, 
]

const SETTINGS_PATH: = "user://settings.cfg"
const SAVE_PATH: = "user://save.json"
const CHARACTERS: = [
	{"id": "salim", "name": "سليم", "path": "res://assets/characters/salim.glb"}, 
]

var settings: = {
	"quality": 2, 
	"mouse_sens": 1.0, 
	"pad_sens": 1.0, 
	"invert_y": false, 
	"fov": 75.0, 
	"master_vol": 0.9, 
	"music_vol": 0.6, 
	"sfx_vol": 0.9, 
	"voice_vol": 1.0, 
	"fullscreen": true, 
	"vsync": true, 
	"show_timer": true, 
	"auto_sprint": false, 
	"assist": false, 
	"checkpoints": false, 
	"render_scale": 1.0, 
	"character": "salim", 
	"camera_fx": true, 
	"fear_fx": true, 
	"skip_seen_cutscenes": false, 
	"touch_sens": 1.0, 
	"haptics": true, 
	"cam_follow": true, 
	"fps_cap": 60, 
	"dyn_res": true, 
}

var input_blocked: = false
var playing: = false

var mobile: = OS.has_feature("mobile") or "--mobile" in OS.get_cmdline_user_args()
var touch: = mobile or "--touch" in OS.get_cmdline_user_args()
var touch_stick_active: = false
var world_time: = 0.0
var low_gravity_y: = 99999.0
var route_sig: = ""
var main: Node = null


var stats_time: = 0.0
var stats_falls: = 0
var stats_jumps: = 0
var stats_biggest_fall: = 0.0
var stats_max_height: = 0.0
var finished: = false
var best_time: = 0.0
var story: = {}
var splits: = {}
var best_splits: = {}
var achievements: = {}
var album: = {}
var fall_marks: Array = []

func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	if mobile:

		settings.quality = 1
		settings.render_scale = 0.8
		settings.fov = 72.0
	load_settings()

func _process(delta: float) -> void :
	if playing and not get_tree().paused and not finished:
		stats_time += delta

func _physics_process(delta: float) -> void :
	if not get_tree().paused:
		world_time += delta

func load_settings() -> void :
	var cf: = ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		for k in settings.keys():
			settings[k] = cf.get_value("settings", k, settings[k])
		achievements = cf.get_value("progress", "achievements", {})
		best_splits = cf.get_value("progress", "best_splits", {})
		best_time_ever = cf.get_value("progress", "best_time", 0.0)
		album = cf.get_value("progress", "album", {})
	apply_window_settings()

func save_settings() -> void :
	_write_cfg()
	settings_changed.emit()

func _write_cfg() -> void :
	var cf: = ConfigFile.new()
	for k in settings.keys():
		cf.set_value("settings", k, settings[k])
	cf.set_value("progress", "achievements", achievements)
	cf.set_value("progress", "best_splits", best_splits)
	cf.set_value("progress", "best_time", best_time_ever)
	cf.set_value("progress", "album", album)
	cf.save(SETTINGS_PATH)

var best_time_ever: = 0.0

func unlock(id: String) -> void :
	if achievements.get(id, false):
		return
	achievements[id] = true
	_write_cfg()
	achievement_unlocked.emit(id)

func achievement_info(id: String) -> Dictionary:
	for a in ACHIEVEMENTS:
		if a.id == id:
			return a
	return {}


func record_split(zone: int) -> Array:
	var k: = str(zone)
	if splits.has(k):
		return []
	splits[k] = stats_time
	var prev: float = float(best_splits.get(k, -1.0))
	if prev < 0.0 or stats_time < prev:
		best_splits[k] = stats_time
		_write_cfg()
	return [stats_time, prev]

func haptic(ms: int, amp: = 0.5) -> void :
	if mobile and settings.get("haptics", true):
		Input.vibrate_handheld(ms, amp)

func apply_window_settings() -> void :
	if DisplayServer.get_name() == "headless":
		return
	if mobile:
		Engine.max_fps = int(settings.get("fps_cap", 60))
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		return
	if settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1600, 900))
			var scr: = DisplayServer.screen_get_size()
			DisplayServer.window_set_position((scr - Vector2i(1600, 900)) / 2)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)

func character_path() -> String:
	for c in CHARACTERS:
		if c.id == settings.character:
			return c.path
	return CHARACTERS[0].path


func album_add(kind: String, id: String) -> void :
	if not album.has(kind):
		album[kind] = {}
	if not album[kind].has(id):
		album[kind][id] = true
		_write_cfg()

func album_has(kind: String, id: String) -> bool:
	return album.has(kind) and album[kind].has(id)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func reset_stats() -> void :
	stats_time = 0.0
	stats_falls = 0
	stats_jumps = 0
	stats_biggest_fall = 0.0
	stats_max_height = 0.0
	finished = false
	fall_marks = []
	story = {}
	splits = {}

func save_game(pos: Vector3, yaw: float) -> void :
	var d: = {
		"pos": [pos.x, pos.y, pos.z], 
		"yaw": yaw, 
		"time": stats_time, 
		"falls": stats_falls, 
		"jumps": stats_jumps, 
		"biggest_fall": stats_biggest_fall, 
		"max_height": stats_max_height, 
		"finished": finished, 
		"best_time": best_time, 
		"version": 1, 
		"route": route_sig, 
		"story": story, 
		"splits": splits, 
		"fall_marks": fall_marks, 
	}
	var f: = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

func load_game() -> Dictionary:
	if not has_save():
		return {}
	var f: = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	stats_time = d.get("time", 0.0)
	stats_falls = int(d.get("falls", 0))
	stats_jumps = int(d.get("jumps", 0))
	stats_biggest_fall = d.get("biggest_fall", 0.0)
	stats_max_height = d.get("max_height", 0.0)
	finished = d.get("finished", false)
	best_time = d.get("best_time", 0.0)
	story = d.get("story", {})
	splits = d.get("splits", {})
	fall_marks = d.get("fall_marks", [])
	return d

func delete_save() -> void :
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func respawn_at_start() -> void :
	if main and main.has_method("respawn_at_start"):
		main.respawn_at_start()

static func format_time(t: float) -> String:
	var s: = int(t)
	var h: = s / 3600
	var m: = (s % 3600) / 60
	var sec: = s % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, sec]
	return "%02d:%02d" % [m, sec]
