extends SceneTree
## Presentation metadata only. All shells, portals and native collisions remain.
const M = preload("res://scripts/procedural/mesh_factory.gd")
const SHARED_501 := ["WestNorth","WestMiddle","WestSouth","WestWindowInfill","EntryDoor","EntryFrame","EntryFrame2","EntryLintel","EntryFrameHeader","Portal501"]

func _initialize() -> void:
	call_deferred("build")

func build() -> void:
	var scene: Node3D = load("res://scenes/apartment/stage6a2b_shell.tscn").instantiate()
	# Metadata on instance roots survives PackedScene composition; writing only
	# inherited child metadata is not serialized unless children are editable.
	for path in ["Furniture","LifeDetails","ExteriorTest"]:
		if scene.has_node(path): scene.get_node(path).set_meta("region_presentation","interior_501")
	var classes := {}
	for mesh in scene.find_children("*","GeometryInstance3D",true,false):
		var path := str(scene.get_path_to(mesh))
		var presentation := "boundary"
		if mesh.get_meta("visibility_role","") == "floor_cover":
			presentation = "floor_cover"
		elif path.begins_with("NeighborRooms/"):
			presentation = "unopened_envelope"
		elif path.begins_with("Furniture/") or path.begins_with("LifeDetails/") or path.begins_with("ExteriorTest/"):
			presentation = "interior_501"
		elif path.begins_with("Architecture/"):
			var part := path.split("/")[1]
			presentation = "boundary" if part in SHARED_501 else "interior_501"
		else:
			# Original apartment life details may use a separate root group.
			var is_corridor := path.begins_with("Corridor/")
			if not is_corridor: presentation = "interior_501"
		mesh.set_meta("region_presentation",presentation)
		classes[presentation] = int(classes.get(presentation,0))+1
	assert(M.save_scene(scene,"res://scenes/apartment/stage6a2b_regions_shell.tscn") == OK)
	scene.free()
	print("PASS presentation metadata, geometry/colliders unchanged: ",classes)
	quit()
