extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/zombie_validation.json"))
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.cell_size = settings.navigation_cell_size
	mesh.cell_height = settings.navigation_cell_height
	mesh.agent_radius = settings.navigation_radius
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.05
	mesh.agent_max_slope = 10.0
	mesh.region_min_size = 1.0
	mesh.region_merge_size = 2.0
	var data := NavigationMeshSourceGeometryData3D.new()
	var store: Node3D = scene.get_node("ConvenienceStore")
	NavigationServer3D.parse_source_geometry_data(mesh,data,store)
	NavigationServer3D.bake_from_source_geometry_data(mesh,data)
	var polygons: Array[PackedInt32Array] = []
	var vertices := mesh.get_vertices()
	for i in mesh.get_polygon_count():
		var polygon := mesh.get_polygon(i)
		if Array(polygon).all(func(index): return vertices[index].y < 0.2):
			polygons.append(polygon)
	# Counter/freezer/shelf tops are not a floor; no navigation onto furniture.
	mesh.clear_polygons()
	for polygon in polygons:
		mesh.add_polygon(polygon)
	var signature: String = load("res://scripts/ai/store_navigation.gd").geometry_signature(store)
	var result := ResourceSaver.save(mesh,"res://assets/navigation/store_navigation.tres")
	var file := FileAccess.open("res://data/store_navigation_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"geometry_signature":signature,"polygons":polygons.size(),"radius":mesh.agent_radius,"cell_size":mesh.cell_size,"cell_height":mesh.cell_height,"source":"Native static collider bake, floor polygons only"},"\t"))
	file.close()
	print("NAVIGATION BAKE ",polygons.size()," polygons, save=",result)
	scene.queue_free()
	await process_frame
	quit(0 if result == OK and not polygons.is_empty() else 1)
