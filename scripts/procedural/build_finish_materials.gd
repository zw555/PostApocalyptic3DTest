extends SceneTree

func _initialize() -> void:
	var shader: Shader = load("res://materials/upgrade/architectural_finish.gdshader")
	for item in [["floor_finish", "a4a18e", true], ["wall_finish", "879588", false], ["wall_lower_finish", "4c655c", false]]:
		var material := ShaderMaterial.new()
		material.shader = shader
		material.resource_name = "Concrete / continuous " + str(item[0])
		material.set_shader_parameter("base_color", Color(item[1]))
		material.set_shader_parameter("floor_surface", item[2])
		material.set_shader_parameter("wear_amount", 0.40 if item[2] else 0.35)
		material.set_shader_parameter("dust_amount", 0.32)
		ResourceSaver.save(material, "res://materials/upgrade/%s.tres" % item[0])
	print("FINISH MATERIALS: PASS")
	quit()
