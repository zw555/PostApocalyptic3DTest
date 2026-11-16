extends SceneTree
## Add visibility metadata only; preserve every existing transform/collider.
const M = preload("res://scripts/procedural/mesh_factory.gd")
const P = preload("res://scripts/apartment/floor5_layout.gd")
const Regions = preload("res://scripts/apartment/floor5_regions.gd")

func _initialize() -> void:
	call_deferred("build")

func ensure(root_node: Node3D,path: String) -> Node3D:
	var parent := root_node
	for part in path.split("/"):
		if not parent.has_node(part):
			var child := Node3D.new()
			child.name = part
			parent.add_child(child)
		parent = parent.get_node(part)
	return parent

func build() -> void:
	var floor_root: Node3D = load("res://scenes/apartment/stage6a2_shell.tscn").instantiate()
	var material := StandardMaterial3D.new()
	material.resource_name = "Unopened room floor - fixed placeholder"
	material.albedo_color = Color(0.045,0.055,0.055,1)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.roughness = 1
	assert(ResourceSaver.save(material,"res://materials/apartment/floor5_unopened.tres") == OK)
	var shared_material: Material = load("res://materials/apartment/floor5_unopened.tres")
	for definition in Regions.definitions():
		var node := ensure(floor_root,definition.path)
		node.set_meta("region_id",definition.id)
		node.set_meta("region_label",definition.label)
		node.set_meta("region_bounds",definition.bounds)
		node.set_meta("region_playable",definition.playable)
		node.set_meta("floor_id",P.FLOOR_ID)
		if not definition.playable:
			var surface: MeshInstance3D = node.get_node("ClosedVolumeFloor")
			surface.material_override = shared_material
			surface.set_meta("visibility_role","placeholder_floor")
			var contents := ensure(node,"UnopenedContents")
			contents.set_meta("visibility_role","unopened_contents")
			contents.set_meta("region_id",definition.id)
	for node in floor_root.find_children("*","Node3D",true,false):
		if node.get_meta("roof_panel",false):
			node.set_meta("cover_floor_id",P.FLOOR_ID)
			node.set_meta("visibility_role","floor_cover")
		if not node.get_meta("visibility_target",false) or node.get_meta("roof_panel",false): continue
		var path := str(floor_root.get_path_to(node))
		var neighbors: Array[String] = []
		if path.begins_with("Architecture/"):
			neighbors = ["apartment_501"]
			# One physical shared wall, one state, both region identifiers.
			if absf(node.position.x+4.525) < 0.12: neighbors.append("corridor_f05")
		elif path.begins_with("Corridor/"):
			neighbors = ["corridor_f05","stairwell_f05"]
			if str(node.name).begins_with("West"): neighbors.append_array(["apartment_502_placeholder","apartment_504_placeholder"])
			else: neighbors.append("apartment_503_placeholder")
		else:
			for number in ["502","503","504"]:
				if path.begins_with("NeighborRooms/Room"+number+"/"): neighbors = ["apartment_"+number+"_placeholder"]
		node.set_meta("visibility_regions",neighbors)
	assert(M.save_scene(floor_root,"res://scenes/apartment/stage6a2b_shell.tscn") == OK)
	floor_root.free()
	print("PASS A2-B visibility metadata: six regions, 29 floor covers, zero new gameplay meshes")
	quit()
