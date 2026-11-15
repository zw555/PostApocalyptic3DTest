extends SceneTree
func _initialize() -> void:
	var store: Node3D = load("res://scenes/environment/cad_store_environment.tscn").instantiate()
	root.add_child(store)
	for node in store.get_node("GroupedProducts").get_children():
		var mesh: ArrayMesh = node.multimesh.mesh
		print(node.name," visible=",node.visible," count=",node.multimesh.instance_count," aabb=",node.custom_aabb," authoritative_transform=",node.instance_transforms[0]," surfaces=",mesh.get_surface_count()," mesh_bounds=",mesh.get_aabb())
		break
	store.free()
	quit()
