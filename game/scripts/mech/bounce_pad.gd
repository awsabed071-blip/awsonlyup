extends StaticBody3D


func on_bounced() -> void :
	for c in get_children():
		if c is MeshInstance3D:
			var tw: = create_tween()
			tw.tween_property(c, "scale", Vector3(1.15, 0.6, 1.15), 0.06)
			tw.tween_property(c, "scale", Vector3(0.95, 1.12, 0.95), 0.1)
			tw.tween_property(c, "scale", Vector3.ONE, 0.12)
