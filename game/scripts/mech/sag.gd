extends AnimatableBody3D




var dip: = 0.13
var roll: = 0.05
var _base: = Transform3D()
var _load: = 0.0
var _stand_t: = 10.0
var _v: = 0.0
var _y: = 0.0
var _t: = 0.0
var _creak_t: = 0.0

func _ready() -> void :
	_base = transform
	sync_to_physics = true

func player_standing(_p) -> void :
	if _stand_t > 0.4:
		Sfx.play("creak", -9.0, 0.15)
		Game.haptic(12, 0.3)
		_creak_t = randf_range(1.2, 2.2)
	_stand_t = 0.0

func _physics_process(delta: float) -> void :
	_t += delta
	_stand_t += delta
	var want: = 1.0 if _stand_t < 0.12 else 0.0
	_load = move_toward(_load, want, delta * (3.0 if want > 0.0 else 5.0))

	var target: = dip * _load
	_v += ((target - _y) * 90.0 - _v * 9.0) * delta
	_y += _v * delta
	if _load > 0.5:
		_creak_t -= delta
		if _creak_t <= 0.0:
			_creak_t = randf_range(1.6, 3.0)
			Sfx.play("creak", -12.0, 0.2)
	var wob: = sin(_t * 5.3) * roll * _load + sin(_t * 13.0) * roll * 0.25 * _load
	var xf: = _base
	xf.origin.y -= _y
	xf.basis = _base.basis * Basis(Vector3.RIGHT, wob)
	transform = xf
