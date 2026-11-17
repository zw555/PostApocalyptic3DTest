extends Node
const Registry = preload("res://scripts/visibility/visibility_zones.gd")
const Portal = preload("res://scripts/visibility/portal_visibility.gd")
const Occlusion = preload("res://scripts/visibility/camera_occlusion.gd")
const FloorShader = preload("res://materials/apartment/configured_floor_view.gdshader")
var host: Node3D
var config: Node3D
var registry := Registry.new()
var portal := Portal.new()
var camera_occlusion := Occlusion.new()
var decisions := {}
var floors := {}
var property_writes := 0
var current_region_id := ""
var area_weights := {}
var regions := {}
var doorway_in_transition := false
var detection_usec := 0
var ready_for_updates := false
var field_elapsed := 1.0
var dependent_sources := {}

func initialize(scene: Node3D) -> void:
	host = scene
	process_priority = 90
	process_physics_priority = 30
	registry.zones = config.zones
	registry.update(host.player.global_position,0,true)
	portal.configure(host,config,registry)
	camera_occlusion.configure(host,config,registry)
	for source in camera_occlusion.states:
		for mesh in camera_occlusion.states[source].record.dependents: dependent_sources[mesh] = source
	for zone in config.zones: regions[zone.zone_id] = {"label":zone.display_name}
	for mesh in config.records:
		if config.records[mesh].kind == "private_floor":
			var image := Image.create(48,32,false,Image.FORMAT_RF)
			image.fill(Color.BLACK)
			var texture := ImageTexture.create_from_image(image)
			var mat := ShaderMaterial.new()
			mat.shader = FloorShader
			var original: BaseMaterial3D = mesh.get_active_material(0)
			mat.set_shader_parameter("base_color",original.albedo_color)
			if original.albedo_texture: mat.set_shader_parameter("base_texture",original.albedo_texture)
			mat.set_shader_parameter("uv_scale",original.uv1_scale)
			mat.set_shader_parameter("roughness_value",original.roughness)
			mat.set_shader_parameter("permission_field",texture)
			var box: AABB = mesh.get_aabb()
			mat.set_shader_parameter("local_min",Vector2(box.position.x,box.position.z))
			mat.set_shader_parameter("local_size",Vector2(box.size.x,box.size.z))
			floors[mesh] = {"image":image,"texture":texture,"material":mat,"box":box}
	ready_for_updates = true
	_process(0)

func region_at(world: Vector3) -> String:
	var zone: Node3D = registry.at(world)
	return zone.zone_id if zone != null else ""

func region_label() -> String:
	return registry.current.display_name if registry.current != null else "区域外"

func observer_can_see(point: Vector3) -> bool:
	for adapter in portal.adapters:
		if registry.current in adapter.linked_zones and adapter.observer_can_see(point): return true
	return false

func hidden_names() -> Array[String]:
	var output: Array[String] = []
	for source in camera_occlusion.states:
		if camera_occlusion.states[source].cut: output.append(str(config.source_root.get_path_to(camera_occlusion.states[source].record.target)))
	return output

func is_hidden(target: Node3D) -> bool:
	for state in camera_occlusion.states.values():
		if state.record.target == target: return state.cut
	return false

func _physics_process(delta: float) -> void:
	if not ready_for_updates: return
	registry.update(host.player.global_position,delta)
	portal.tick(delta)
	camera_occlusion.extra_points.clear()
	for adapter in portal.adapters:
		for point in adapter.fan_points:
			if camera_occlusion.extra_points.size() < 18: camera_occlusion.extra_points.append(point)
	camera_occlusion.tick(delta)
	field_elapsed += delta

func floor_field(mesh: MeshInstance3D) -> void:
	var state: Dictionary = floors[mesh]
	for y in state.image.get_height():
		for x in state.image.get_width():
			var box: AABB = state.box
			var local := Vector3(lerpf(box.position.x,box.end.x,(x+0.5)/state.image.get_width()),box.end.y,lerpf(box.position.z,box.end.z,(y+0.5)/state.image.get_height()))
			state.image.set_pixel(x,y,Color(portal.floor_permission(mesh.to_global(local)),0,0))
	state.texture.update(state.image)

func _process(_delta: float) -> void:
	if not ready_for_updates: return
	current_region_id = registry.current.zone_id if registry.current != null else ""
	for zone in registry.zones: area_weights[zone.zone_id] = registry.weights.get(zone,0.0)
	doorway_in_transition = portal.adapters.any(func(a):return a.doorway_in_transition)
	detection_usec = camera_occlusion.usec
	decisions.clear()
	for mesh in config.records:
		var record: Dictionary = config.records[mesh]
		var alpha := 1.0
		var zone: Node3D = record.zone
		var reason: String = record.kind
		match record.kind:
			"cover","sealed": alpha = 0.0
			"content": alpha = maxf(portal.private_weight(zone),portal.permits.get(record.root,0.0))
			"foundation","boundary":
				if zone.public_connection: alpha = 1.0 if registry.public_allowed(zone,mesh.global_position) else 0.0
				elif zone != registry.current:
					# Keep same-height boundaries, without exposing a whole upper storey.
					alpha = 1.0 if registry.current != null and absf(zone.center_world().y-registry.current.center_world().y) < 2.1 else 0.0
			"private_floor":
				alpha = maxf(portal.private_weight(zone),0.0011 if portal.adapters.any(func(a):return not a.connection.is_closed() and registry.current in a.linked_zones) else 0.0)
		var cast_value: int = record.cast
		if camera_occlusion.states.has(mesh): alpha *= camera_occlusion.states[mesh].alpha
		if dependent_sources.has(mesh): alpha *= camera_occlusion.states[dependent_sources[mesh]].alpha
		if floors.has(mesh):
			if field_elapsed >= 0.05: floor_field(mesh)
			decisions[mesh] = {"visible":record.visible and alpha > 0.001,"cast":cast_value,"alpha":1.0,"material":floors[mesh].material,"region_coverage":portal.private_weight(zone),"reason":reason}
		else:
			decisions[mesh] = {"visible":record.visible and alpha > 0.001,"cast":cast_value if alpha > 0.001 else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,"alpha":alpha,"material":record.material,"reason":reason}
	commit_decisions()
	if field_elapsed >= 0.05: field_elapsed = 0.0

func commit_decisions() -> void:
	# Sole visual writer in the new entry. Components only return permissions.
	for mesh in decisions:
		var result: Dictionary = decisions[mesh]
		if mesh.visible != result.visible:
			mesh.visible = result.visible
			property_writes += 1
		if mesh.cast_shadow != result.cast: mesh.cast_shadow = result.cast
		if not is_equal_approx(mesh.transparency,1.0-result.alpha): mesh.transparency = 1.0-result.alpha
		if mesh.material_override != result.material: mesh.material_override = result.material
		if result.has("region_coverage"): mesh.set_instance_shader_parameter("region_coverage",result.region_coverage)
