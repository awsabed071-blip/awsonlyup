extends RefCounted
class_name CharMaterials
# Material setup shared by the hero and the story actors. The realistic characters ship PBR
# materials (albedo, normal, roughness): skin gets subsurface scattering, the hair card an alpha
# cut, eyes a wet highlight, cloth stays matte. Returns the materials by name for later tweaks.

static func apply(model: Node3D, layers: int = 1) -> Dictionary:
	var out: = {}
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: = node as MeshInstance3D
		mi.layers = layers
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var src: = mi.get_active_material(si)
			if not (src is StandardMaterial3D):
				continue
			var sm: = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			var nm: = String(sm.resource_name).to_lower()
			if nm.begins_with("skin"):
				sm.subsurf_scatter_enabled = true
				sm.subsurf_scatter_strength = 0.3
				sm.subsurf_scatter_skin_mode = true
				sm.metallic_specular = 0.42
			elif nm.begins_with("hair"):
				sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				sm.alpha_scissor_threshold = 0.5
				sm.cull_mode = BaseMaterial3D.CULL_DISABLED
				sm.metallic_specular = 0.3
			elif nm.begins_with("eye"):
				sm.roughness = 0.1
				sm.metallic_specular = 0.8
			else:
				sm.metallic_specular = 0.18
			sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			mi.set_surface_override_material(si, sm)
			out[nm] = sm
	return out
