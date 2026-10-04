extends Node
# Development helper, inert in normal play. Launch with
#   --shots=<json file>  : [{"out": "/path.png", "mode": "menu|play|prologue", "pos": [x,y,z], "yaw": r, "pitch": r, "wait": s}, ...]
# to render frames of the menu, the climb at given positions or the prologue, then quit.
var _t: = 0.0
var _list: Array = []
var _i: = -1
var _started: = false
var _phase_t: = 0.0
var _busy: = false

func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			var f: = FileAccess.open(a.substr(8), FileAccess.READ)
			if f:
				var j = JSON.parse_string(f.get_as_text())
				if j is Array:
					_list = j
	if _list.is_empty():
		set_process(false)

func _process(delta: float) -> void :
	_t += delta
	var m = get_node_or_null("/root/Main")
	if m == null or m.get("player") == null or _busy:
		return
	if _i < 0:
		if _t < 3.0:
			return
		_i = 0
		_begin(m)
		return
	_phase_t += delta
	var sh: Dictionary = _list[_i]
	if _phase_t > float(sh.get("wait", 6.0)):
		_busy = true
		await RenderingServer.frame_post_draw
		var img: = get_viewport().get_texture().get_image()
		img.save_png(String(sh.out))
		print("SHOT saved ", sh.out, " ", img.get_size())
		_i += 1
		if _i >= _list.size():
			get_tree().quit()
			return
		_begin(m)
		_busy = false

func _begin(m) -> void :
	_phase_t = 0.0
	var sh: Dictionary = _list[_i]
	var mode: String = sh.get("mode", "play")
	if mode == "menu":
		return
	if mode == "prologue":
		Game.story["prologue"] = false
		Game.delete_save()
		m._on_play(true)
		return
	if mode == "memory":
		Game.story["prologue"] = true
		if m.mode != m.Mode.PLAYING:
			m._on_play(false)
		var z: int = int(sh.get("z", 2))
		var spot: Vector3 = m.story.memories[z].spot
		m.player.teleport(spot + Vector3(1.5, 0.3, 1.5), 0.0)
		get_tree().create_timer(1.0).timeout.connect( func(): m._play_memory(z))
		return
	if mode == "ending":
		Game.story["prologue"] = true
		if m.mode != m.Mode.PLAYING:
			m._on_play(false)
		var fp: Vector3 = m.level.finish_pos
		get_tree().create_timer(1.0).timeout.connect( func(): m.player.teleport(fp + Vector3(0, 0.3, 0), 0.0))
		return
	if sh.has("pos"):
		var p: Array = sh.pos
		Game.story["prologue"] = true
		m.player.teleport(Vector3(float(p[0]), float(p[1]), float(p[2])), 0.0)
	if m.mode != m.Mode.PLAYING:
		m._on_play(false)
	if sh.has("pos") and m.mode == m.Mode.PLAYING:
		var p2: Array = sh.pos
		m.player.teleport(Vector3(float(p2[0]), float(p2[1]), float(p2[2])), 0.0)
	if sh.has("yaw"):
		m.rig.yaw = float(sh.yaw)
	if sh.has("pitch"):
		m.rig.pitch = float(sh.pitch)
	m.rig.snap_to_target()
