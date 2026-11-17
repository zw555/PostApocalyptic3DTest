extends Node3D
## Adapter for this authored scene only. Core components have no scene paths/IDs.
const Zone = preload("res://scripts/visibility/visibility_zone.gd")
const Definitions = preload("res://scripts/apartment/floor5_regions.gd")
var zones: Array = []
var objects: Array = []
var records: Dictionary = {}
var occluders: Array = []
var portals: Array = []
var floor_exclusions: Array[RID] = []
var source_root: Node3D

func add_zone(id: String,label: String,box: AABB,is_public: bool,rank := 0) -> Node3D:
	var zone := Zone.new()
	zone.zone_id = id
	zone.name = id
	zone.display_name = label
	zone.bounds = box
	zone.priority = rank
	zone.public_connection = is_public
	add_child(zone)
	zones.append(zone)
	return zone

func register_object(root_node: Node3D,zone: Node3D,kind: String) -> void:
	var meshes: Array = [root_node] if root_node is GeometryInstance3D else root_node.find_children("*","GeometryInstance3D",true,false)
	var box := AABB()
	var first := true
	var owned := []
	for mesh in meshes:
		if records.has(mesh): continue
		var bounds: AABB = mesh.global_transform*mesh.get_aabb()
		box = bounds if first else box.merge(bounds)
		first = false
		owned.append(mesh)
		var record := {"zone":zone,"kind":kind,"root":root_node,"mesh":mesh,"visible":mesh.visible,"cast":mesh.cast_shadow,"material":mesh.material_override,"transparency":mesh.transparency}
		records[mesh] = record
		zone.members.append(mesh)
	if not owned.is_empty() and kind == "content": objects.append({"root":root_node,"zone":zone,"meshes":owned,"bounds":box})

func build(host: Node3D) -> void:
	var apartment: Node3D = host.get_node("Apartment")
	source_root = apartment
	global_transform = apartment.global_transform
	var by_id := {}
	for definition in Definitions.definitions():
		var b: Rect2 = definition.bounds
		var zone := add_zone(definition.id,definition.label,AABB(Vector3(b.position.x,-0.35,b.position.y),Vector3(b.size.x,3.0,b.size.y)),definition.path.begins_with("Corridor"))
		zone.playable = definition.playable
		by_id[definition.id] = zone
	var stair: Node3D = apartment.get_node("Stairwell")
	for definition in stair.get_meta("region_definitions"):
		var b: Rect2 = definition.bounds
		var zone := add_zone(definition.id,definition.label,AABB(Vector3(b.position.x,definition.low,b.position.y),Vector3(b.size.x,definition.high-definition.low,b.size.y)),true,10)
		zone.spatial_margin = 0.06
		zone.settle_seconds = 0.10
		by_id[definition.id] = zone
	var home: Node3D = by_id.apartment_501
	var hall: Node3D = by_id.corridor_f05
	var entry: Node3D = by_id.stairwell_f05
	var top: Node3D = by_id.stairs_landing_f05
	var upper: Node3D = by_id.stairs_f05_mid
	var turn: Node3D = by_id.stairs_turn
	var lower: Node3D = by_id.stairs_mid_f04
	var bottom: Node3D = by_id.stairs_landing_f04
	# Authoring references, not special branches in the visibility algorithm.
	var chain := [home,hall,entry,top,upper,turn,lower,bottom]
	for i in chain.size()-1:
		chain[i].neighbors.append(chain[i+1])
		chain[i+1].neighbors.append(chain[i])
	for zone in chain:
		for other in chain:
			if other.public_connection and absf(other.bounds.position.y-zone.bounds.position.y) < 2.1: zone.structure_links.append(other)
	for zone in zones:
		var b: AABB = zone.bounds
		if not zone.playable: continue
		# Stable authored space samples; stair runs follow the measured ramp plane.
		for x in [0.2,0.5,0.8]:
			for z in [0.12,0.35,0.60,0.85]:
				var point := Vector3(lerpf(b.position.x,b.end.x,x),0.3,lerpf(b.position.z,b.end.z,z))
				if zone in [upper,lower]:
					var dim: Dictionary = stair.get_meta("dimensions")
					point.y = lerpf(dim.five_y if zone == upper else dim.four_y,dim.mid_y,clampf((point.z-dim.start)/(dim.end-dim.start),0,1))+0.3
				elif zone == turn: point.y = stair.get_meta("dimensions").mid_y+0.3
				elif zone == bottom: point.y = stair.get_meta("dimensions").four_y+0.3
				zone.samples.append(point)
	for body in apartment.get_node("Furniture").find_children("*","StaticBody3D",true,false): floor_exclusions.append(body.get_rid())
	# Specific content groups retain whole-object E.1 sampling.
	for path in ["Furniture","LifeDetails","ExteriorTest"]:
		if apartment.has_node(path):
			for child in apartment.get_node(path).get_children():
				if child is Node3D: register_object(child,home,"content")
	for child in apartment.get_node("Corridor/LifeDetails").get_children():
		if child is Node3D: register_object(child,hall,"content")
	for mesh in apartment.find_children("*","GeometryInstance3D",true,false):
		if records.has(mesh): continue
		var path := str(apartment.get_path_to(mesh))
		var zone: Node3D = home
		var kind := "boundary"
		if mesh.get_meta("visibility_role","") == "floor_cover": kind = "cover"
		elif path.begins_with("NeighborRooms/"): kind = "sealed"
		elif path.begins_with("Corridor/"):
			zone = hall
			kind = "foundation" if mesh.name == "Floor" else "boundary"
		elif path.begins_with("Stairwell/"):
			var pos: Vector3 = apartment.to_local(mesh.global_position)
			zone = top if pos.y > -0.6 else turn if pos.y > -2.1 else bottom
			kind = "foundation" if mesh.name in ["Landing05","Landing04","TurnLanding"] or str(mesh.name).begins_with("Tread") or str(mesh.name).begins_with("Nosing") or "Flight" in path else "boundary"
		elif mesh.name == "Floor": kind = "private_floor"
		register_object(mesh,zone,kind)
	for target in host.structural_targets:
		var source: MeshInstance3D = host.mesh_for(target)
		if not records.has(source) or records[source].kind in ["cover","sealed"]: continue
		var dependents := []
		for mesh in host.dependencies:
			var path: NodePath = mesh.get_meta("cut_owner")
			var owner_node: Node3D = mesh.get_node(path) if str(path) == ".." else apartment.get_node("Architecture").get_node(path)
			if owner_node == target: dependents.append(mesh)
		occluders.append({"target":target,"source":source,"dependents":dependents})
	for door in host.doors:
		if door.has_meta("connects_regions"):
			var pair: Array = door.get_meta("connects_regions")
			portals.append({"door":door,"zones":[by_id[pair[0]],by_id[pair[1]]]})
