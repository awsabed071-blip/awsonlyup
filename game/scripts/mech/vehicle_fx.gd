extends Node


var kind: = ""
var jib_rel: = 0.0
var _body
var _snd: Node
var _burn_t: = 0.0
var _t: = 0.0
var _flame: MeshInstance3D
var _flame_light: OmniLight3D
var _fire: GPUParticles3D
var _cable: MeshInstance3D
var _trolley: MeshInstance3D

func _ready() -> void :
	_body = get_parent()
	_snd = _body.get_node_or_null("Snd")
	_flame = _body.get_node_or_null("Flame")
	_flame_light = _body.get_node_or_null("FlameLight")
	_fire = _body.get_node_or_null("Fire")
	_cable = _body.get_node_or_null("Cable")
	_trolley = _body.get_node_or_null("Trolley")
	_body.departed.connect(_on_departed)
	_body.arrived.connect(_on_arrived)
	if _flame:
		_flame.scale = Vector3(1, 0.3, 1)

func _on_departed(forward: bool) -> void :
	match kind:
		"train":
			_play_3d("horn", -2.0)
		"balloon":
			if forward:
				_burn_t = 2.2
				_play_3d("burner", 0.0)
		"rocket":
			if forward:
				if _snd:
					_snd.play()
				if _fire:
					_fire.emitting = true

func _on_arrived(forward: bool) -> void :
	if kind == "rocket" and _fire:
		_fire.emitting = false

func _play_3d(key: String, db: float) -> void :
	var s: AudioStream = Sfx._load(key)
	if s == null:
		return
	var p: = AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = "SFX"
	p.volume_db = db
	p.unit_size = 10.0
	p.max_distance = 80.0
	_body.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _physics_process(delta: float) -> void :
	_t += delta
	var v: Vector3 = _body.velocity_now
	var spd: = v.length()
	match kind:
		"train", "crane":
			if _snd:
				var want: = -30.0 + clampf(spd / 6.0, 0.0, 1.0) * 26.0
				_snd.volume_db = lerpf(_snd.volume_db, want, 1.0 - exp(-4.0 * delta))
				_snd.pitch_scale = 0.8 + clampf(spd / 8.0, 0.0, 1.0) * 0.4
			if _cable and _trolley:
				var off: Vector3 = _body.position - _body.base
				var top: = jib_rel - off.y
				var hook: = 0.2 + 2.8
				_trolley.position = Vector3(0, top - 0.2, 0)
				var L: = maxf(top - 0.4 - hook, 0.2)
				_cable.scale = Vector3(1, L, 1)
				_cable.position = Vector3(0, hook + L * 0.5, 0)
		"balloon":
			var rising: = v.y > 0.3
			if rising and fmod(_t, 4.5) < delta:
				_burn_t = 1.6
				_play_3d("burner", -4.0)
			_burn_t = maxf(_burn_t - delta, 0.0)
			var k: = clampf(_burn_t / 0.8, 0.0, 1.0)
			if _flame:
				var fl: = 0.3 + k * (0.9 + 0.15 * sin(_t * 31.0))
				_flame.scale = Vector3(1, fl, 1)
			if _flame_light:
				_flame_light.light_energy = k * (2.2 + 0.4 * sin(_t * 23.0))
		"rocket":
			var up: = v.y > 0.5
			if _flame_light:
				_flame_light.light_energy = lerpf(_flame_light.light_energy, 4.0 + sin(_t * 40.0) * 0.8 if up else 0.0, 1.0 - exp(-6.0 * delta))
			if _fire and v.y < -0.5 and not _fire.emitting:
				_fire.emitting = true
				_fire.amount_ratio = 0.35
			elif _fire and up:
				_fire.amount_ratio = 1.0
			if up and Game.main and Game.main.player:
				var pl: CharacterBody3D = Game.main.player
				if pl.is_on_floor() and pl.global_position.distance_to(_body.global_position) < 3.0:
					Game.main.rig.add_shake(0.35)
