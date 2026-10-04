extends Node



var _acc: = 0.0
var _frames: = 0
var _good: = 0
var _warm: = 5.0
var scale: = -1.0

func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.settings_changed.connect( func(): scale = -1.0)

func _process(delta: float) -> void :
	if not Game.settings.get("dyn_res", true):
		return
	var vp: = get_viewport()
	if scale < 0.0:
		scale = vp.scaling_3d_scale
		_warm = 3.0
	if _warm > 0.0:
		_warm -= delta
		_acc = 0.0
		_frames = 0
		return
	_acc += delta
	_frames += 1
	if _acc < 1.0:
		return
	var fps: = _frames / _acc
	_acc = 0.0
	_frames = 0
	var target: = float(Game.settings.get("fps_cap", 60))
	var top: = float(Game.settings.get("render_scale", 0.8))
	if fps < target * 0.9 and scale > 0.55:
		scale = maxf(scale - 0.07, 0.55)
		_good = 0
		_apply(vp)
	elif fps >= target - 1.5:
		_good += 1
		if _good >= 5 and scale < top:
			scale = minf(scale + 0.05, top)
			_good = 0
			_apply(vp)
	else:
		_good = 0

func _apply(vp: Viewport) -> void :
	vp.scaling_3d_scale = scale
