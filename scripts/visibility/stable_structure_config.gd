extends "res://scripts/visibility/floor5_information_config.gd"
## Only this authoring adapter knows the existing scene hierarchy.
var occluded_surface_color := Color("8c8b7e")

func build(host: Node3D) -> void:
	super.build(host)
	for mesh in records:
		var record: Dictionary = records[mesh]
		var role: String = record.category
		if role == "BuildingShell": role = "BuildingStructure"
		if record.kind == "private_floor": role = "StructureSurface"
		# Existing closed-room support slabs are backgrounds too, never roofs or
		# authorization for the room's content. Keep their authored floor height.
		if mesh.get_meta("visibility_role","") == "placeholder_floor":
			role = "StructureSurface"
			var owner_node: Node = mesh
			while owner_node != source_root and not owner_node.has_meta("region_id"): owner_node = owner_node.get_parent()
			var owners: Array = zones.filter(func(z):return z.zone_id == owner_node.get_meta("region_id",""))
			assert(owners.size() == 1,"Structural placeholder must declare its owning zone")
			record.zone = owners[0]
		var path := str(source_root.get_path_to(mesh))
		if path.begins_with("Stairwell/") and record.category == "ZoneInterior":
			# Actual inclined supporting decks are stable coarse structural surfaces;
			# detailed treads/rails/signs remain whole region-authorized objects.
			if mesh.get_meta("stair_platform",false) or mesh.get_meta("query_mesh",false): role = "StructureSurface"
		record.category = role
		record.structure_visible_from = zones.duplicate()
	# Content/props are not camera cut objects: don't hide half of a suitcase.
	occluders = occluders.filter(func(o):return records[o.source].category in ["BuildingStructure","StructureSurface"])
	for connection in portals:
		connection.erase("side_points") # E.1-only projection data; unused in A.3.
		connection.open_fraction = 0.60
		connection.close_fraction = 0.50
		connection.observer_height_range = Vector2(-0.35,preload("res://scripts/apartment/apartment_layout.gd").WALL_HEIGHT)
		connection.height_hysteresis = 0.10
		# Door leaves/details belong to their actual storey even when a landing
		# slab is cut by the camera. This is independent of Portal permissions.
	for door in host.doors:
		for mesh in records:
			if door.is_ancestor_of(mesh):
				records[mesh].height_reference = door
				records[mesh].height_interval = Vector2(-0.50,2.65)
	var dimensions: Dictionary = source_root.get_node("Stairwell").get_meta("dimensions")
	for entry in [["Floor05Sign",dimensions.five_y],["Floor04Sign",dimensions.four_y],["TurnSign",dimensions.mid_y]]:
		var sign: Node3D = source_root.get_node("Stairwell").get_node(entry[0])
		records[sign].height_point = source_root.to_global(Vector3(0,entry[1],0))
		records[sign].height_up = source_root.global_basis.y.normalized()
		records[sign].height_interval = Vector2(-0.55,0.55)
	# Keep the old source files for legacy entries, not a second active rule set.
	objects.clear()
	floor_exclusions.clear()
	for zone in zones: zone.structure_links.clear()
