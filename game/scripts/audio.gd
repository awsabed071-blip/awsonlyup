extends Node


const SOUNDS: = {
	"jump": ["jump_1", "jump_2"], 
	"land": ["land_1", "land_2"], 
	"thud": ["thud"], 
	"step": ["step_1", "step_2", "step_3", "step_4"], 
	"bounce": ["bounce"], 
	"crumble": ["crumble"], 
	"gust": ["gust"], 
	"click": ["ui_click"], 
	"hover": ["ui_hover"], 
	"zone": ["zone_chime"], 
	"finish": ["finish"], 
	"whoosh": ["whoosh"], 
	"grab": ["grab"], 
	"zip": ["zip"], 
	"lantern_on": ["lantern_on"], 
	"memory": ["memory"], 
	"achievement": ["achievement"], 
	"split": ["split"], 
	"burner": ["burner"], 
	"rocket": ["rocket"], 
	"swell": ["swell"], 
	"eagle": ["eagle"], 
	"clank": ["clank"], 
	"creak": ["creak"], 
	"ding": ["ding"], 
	"radio_click": ["radio_click"], 
	"bike_bell": ["bike_bell"], 
	"pigeon_coo": ["pigeon_coo"], 
	"wings": ["wings"], 
	"swing_creak": ["swing_creak"], 
	"shutter": ["shutter"], 
	"light_rise": ["light_rise"], 
	"stars_chime": ["stars_chime"], 
	"kite": ["kite_flutter"], 
	"q_ok": ["q_ok"], 
	"q_bad": ["q_bad"], 
	"q_tick": ["q_tick"], 
	"q_chest": ["q_chest"], 
	"q_lit": ["q_lit"], 
	"q_win": ["q_win"], 
	"q_hit": ["q_hit"], 
	"q_laugh": ["q_laugh"], 
	"q_alarm": ["q_alarm"], 
	"q_eject": ["q_eject"], 
}

var _streams: = {}
var _pool: Array[AudioStreamPlayer] = []
var _wind: AudioStreamPlayer
var _fall: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_cur: = ""
var _music_active: AudioStreamPlayer
var wind_level: = 0.0
var fall_level: = 0.0
var amb_level: = 0.0
var heart_level: = 0.0
var breath_level: = 0.0
var _heart: AudioStreamPlayer
var _named: = {}

func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["Music", "SFX", "Ambience", "Voice"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx: = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	for key in SOUNDS.keys():
		for fname in SOUNDS[key]:
			var s: = _load(fname)
			if s:
				if not _streams.has(key):
					_streams[key] = []
				_streams[key].append(s)
	for i in 14:
		var p: = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_wind = _make_loop("wind_loop", "Ambience")
	_fall = _make_loop("fall_loop", "Ambience")
	_amb = _make_loop("birds_loop", "Ambience")
	_heart = _make_loop("heart_loop", "SFX")
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = "Music"
	add_child(_music_a)
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = "Music"
	add_child(_music_b)
	_music_active = _music_a
	apply_volumes()
	Game.settings_changed.connect(apply_volumes)

func _load(fname: String) -> AudioStream:
	for ext in [".ogg", ".wav"]:
		var p: String = "res://assets/audio/" + fname + ext
		if ResourceLoader.exists(p):
			return load(p)
	return null

func _make_loop(fname: String, bus: String) -> AudioStreamPlayer:
	var p: = AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = -80.0
	var s: = _load(fname)
	if s:
		if s is AudioStreamOggVorbis:
			s.loop = true
		elif s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = int(s.get_length() * s.mix_rate)
		p.stream = s
	add_child(p)
	return p

func apply_volumes() -> void :
	var s: = Game.settings
	AudioServer.set_bus_volume_db(0, linear_to_db(max(float(s.master_vol), 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(max(float(s.music_vol), 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(max(float(s.sfx_vol), 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), linear_to_db(max(float(s.sfx_vol), 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), linear_to_db(max(float(s.get("voice_vol", 1.0)), 0.0001)))

func play(key: String, db: = 0.0, pitch_var: = 0.0) -> void :
	if not _streams.has(key):
		return
	var arr: Array = _streams[key]
	for p in _pool:
		if not p.playing:
			p.stream = arr[randi() % arr.size()]
			p.volume_db = db
			p.pitch_scale = 1.0 + randf_range( - pitch_var, pitch_var)
			p.play()
			return

func start_ambience() -> void :
	for p in [_wind, _fall, _amb, _heart]:
		if p.stream and not p.playing:
			p.play()

func stop_ambience() -> void :
	for p in [_wind, _fall, _amb, _heart]:
		p.stop()




var _zone_mode: = false
var _zone_track: = ""
var _gap: = 0.0
var music_hold: = false

func zone_music(track: String) -> void :
	if _zone_mode and track == _zone_track:
		return
	var was_playing: = _zone_mode and _music_cur != "" and _music_active.playing
	_zone_mode = true
	_zone_track = track
	if was_playing or (_music_cur != "" and not _music_cur.begins_with("music_")):
		music_stop(3.5)
		_gap = randf_range(5.0, 9.0)
	elif _music_cur != "":
		music_stop(2.5)
		_gap = 3.0
	else:
		_gap = 2.5

func _zone_tick(delta: float) -> void :
	if not _zone_mode:
		return
	if music_hold:
		if _music_cur != "":
			music_stop(3.0)
			_gap = maxf(_gap, 20.0)
		return
	if _music_cur == "":
		_gap -= delta
		if _gap <= 0.0:
			_start_music(_zone_track, 5.0, false)
	elif not _music_active.playing:

		_music_cur = ""
		_gap = randf_range(55.0, 110.0)

func play_music(track: String, fade: = 3.0, looped: = true) -> void :
	_zone_mode = false
	_start_music(track, fade, looped)

func _start_music(track: String, fade: = 3.0, looped: = true) -> void :
	if track == _music_cur:
		return
	_music_cur = track
	var s: = _load(track)
	var old: = _music_active
	var nw: = _music_b if _music_active == _music_a else _music_a
	_music_active = nw
	if s:
		if s is AudioStreamOggVorbis:
			s.loop = looped
		nw.stream = s
		nw.volume_db = -40.0
		nw.play()
		var tw: = create_tween()
		tw.tween_property(nw, "volume_db", 0.0, fade)
	var tw2: = create_tween()
	tw2.tween_property(old, "volume_db", -60.0, fade)
	tw2.tween_callback(old.stop)

func _process(delta: float) -> void :
	_zone_tick(delta)
	if _wind.playing:
		_wind.volume_db = lerp(_wind.volume_db, linear_to_db(max(wind_level, 0.0005)) - 2.0, 1.0 - exp(-2.0 * delta))
		_wind.pitch_scale = 0.85 + wind_level * 0.3
	if _fall.playing:
		_fall.volume_db = lerp(_fall.volume_db, linear_to_db(max(fall_level, 0.0005)), 1.0 - exp(-6.0 * delta))
		_fall.pitch_scale = 0.8 + fall_level * 0.5
	if _heart.playing:
		var hl: float = clamp(heart_level, 0.0, 1.0)
		_heart.volume_db = lerp(_heart.volume_db, linear_to_db(max(hl, 0.0005)) + 2.0, 1.0 - exp(-2.5 * delta))
		_heart.pitch_scale = lerp(_heart.pitch_scale, 0.95 + hl * 0.4, 1.0 - exp(-1.0 * delta))
	for k in _named.keys():
		var np: AudioStreamPlayer = _named[k]
		var tgt: float = np.get_meta("target_db", -80.0)
		np.volume_db = move_toward(np.volume_db, tgt, delta * float(np.get_meta("fade_rate", 30.0)))
		if tgt <= -79.0 and np.volume_db <= -79.0 and np.playing:
			np.stop()
	if _amb.playing:
		_amb.volume_db = lerp(_amb.volume_db, linear_to_db(max(amb_level, 0.0005)) - 6.0, 1.0 - exp(-1.0 * delta))



func loop_on(fname: String, db: = 0.0, fade: = 1.5, bus: = "Ambience") -> void :
	var p: AudioStreamPlayer = _named.get(fname)
	if p == null:
		p = _make_loop(fname, bus)
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		_named[fname] = p
	p.set_meta("target_db", db)
	p.set_meta("fade_rate", 80.0 / maxf(fade, 0.05))
	if not p.playing:
		p.volume_db = -60.0 if fade > 0.05 else db
		p.play()

func loop_off(fname: String, fade: = 1.5) -> void :
	var p: AudioStreamPlayer = _named.get(fname)
	if p:
		p.set_meta("target_db", -80.0)
		p.set_meta("fade_rate", 80.0 / maxf(fade, 0.05))

func make_3d(fname: String, parent: Node3D, db: = 0.0, unit: = 6.0, max_dist: = 60.0) -> AudioStreamPlayer3D:
	var s: = _load(fname)
	if s == null:
		return null
	if s is AudioStreamOggVorbis:
		s.loop = true
	var p: = AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = "Ambience"
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = max_dist
	p.attenuation_filter_cutoff_hz = 6000.0
	p.autoplay = true
	parent.add_child(p)
	return p

func music_stop(fade: = 2.0) -> void :
	_music_cur = ""
	var tw: = create_tween()
	tw.tween_property(_music_active, "volume_db", -60.0, fade)
	tw.tween_callback(_music_active.stop)
