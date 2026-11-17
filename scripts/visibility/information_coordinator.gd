extends "res://scripts/visibility/visibility_coordinator.gd"
const InformationRegistry = preload("res://scripts/visibility/information_zones.gd")
const InformationPortal = preload("res://scripts/visibility/information_portals.gd")
const InformationCamera = preload("res://scripts/visibility/information_camera_occlusion.gd")
const InformationFloor = preload("res://materials/apartment/information_floor_view.gdshader")
var information_ready := false
var field_updates := 0
var decision_usec := 0

func initialize(scene: Node3D) -> void:
	registry = InformationRegistry.new()
	portal = InformationPortal.new()
	camera_occlusion = InformationCamera.new()
	camera_occlusion.information = portal
	super.initialize(scene)
	for mesh in floors:
		var state: Dictionary = floors[mesh]
		state.material.shader = InformationFloor
		var mask := Image.create(48,32,false,Image.FORMAT_RF)
		for y in mask.get_height():
			for x in mask.get_width():
				var point := surface_point(mesh,x,y)
				mask.set_pixel(x,y,Color(float(registry.at(point) in config.records[mesh].surface_zones),0,0))
		state.mask_image = mask
		state.mask_texture = ImageTexture.create_from_image(mask)
		state.material.set_shader_parameter("zone_mask",state.mask_texture)
		state.cleared = false
		state.energy = 0.0
	# Floor trims reuse the same permission field in the parent surface space.
	# This preserves authored cross-zone meshes without exposing hidden-room strips.
	for mesh in floors:
		var record: Dictionary = config.records[mesh]
		if not record.has("surface_parent"): continue
		var parent: MeshInstance3D = record.surface_parent
		var state: Dictionary = floors[mesh]
		var source: Dictionary = floors[parent]
		state.surface_parent = parent
		state.texture = source.texture
		state.material.set_shader_parameter("permission_field",source.texture)
		state.material.set_shader_parameter("zone_mask",source.mask_texture)
		state.material.set_shader_parameter("local_min",Vector2(source.box.position.x,source.box.position.z))
		state.material.set_shader_parameter("local_size",Vector2(source.box.size.x,source.box.size.z))
		state.material.set_shader_parameter("surface_transform",parent.global_transform.affine_inverse()*mesh.global_transform)
	information_ready = true
	_process(0)

func surface_point(mesh: MeshInstance3D,x: int,y: int) -> Vector3:
	var state: Dictionary = floors[mesh]
	var box: AABB = state.box
	return mesh.to_global(Vector3(lerpf(box.position.x,box.end.x,(x+0.5)/state.image.get_width()),box.end.y+0.015,lerpf(box.position.z,box.end.z,(y+0.5)/state.image.get_height())))

func floor_field(mesh: MeshInstance3D) -> void:
	var state: Dictionary = floors[mesh]
	if state.has("surface_parent"):
		state.energy = floors[state.surface_parent].energy
		return
	var record: Dictionary = config.records[mesh]
	var allowed: bool = record.surface_zones.any(func(z):return portal.zone_permitted(z))
	if not allowed:
		if not state.cleared:
			state.image.fill(Color.BLACK)
			state.texture.update(state.image)
			state.cleared = true
		state.energy = 0.0
		return
	if record.surface_zones.any(func(z):return portal.private_weight(z) >= 0.999): return
	state.energy = 0.0
	for y in state.image.get_height():
		for x in state.image.get_width():
			var coverage: float = portal.floor_permission(surface_point(mesh,x,y))
			state.image.set_pixel(x,y,Color(coverage,0,0))
			state.energy += coverage
	state.texture.update(state.image)
	state.cleared = false
	field_updates += 1

func _process(_delta: float) -> void:
	if not information_ready: return
	var started := Time.get_ticks_usec()
	current_region_id = registry.current.zone_id if registry.current != null else ""
	for zone in registry.zones: area_weights[zone.zone_id] = registry.weights.get(zone,0.0)
	doorway_in_transition = portal.adapters.any(func(a):return a.doorway_in_transition)
	detection_usec = camera_occlusion.usec
	decisions.clear()
	for mesh in config.records:
		var record: Dictionary = config.records[mesh]
		var category: String = record.get("category","ZoneInterior")
		var alpha := 0.0
		var weight := portal.private_weight(record.zone)
		var permitted: bool = record.surface_zones.any(func(z):return portal.zone_permitted(z)) if record.has("surface_zones") else portal.zone_permitted(record.zone)
		var reason := "information_denied"
		match category:
			"BuildingShell":
				alpha = 1.0 if registry.current != null and absf(record.zone.center_world().y-registry.current.center_world().y) < 3.2 else 0.0
				reason = "building_shell"
			"ZoneInterior":
				alpha = maxf(weight,portal.permits.get(record.root,0.0))
				if floors.has(mesh): alpha = maxf(weight,0.0011 if permitted else 0.0)
				reason = "current_interior" if weight > 0 else "portal_interior" if permitted or alpha > 0 else "information_denied"
			"DebugOnly": reason = "debug_only_disabled"
			"Concealed": reason = "unopened_or_cover"
		# Camera can ONLY reduce the result. It never supplies alpha/permission.
		var camera_alpha := 1.0
		if camera_occlusion.states.has(mesh): camera_alpha *= camera_occlusion.states[mesh].alpha
		if dependent_sources.has(mesh): camera_alpha *= camera_occlusion.states[dependent_sources[mesh]].alpha
		alpha *= camera_alpha
		if floors.has(mesh):
			if field_elapsed >= 0.05 or not permitted: floor_field(mesh)
			if weight <= 0.001 and floors[mesh].energy <= 0.001: alpha = 0.0
			decisions[mesh] = {"visible":record.visible and alpha > 0.001,"cast":record.cast if alpha > 0.001 else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,"alpha":camera_alpha,"material":floors[mesh].material,"region_coverage":weight,"information":permitted,"reason":reason}
		else:
			decisions[mesh] = {"visible":record.visible and alpha > 0.001,"cast":record.cast if alpha > 0.001 else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,"alpha":alpha,"material":record.material,"information":permitted or weight > 0,"reason":reason}
	commit_decisions() # Inherited sole writer, no other component writes Mesh state.
	if field_elapsed >= 0.05: field_elapsed = 0
	decision_usec = Time.get_ticks_usec()-started
