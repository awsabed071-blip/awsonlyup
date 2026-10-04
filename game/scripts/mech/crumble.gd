extends AnimatableBody3D


var delay: = 0.7
var respawn: = 3.5
var _state: = 0
var _t: = 0.0
var _base: = Vector3.ZERO
var _visuals: Array[Node3D] = []

func _ready() -> void :
	_base = position
	for c in get_children():
		if c is Node3D and not (c is CollisionShape3D) and not (c is Area3D):
			_visuals.append(c)

func player_standing(_p) -> void :
	if _state == 0:
		_state = 1
		_t = 0.0
		Sfx.play("crumble", -6.0, 0.1)

func _set_collision(on: bool) -> void :
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", not on)

func _physics_process(delta: float) -> void :
	match _state:
		1:
			_t += delta
			var s: = 0.05 + 0.1 * (_t / delay)
			for v in _visuals:
				v.position = Vector3(randf_range( - s, s), randf_range( - s, s) * 0.5, randf_range( - s, s))
			if _t >= delay:
				_state = 2
				_t = 0.0
				_set_collision(false)
				Sfx.play("crumble", -2.0, 0.1)
		2:
			_t += delta
			position = _base + Vector3(0, -6.0 * _t * _t, 0)
			for v in _visuals:
				v.scale = Vector3.ONE * clamp(1.0 - _t * 0.6, 0.05, 1.0)
			if _t >= respawn:
				_state = 3
				_t = 0.0
				position = _base
				for v in _visuals:
					v.position = Vector3.ZERO
		3:
			_t += delta
			var k: float = clamp(_t / 0.6, 0.0, 1.0)
			for v in _visuals:
				v.scale = Vector3.ONE * max(k, 0.05)
			if _t >= 0.6:
				_state = 0
				_set_collision(true)
