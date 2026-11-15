extends NavigationRegion3D
var synchronized := false
var error := ""

static func geometry_signature(store: Node3D) -> String:
	var entries: Array[String] = []
	for body in store.find_children("*","StaticBody3D",true,false):
		for shape in body.find_children("*","CollisionShape3D",true,false):
			if not shape.disabled and shape.shape is BoxShape3D and (body.collision_layer & 1) != 0:
				entries.append("%s|%s|%s"%[store.get_path_to(shape),str(shape.global_transform),str(shape.shape.size)])
	entries.sort()
	return "\n".join(entries).sha256_text()

func _ready() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/store_navigation_manifest.json"))
	if geometry_signature(get_parent().get_node("ConvenienceStore")) != manifest.geometry_signature:
		error = "Navigation source changed. Rebuild using scripts/ai/build_navigation.gd."
		push_error(error)
		return
	var mesh: NavigationMesh = load("res://assets/navigation/store_navigation.tres")
	NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map,mesh.cell_size)
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map,mesh.cell_height)
	navigation_mesh = mesh
	await get_tree().physics_frame
	await get_tree().physics_frame
	synchronized = NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0
