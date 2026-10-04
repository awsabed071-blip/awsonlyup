extends Area3D

var a: = Vector3.ZERO
var b: = Vector3.ZERO
var _inside: Array = []

func _ready() -> void :
	collision_layer = 0
	collision_mask = 2
	var cs: = CollisionShape3D.new()
	var sh: = SphereShape3D.new()
	sh.radius = 0.9
	cs.shape = sh
	add_child(cs)
	body_entered.connect( func(bd): if bd.has_method("start_zip"): _inside.append(bd))
	body_exited.connect( func(bd): _inside.erase(bd))

func _physics_process(_d: float) -> void :
	for p in _inside:
		if is_instance_valid(p):
			p.start_zip(a, b)
