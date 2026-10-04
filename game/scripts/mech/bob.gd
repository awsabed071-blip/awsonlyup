extends Node3D

var amp: = 0.6
var speed: = 0.35
var spin: = 0.02
var _base: = Vector3.ZERO
var _ph: = 0.0
func _ready() -> void :
	_base = position
	_ph = randf() * TAU
func _process(delta: float) -> void :
	_ph += delta * speed
	position = _base + Vector3(0, sin(_ph) * amp, 0)
	rotation.y += spin * delta
