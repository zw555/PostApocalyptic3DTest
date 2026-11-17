extends "res://scripts/visibility/region_presentation_coordinator.gd"
## Conservative candidate adapter. A.4 remains the sole decision/commit policy.
## Rebuild only on permission or authored height-boundary changes.
var complete_records := {}
var complete_surfaces: Array = []
var boundaries: Array[float] = []
var candidate_cache := {}
var externally_written := {}
var previous_key := ""
var inactive_decisions := {}
var candidate_count := 0
var rebuild_count := 0
func initialize(scene: Node3D) -> void:
	super.initialize(scene)
	for target in host.structural_targets: externally_written[host.mesh_for(target)] = true
	for mesh in host.dependencies: externally_written[mesh] = true
	complete_records = config.records.duplicate()
	complete_surfaces = presentation_surfaces.duplicate()
	for record in complete_records.values():
		if record.has("height_interval"):
			var origin: Vector3 = record.height_reference.global_position if record.has("height_reference") else record.height_point
			var up: Vector3 = record.height_reference.global_basis.y.normalized() if record.has("height_reference") else record.height_up
			if up.dot(Vector3.UP)>0.999:
				boundaries.append(origin.y+record.height_interval.x)
				boundaries.append(origin.y+record.height_interval.y)
		if record.category == "StructureSurface" and record.has("background_height"):
			boundaries.append(record.background_reference.global_position.y+record.background_height.x)
			boundaries.append(record.background_reference.global_position.y+record.background_height.y)
	boundaries.sort()

func eligible(record: Dictionary) -> bool:
	if record.category in ["BuildingStructure","StructureSurface"]:
		if not registry.current in record.structure_visible_from: return false
	elif record.category in ["ZoneInterior","RegionContent","GameInformation"]:
		if not portal.allows_content(record.zone): return false
	else: return false
	if record.has("height_interval"):
		var origin: Vector3 = record.height_reference.global_position if record.has("height_reference") else record.height_point
		var up: Vector3 = record.height_reference.global_basis.y.normalized() if record.has("height_reference") else record.height_up
		var height: float = up.dot(host.player.global_position-origin)
		if height < record.height_interval.x or height >= record.height_interval.y: return false
	if record.category == "StructureSurface" and record.has("background_height") and (not portal.allows_content(record.zone) or record.get("surface_storey_limit",false)):
		var height: float = record.background_reference.to_local(host.player.global_position).y
		if height < record.background_height.x or height >= record.background_height.y: return false
	return true

func _process(delta: float) -> void:
	if complete_records.is_empty():
		super._process(delta)
		return
	var started := Time.get_ticks_usec()
	var band := boundaries.bsearch(host.player.global_position.y,false)
	var key := str(registry.current.get_instance_id() if registry.current != null else 0)+":"+str(band)
	for zone in portal.content_zones: key += ":"+str(zone.get_instance_id())
	if key != previous_key:
		# One full A.4 commit revokes removed meshes before narrowing candidates.
		config.records = complete_records
		presentation_surfaces = complete_surfaces
		super._process(delta)
		if not candidate_cache.has(key):
			var subset := {}
			for mesh in complete_records:
				if externally_written.has(mesh) or eligible(complete_records[mesh]): subset[mesh] = complete_records[mesh]
			candidate_cache[key] = {"records":subset,"surfaces":complete_surfaces.filter(func(m):return subset.has(m))}
			rebuild_count += 1
		inactive_decisions = decisions.duplicate()
		for mesh in candidate_cache[key].records: inactive_decisions.erase(mesh)
		previous_key = key
	var candidates: Dictionary = candidate_cache[key]
	config.records = candidates.records
	presentation_surfaces = candidates.surfaces
	candidate_count = config.records.size()
	super._process(delta)
	decisions.merge(inactive_decisions,false) # Keep full diagnostics for inactive objects.
	config.records = complete_records
	presentation_surfaces = complete_surfaces
	decision_usec = Time.get_ticks_usec()-started
