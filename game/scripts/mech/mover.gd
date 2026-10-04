extends AnimatableBody3D


var base: = Vector3.ZERO
var offset: = Vector3.ZERO
var period: = 8.0
var phase: = 0.0

func _ready() -> void :
	base = position
	_apply()

func _physics_process(_delta: float) -> void :
	_apply()

func _apply() -> void :
	var k: = 0.5 - 0.5 * cos(TAU * (Game.world_time / period + phase))
	position = base + offset * k

func position_at(t: float) -> Vector3:
	var k: = 0.5 - 0.5 * cos(TAU * (t / period + phase))
	return base + offset * k
