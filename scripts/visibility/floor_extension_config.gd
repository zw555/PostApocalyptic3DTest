extends "res://scripts/visibility/region_presentation_config.gd"
const Connection = preload("res://scripts/apartment/configurable_stair_connection.gd")
func build(host: Node3D) -> void:
	super.build(host)
	register_connection(host,host.extension,"stairs_landing_f04")
	configure_presentation()

func register_connection(host: Node3D, assembly: Node3D, start_id: String) -> void:
	var new_zones := []
	for definition in Connection.definitions(assembly):
		var zone := add_zone(definition.id,definition.id,definition.box,true,10)
		zone.global_transform = assembly.global_transform
		zone.spatial_margin = 0.06
		zone.settle_seconds = 0.10
		var box: AABB = definition.box
		zone.samples.assign([Vector3(box.get_center().x,definition.y+0.3,box.get_center().z)])
		new_zones.append(zone)
	var start: Node3D = zones.filter(func(z):return z.zone_id == start_id)[0]
	# A stair is an open physical volume, with no invented door or recursive grant.
	var connected: Array = start.get_meta("open_connections",[]).duplicate()
	connected.append(start)
	connected.append_array(new_zones)
	for zone in connected:
		zone.set_meta("open_connections",connected.filter(func(z):return z != zone))
	var chain := [start]+new_zones
	for i in chain.size()-1:
		chain[i].neighbors.append(chain[i+1])
		chain[i+1].neighbors.append(chain[i])
	for child in assembly.get_children():
		if not child is Node3D: continue
		var zone: Node3D = new_zones[0]
		if str(child.name).begins_with("FlightB") or str(child.name).begins_with("WestInnerRail"): zone = new_zones[2]
		elif str(child.name).begins_with("Turn"): zone = new_zones[1]
		elif str(child.name).begins_with("End"): zone = new_zones[3]
		register_object(child,zone,"content")
	for mesh in records:
		if not assembly.is_ancestor_of(mesh): continue
		var record: Dictionary = records[mesh]
		var owner_node: Node3D = mesh
		while owner_node.get_parent() != assembly: owner_node = owner_node.get_parent()
		record.category = "BuildingStructure" if owner_node.has_node("WallCollision") else "StructureSurface" if mesh.get_meta("stair_platform",false) or mesh.get_meta("query_mesh",false) else "ZoneInterior"
		record.structure_visible_from = connected
		# Same authoring interval applies to any floor IDs, transform and height.
		record.height_reference = assembly
		record.height_interval = Vector2(-assembly.get_meta("settings").height-0.35,0.25)
	for target in assembly.find_children("*","Node3D",true,false):
		if not target.get_meta("visibility_target",false): continue
		var source: GeometryInstance3D = target if target is GeometryInstance3D else target.get_node("Upper")
		if records[source].category not in ["BuildingStructure","StructureSurface"]: continue
		var dependents := []
		for mesh in target.find_children("*","GeometryInstance3D",true,false):
			if mesh != source: dependents.append(mesh)
		occluders.append({"target":target,"source":source,"dependents":dependents,"zones":connected})
		# Register native collision shapes on the existing query-only layer.
		var bodies: Array = [target.get_parent().get_node(str(target.name)+"Collision")] if target is GeometryInstance3D else target.find_children("*","StaticBody3D",true,false)
		for body in bodies:
			for shape in body.get_children():
				if shape is CollisionShape3D: host.occlusion.register_proxy(shape.shape,shape.global_transform,source,str(source.get_path()))
