extends Node






var by_text: = {}
var lines: = []
var _cache: = {}
var player: AudioStreamPlayer
var dirs: Array[String] = []
var _duck_tw: Tween
var by_id: = {}
var tts_voice: = ""
const TTS_STYLE: = {
	"grandma": {"pitch": 0.8, "rate": 0.82}, 
	"child": {"pitch": 1.55, "rate": 1.02}, 
	"hero": {"pitch": 0.92, "rate": 0.95}, 
	"narrator": {"pitch": 0.86, "rate": 0.88}, 
	"musahhir": {"pitch": 0.72, "rate": 0.9}, 
}

func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	var f: = FileAccess.open("res://data/voice_lines.json", FileAccess.READ)
	if f:
		var arr = JSON.parse_string(f.get_as_text())
		if arr is Array:
			lines = arr
			for o in arr:
				by_text[String(o.text)] = String(o.id)
				by_id[String(o.id)] = o
	var exe_dir: = OS.get_executable_path().get_base_dir()
	dirs = [exe_dir.path_join("voices"), ProjectSettings.globalize_path("user://voices"), ProjectSettings.globalize_path("res://voices")]
	player = AudioStreamPlayer.new()
	player.bus = "Voice" if AudioServer.get_bus_index("Voice") >= 0 else "SFX"
	add_child(player)
	if DisplayServer.get_name() != "headless" and ProjectSettings.get_setting("audio/general/text_to_speech", false):
		var vs: = DisplayServer.tts_get_voices_for_language("ar")
		if vs.size() > 0:
			tts_voice = vs[0]

func _line(text: String) -> Dictionary:
	var id: String = by_text.get(text, "")
	return by_id.get(id, {}) if id != "" else {}

func _tts_ok(text: String) -> bool:
	return tts_voice != "" and not _line(text).is_empty() and float(Game.settings.get("voice_vol", 1.0)) > 0.01

func count_available() -> int:
	var n: = 0
	for o in lines:
		if _load(String(o.id)) != null:
			n += 1
	return n

func _load(id: String) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	var s: AudioStream = null
	for d in dirs:
		for ext in ["ogg", "mp3", "wav"]:
			var p: = d.path_join(id + "." + ext)
			if FileAccess.file_exists(p):
				match ext:
					"ogg":
						s = AudioStreamOggVorbis.load_from_file(p)
					"mp3":
						s = AudioStreamMP3.load_from_file(p)
					"wav":
						s = AudioStreamWAV.load_from_file(p)
				if s:
					break
		if s:
			break
	if s == null:

		for ext2 in ["mp3", "ogg", "wav"]:
			var rp: = "res://assets/voices/%s.%s" % [id, ext2]
			if ResourceLoader.exists(rp):
				s = load(rp)
				break
	_cache[id] = s
	return s

func stream_for(text: String) -> AudioStream:
	var id: String = by_text.get(text, "")
	return _load(id) if id != "" else null

func length(text: String) -> float:
	var s: = stream_for(text)
	if s:
		return s.get_length()
	if _tts_ok(text):
		return _tts_estimate(text)
	return 0.0

func _tts_estimate(text: String) -> float:
	var st: Dictionary = TTS_STYLE.get(String(_line(text).get("voice", "narrator")), TTS_STYLE.narrator)
	var words: = text.split(" ", false).size()
	var pauses: = text.count("…") + text.count("،") * 0.5
	return (words / 2.3 + pauses * 0.35 + 0.3) / float(st.rate)

func speak(text: String) -> float:
	var s: = stream_for(text)
	if s == null:
		if _tts_ok(text):
			var o: = _line(text)
			var st: Dictionary = TTS_STYLE.get(String(o.get("voice", "narrator")), TTS_STYLE.narrator)
			var vol: = int(clampf(float(Game.settings.get("voice_vol", 1.0)) * float(Game.settings.get("master_vol", 1.0)), 0.0, 1.0) * 100.0)
			DisplayServer.tts_stop()
			DisplayServer.tts_speak(String(o.get("say", text)), tts_voice, vol, float(st.pitch), float(st.rate))
			var d: = _tts_estimate(text)
			_duck(d)
			return d
		return 0.0
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = false
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = false
	player.stream = s
	player.play()
	_duck(s.get_length())
	return s.get_length()

func stop() -> void :
	player.stop()
	if tts_voice != "":
		DisplayServer.tts_stop()

func _duck(dur: float) -> void :

	var bi: = AudioServer.get_bus_index("Music")
	if bi < 0:
		return
	var base: = linear_to_db(maxf(float(Game.settings.get("music_vol", 0.6)), 0.0001))
	if _duck_tw:
		_duck_tw.kill()
	_duck_tw = create_tween()
	_duck_tw.tween_method( func(v: float): AudioServer.set_bus_volume_db(bi, v), AudioServer.get_bus_volume_db(bi), base - 8.0, 0.25)
	_duck_tw.tween_interval(maxf(dur - 0.2, 0.1))
	_duck_tw.tween_method( func(v: float): AudioServer.set_bus_volume_db(bi, v), base - 8.0, base, 0.8)
