extends "res://scripts/visibility/visibility_coordinator.gd"
## Reuses only the base final commit and public diagnostic interface.
const Zones = preload("res://scripts/visibility/information_zones.gd")
const Permissions = preload("res://scripts/visibility/adjacent_region_permissions.gd")
const CameraReadability = preload("res://scripts/visibility/information_camera_occlusion.gd")
var region_states := {}
var background_material: StandardMaterial3D
var decision_usec := 0

func initialize(scene: Node3D) -> void:
	host = scene
	process_priority = 90
	process_physics_priority = 30
	registry = Zones.new()
	registry.zones = config.zones
	registry.update(host.player.global_position,0,true)
	portal = Permissions.new()
	portal.configure(host,config,registry)
	camera_occlusion = CameraReadability.new()
	camera_occlusion.information = portal
	camera_occlusion.configure(host,config,registry)
	for source in camera_occlusion.states:
		for mesh in camera_occlusion.states[source].record.dependents: dependent_sources[mesh] = source
	for zone in registry.zones: regions[zone.zone_id] = {"label":zone.display_name}
	background_material = StandardMaterial3D.new()
	background_material.resource_name = "Unlit low-detail structural surface - no gameplay shadows"
	background_material.albedo_color = config.occluded_surface_color
	background_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	background_material.roughness = 1.0
	background_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ready_for_updates = true
	_process(0)

func _physics_process(delta: float) -> void:
	if not ready_for_updates: return
	registry.update(host.player.global_position,delta)
	portal.tick(delta)
	camera_occlusion.tick(delta)

func _process(_delta: float) -> void:
	if not ready_for_updates: return
	var started := Time.get_ticks_usec()
	current_region_id = registry.current.zone_id if registry.current != null else ""
	for zone in registry.zones:
		area_weights[zone.zone_id] = portal.weight(zone)
		region_states[zone.zone_id] = portal.region_state(zone)
	detection_usec = camera_occlusion.usec
	decisions.clear()
	for mesh in config.records:
		var record: Dictionary = config.records[mesh]
		var role: String = record.get("category","RegionContent")
		var weight: float = portal.weight(record.zone)
		var alpha := 0.0
		var material: Material = record.material
		var cast: int = record.cast
		var reason := "ungranted_content"
		match role:
			"BuildingStructure","StructureSurface":
				alpha = 1.0 if registry.current in record.structure_visible_from else 0.0
				reason = "stable_structure"
				if role == "StructureSurface" and not portal.allows_content(record.zone):
					material = background_material
					cast = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					reason = "occluded_structural_background"
			"ZoneInterior","RegionContent":
				alpha = weight
				reason = "whole_region_content" if weight > 0 else "ungranted_content"
			"GameInformation":
				var point: Vector3 = record.root.to_global(record.get("information_offset",Vector3.UP*0.8))
				var discovered: bool = record.get("discovered",false) or record.root.get_meta("visibility_discovered",false)
				alpha = 1.0 if portal.can_reveal_information(record.zone,point,discovered,record.root) else 0.0
				reason = "perceived_information" if alpha > 0 else "information_denied"
			"DebugOnly": reason = "debug_disabled"
			"Concealed": reason = "cover_or_unopened"
		if record.has("height_interval"):
			var origin: Vector3 = record.height_reference.global_position if record.has("height_reference") else record.height_point
			var up: Vector3 = record.height_reference.global_basis.y.normalized() if record.has("height_reference") else record.height_up
			var relative_height: float = up.dot(host.player.global_position-origin)
			if relative_height < record.height_interval.x or relative_height >= record.height_interval.y:
				alpha = 0.0
				reason = "different_height_detail"
		var camera_alpha := 1.0
		if camera_occlusion.states.has(mesh): camera_alpha *= camera_occlusion.states[mesh].alpha
		if dependent_sources.has(mesh): camera_alpha *= camera_occlusion.states[dependent_sources[mesh]].alpha
		alpha *= camera_alpha # Can reduce readability alpha, NEVER grant content.
		decisions[mesh] = {"visible":record.visible and alpha > 0.001,"cast":cast if alpha > 0.001 else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,"alpha":alpha,"material":material,"information":portal.allows_content(record.zone),"region_state":portal.region_state(record.zone),"reason":reason}
	commit_decisions()
	decision_usec = Time.get_ticks_usec()-started

func observer_can_see(point: Vector3) -> bool:
	var zone: Node3D = registry.at(point)
	return zone != null and portal.allows_content(zone) and portal.physical_line_of_sight(point)
