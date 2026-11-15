extends Node3D
## Single depth-tested outline proxy, never a product overlay or x-ray silhouette.
var display: MeshInstance3D
var mesh_cache: Dictionary = {}
var current_id := ""
var depleted := false
var strong: StandardMaterial3D
var weak: StandardMaterial3D
var config: Dictionary

func initialize(containers: Dictionary) -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/art_localization.json")).highlight
	var strong_color := Color(config.color)
	strong_color.a = config.alpha
	var weak_color := Color(config.empty_color)
	weak_color.a = config.empty_alpha
	strong = make_material(strong_color)
	weak = make_material(weak_color)
	display = MeshInstance3D.new()
	display.name = "CurrentContainerOutline"
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	display.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(display)
	for id in containers:
		var e: Dictionary = containers[id].entry
		mesh_cache[id] = proxy_mesh(e.length+config.padding_m,e.width+config.padding_m,e.height+0.025)
	display.hide()

func make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = false
	material.roughness = 1.0
	return material

func proxy_mesh(length: float, width: float, height: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var thickness: float = config.width_m
	for y in [0.025,height]:
		for side in [-1.0,1.0]:
			append_bar(tool,Vector3(length,thickness,thickness),Vector3(0,y,side*width/2))
			append_bar(tool,Vector3(thickness,thickness,width),Vector3(side*length/2,y,0))
	for x in [-length/2,length/2]:
		for z in [-width/2,width/2]:
			append_bar(tool,Vector3(thickness,height-0.025,thickness),Vector3(x,(height+0.025)/2,z))
	return tool.commit()

func append_bar(tool: SurfaceTool, size: Vector3, center: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	tool.append_from(box,0,Transform3D(Basis.IDENTITY,center))

func show_target(id: String, container: Dictionary = {}) -> void:
	if id.is_empty():
		current_id = ""
		display.hide()
		return
	if not mesh_cache.has(id):
		show_target("")
		return
	if current_id != id:
		var entry: Dictionary = container.entry
		display.mesh = mesh_cache[id]
		display.position = entry.position
		display.rotation.y = deg_to_rad(entry.rotation)
		current_id = id
	depleted = container.loot_inventory.values().all(func(e): return e.quantity == 0)
	display.material_override = weak if depleted else strong
	display.show()
