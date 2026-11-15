extends RefCounted
const Survivor = preload("res://scripts/procedural/survivor_generator.gd")

static func build() -> Node3D:
	var visual := Survivor.build()
	visual.set_script(load("res://scripts/ai/zombie_visual.gd"))
	visual.rotation = Vector3.ZERO
	visual.get_node("UpperBody/Backpack").hide()
	var palette := {"survivor_skin":"89927C","survivor_coat":"73625F","survivor_trim":"564F49","survivor_pants":"434C51","survivor_canvas":"726A54","survivor_leather":"333835","survivor_hair":"3C413C"}
	var materials: Dictionary = {}
	for node in visual.find_children("*","MeshInstance3D",true,false):
		var source: Material = node.material_override
		if not source is StandardMaterial3D:
			continue
		var key: String = source.resource_path.get_file().get_basename()
		if not materials.has(key):
			var mat: StandardMaterial3D = source.duplicate()
			if palette.has(key):
				mat.albedo_color = Color(palette[key])
				mat.albedo_texture = null
				mat.roughness = 0.98
			materials[key] = mat
		node.material_override = materials[key]
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color("99927D")
	cloth.roughness = 1
	var loft = load("res://scripts/procedural/loft_mesh.gd")
	loft.rounded(visual.get_node("UpperBody"),"FrayedPatch",Vector3(0.12,0.15,0.012),Vector3(-0.12,0.1,-0.167),cloth,0.004)
	return visual
