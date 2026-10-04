extends AnimatableBody3D



signal departed(forward: bool)
signal arrived(forward: bool)

var base: = Vector3.ZERO
var offset: = Vector3.ZERO
var pts: Array[Vector3] = []
var seg_t: Array[float] = []
var dwell: = 3.0
var dwell_mid: = 0.6
var speed: = 5.0
var period: = 10.0
var phase: = 0.0
var travel: = 1.0
var kind: = ""
var velocity_now: = Vector3.ZERO
var _last: = Vector3.ZERO
var _state: = -1

func setup(points: Array, dw: float, spd: float) -> void :
	pts.clear()
	for p in points:
		pts.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	dwell = dw
	speed = spd
	seg_t.clear()
	travel = 0.0
	for i in range(pts.size() - 1):
		var L: = pts[i].distance_to(pts[i + 1])

		var t: = maxf(L / maxf(speed, 0.1) * 1.35, 1.5)
		seg_t.append(t)
		travel += t
	travel += dwell_mid * maxf(0.0, pts.size() - 2.0)
	period = 2.0 * dwell + 2.0 * travel
	offset = pts[pts.size() - 1]

func _ready() -> void :
	base = position
	_last = position
	_apply()

func _physics_process(delta: float) -> void :
	_apply()
	velocity_now = (position - _last) / maxf(delta, 0.0001)
	_last = position
	var st: = state_at(Game.world_time)
	if st != _state:
		if _state >= 0:
			if st == 1:
				departed.emit(true)
			elif st == 3:
				departed.emit(false)
			elif st == 2:
				arrived.emit(true)
			elif st == 0:
				arrived.emit(false)
		_state = st

func _apply() -> void :
	position = position_at(Game.world_time)

func _u(t: float) -> float:
	return fposmod(t / period + phase, 1.0) * period

func state_at(t: float) -> int:
	var u: = _u(t)
	if u < dwell:
		return 0
	u -= dwell
	if u < travel:
		return 1
	u -= travel
	if u < dwell:
		return 2
	return 3

func _along(u: float) -> Vector3:
	for i in seg_t.size():
		var st: float = seg_t[i]
		if u < st:
			var k: = u / st
			k = k * k * (3.0 - 2.0 * k)
			return pts[i].lerp(pts[i + 1], k)
		u -= st
		if i < seg_t.size() - 1:
			if u < dwell_mid:
				return pts[i + 1]
			u -= dwell_mid
	return pts[pts.size() - 1]

func position_at(t: float) -> Vector3:
	var u: = _u(t)
	if u < dwell:
		return base + pts[0]
	u -= dwell
	if u < travel:
		return base + _along(u)
	u -= travel
	if u < dwell:
		return base + pts[pts.size() - 1]
	u -= dwell
	return base + _along(travel - u)

func time_to_departure(t: float) -> float:
	var u: = _u(t)
	if u < dwell:
		return dwell - u
	return -1.0
