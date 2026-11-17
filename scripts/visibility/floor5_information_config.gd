extends "res://scripts/visibility/floor5_visibility_config.gd"
## A2 scene-only correction. Legacy A1 configuration and entry remain runnable.
func build(host: Node3D) -> void:
	super.build(host)
	var by_id := {}
	for zone in zones: by_id[zone.zone_id] = zone
	var home: Node3D = by_id.apartment_501
	var hall: Node3D = by_id.corridor_f05
	var entry: Node3D = by_id.stairwell_f05
	var stair_zones: Array = zones.filter(func(z):return z.get_parent() == self and z.priority == 10)
	var bath := add_zone("apartment_501_wet_room","501 卫生间",AABB(Vector3(1.55,-0.35,0.10),Vector3(3.05,3.0,2.0)),false,30)
	bath.spatial_margin = 0.06
	bath.samples.assign([Vector3(2.1,0.3,0.6),Vector3(2.1,0.3,1.5),Vector3(2.9,0.3,0.6),Vector3(3.8,0.3,1.5)])
	# Door-free links describe one interior volume, NOT a bypass of closed doors.
	hall.set_meta("open_connections",[entry])
	entry.set_meta("open_connections",[hall])
	for zone in stair_zones: zone.set_meta("open_connections",stair_zones.filter(func(other):return other != zone))
	var apartment: Node3D = source_root
	var bath_roots := []
	for path in ["Furniture/Toilet","Furniture/Basin","Furniture/Shower","Furniture/LaundryBasket","Furniture/FoldedTowel","Architecture/BathFloor","Architecture/BathroomLampBase","Architecture/BathroomLampDiffuser"]:
		if apartment.has_node(path): bath_roots.append(apartment.get_node(path))
	var debug_roots := []
	for path in ["ExteriorTest","ExteriorDirectionReference"]:
		if apartment.has_node(path): debug_roots.append(apartment.get_node(path))
	for mesh in records:
		var record: Dictionary = records[mesh]
		var path := str(apartment.get_path_to(mesh))
		var zone: Node3D = record.zone
		var category := "BuildingShell" if record.kind == "boundary" else "ZoneInterior"
		var surface: bool = record.kind in ["private_floor","foundation"] and mesh is MeshInstance3D and (mesh.name in ["Floor","Landing05","Landing04","TurnLanding"])
		if record.kind in ["sealed","cover"]: category = "Concealed"
		if debug_roots.any(func(root):return root == mesh or root.is_ancestor_of(mesh)): category = "DebugOnly"
		if bath_roots.any(func(root):return root == mesh or root.is_ancestor_of(mesh)):
			zone = bath
			category = "ZoneInterior"
			if mesh.name == "BathFloor": surface = true
		if path.begins_with("Stairwell/"):
			var root: Node3D = mesh
			while root.get_parent() != apartment.get_node("Stairwell"): root = root.get_parent()
			category = "BuildingShell" if root.has_node("WallCollision") else "ZoneInterior"
			record.root = mesh # Steps/rail elements never grant a whole staircase.
		if path.begins_with("Corridor/") and not path.begins_with("Corridor/Architecture/") and not path.begins_with("Corridor/Doors/"):
			category = "ZoneInterior" # A floor and decorative equipment are information.
		if path.begins_with("Architecture/PlankSeam"):
			category = "ZoneInterior"
			surface = true
			record.surface_parent = apartment.get_node("Architecture/Floor")
		# Protection classes outrank parent-path defaults (including corridor roofs).
		if record.kind in ["sealed","cover"]:
			category = "Concealed"
			surface = false
		record.zone = zone
		record.category = category
		record.surface_zones = [zone]
		if path.begins_with("Corridor/"): record.surface_zones = [hall,entry]
		if surface:
			record.kind = "private_floor"
		elif category == "ZoneInterior": record.kind = "content"
		else: record.kind = "boundary"
	# Rebuild whole-object permission groups from explicit classes/membership.
	objects.clear()
	var buckets := {}
	for mesh in records:
		var record: Dictionary = records[mesh]
		if record.category != "ZoneInterior" or record.kind == "private_floor": continue
		var key: Node3D = record.root
		if not buckets.has(key): buckets[key] = {"root":key,"zone":record.zone,"meshes":[],"bounds":mesh.global_transform*mesh.get_aabb()}
		buckets[key].meshes.append(mesh)
		buckets[key].bounds = buckets[key].bounds.merge(mesh.global_transform*mesh.get_aabb())
	objects = buckets.values()
	# Occluders carry visibility-zone references independently of their shell role.
	for record in occluders:
		record.zones = [home,bath,hall] if apartment.get_node("Architecture").is_ancestor_of(record.source) else [hall,entry] if apartment.get_node("Corridor").is_ancestor_of(record.source) else stair_zones
	portals.clear()
	var home_door: Node3D = apartment.get_node("Architecture/EntryDoor")
	var stair_door: Node3D = apartment.get_node("Corridor/Doors/Doorstairs")
	var bath_door: Node3D = apartment.get_node("Architecture/BathroomDoor")
	bath_door.set_meta("connects_regions",[home.zone_id,bath.zone_id])
	stair_door.set_meta("connects_regions",[entry.zone_id,by_id.stairs_landing_f05.zone_id])
	stair_door.set_meta("portal_half_width",0.49)
	stair_door.set_meta("portal_bottom",0.02)
	stair_door.set_meta("portal_top",2.10)
	portals.append({"door":home_door,"zones":[home,hall]})
	portals.append({"door":stair_door,"zones":[entry,by_id.stairs_landing_f05]})
	portals.append({"door":bath_door,"zones":[home,bath],"side_points":{home:apartment.to_global(Vector3(2.96,1,-0.6)),bath:apartment.to_global(Vector3(2.96,1,0.6))}})
