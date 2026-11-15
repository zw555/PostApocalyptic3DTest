extends Node
## Query-only PhysicsServer RIDs preserve every original body, shape and layer.
## The private mask viewport shares meshes, but never shares the gameplay world.
var config: Dictionary
var camera: Camera3D
var player: CharacterBody3D
var enabled := true
var occluded := false
var blocked_samples := 0
var opacity := 0.0
var hit_labels: Array[String] = []
var detection_usec := 0
var detection_total_usec := 0
var detection_frames := 0
var proxies: Dictionary = {}
var owned_shapes: Array[Shape3D] = []
var originals: Array[MeshInstance3D] = []
var copies: Array[MeshInstance3D] = []
var mask_view: SubViewport
var mask_camera: Camera3D
var mask_material: ShaderMaterial
var outline_material: ShaderMaterial
var overlay: MeshInstance3D
var debug_layer: CanvasLayer
var debug_label: Label
var initialized := false
var candidate_time := 0.0
var last_candidate := false
var last_mode := -1
var last_position := Vector3.ZERO
var shared_detector: Node
var debug_controls := true

func initialize(main_camera: Camera3D, actor: CharacterBody3D, detector: Node = null, overrides: Dictionary = {}) -> void:
	camera = main_camera
	player = actor
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/player_occlusion.json"))
	config.merge(overrides,true)
	shared_detector = detector
	debug_controls = detector == null
	enabled = config.enabled
	# A dedicated query space layer, with zero response mask. No CollisionObject
	# or CollisionShape in the original scene is mutated or duplicated as a node.
	var scene := camera.get_parent()
	if detector:
		proxies = detector.proxies
	for body in ([] if detector else scene.get_node("ConvenienceStore").find_children("*","StaticBody3D",true,false)):
		for shape in body.find_children("*","CollisionShape3D",true,false):
			if shape.disabled or not shape.shape is BoxShape3D:
				continue
			var extent: Vector3 = shape.shape.size
			if extent.y >= float(config.minimum_obstacle_height_m):
				register_proxy(shape.shape,shape.global_transform,body.get_parent(),str(scene.get_path_to(body)))
	# Thin structural posts have visible geometry but deliberately no movement
	# collider. Register only tall BoxMeshes in the architectural section.
	for mesh in ([] if detector else scene.get_node("ConvenienceStore/Architecture").get_children()):
		if mesh is MeshInstance3D and mesh.mesh is BoxMesh and mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			var size_value: Vector3 = mesh.mesh.size
			if size_value.y >= 1.8 and maxf(size_value.x,size_value.z) <= 0.3:
				var shape := BoxShape3D.new()
				shape.size = size_value
				owned_shapes.append(shape)
				register_proxy(shape,mesh.global_transform,mesh,str(scene.get_path_to(mesh)))
	build_renderer()
	build_debug()
	last_position = player.global_position
	process_priority = 100 # After camera follow and the visual animator.
	initialized = true

func register_proxy(shape: Shape3D, pose: Transform3D, source: Node3D, label: String) -> void:
	var rid := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(rid,PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_collision_layer(rid,int(config.collision_mask))
	PhysicsServer3D.body_set_collision_mask(rid,0)
	PhysicsServer3D.body_add_shape(rid,shape.get_rid())
	PhysicsServer3D.body_set_state(rid,PhysicsServer3D.BODY_STATE_TRANSFORM,pose)
	PhysicsServer3D.body_set_space(rid,player.get_world_3d().space)
	proxies[rid] = {"source":source,"label":label}

func build_renderer() -> void:
	mask_view = SubViewport.new()
	mask_view.name = "PlayerDepthMask"
	mask_view.own_world_3d = true
	mask_view.gui_disable_input = true
	mask_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	mask_view.size = Vector2i(1440,1000)
	add_child(mask_view)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	mask_view.add_child(environment)
	mask_camera = Camera3D.new()
	mask_view.add_child(mask_camera)
	mask_camera.current = true
	mask_material = ShaderMaterial.new()
	mask_material.shader = load("res://materials/player_occlusion_mask.gdshader")
	for mesh in player.get_node("Visual").find_children("*","MeshInstance3D",true,false):
		var copy := MeshInstance3D.new()
		copy.mesh = mesh.mesh
		copy.material_override = mask_material
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mask_view.add_child(copy)
		originals.append(mesh)
		copies.append(copy)
	outline_material = ShaderMaterial.new()
	outline_material.shader = load("res://materials/player_occlusion_outline.gdshader")
	outline_material.set_shader_parameter("player_mask",mask_view.get_texture())
	outline_material.set_shader_parameter("outline_color",Color(config.color))
	outline_material.set_shader_parameter("intensity",float(config.intensity))
	outline_material.set_shader_parameter("width_pixels",float(config.width_pixels))
	outline_material.set_shader_parameter("depth_span",float(config.depth_span_m))
	outline_material.set_shader_parameter("depth_bias",float(config.depth_bias_m))
	mask_material.set_shader_parameter("depth_span",float(config.depth_span_m))
	overlay = MeshInstance3D.new()
	overlay.name = "OccludedContourOnly"
	var quad := QuadMesh.new()
	quad.size = Vector2(2,2)
	overlay.mesh = quad
	overlay.material_override = outline_material
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.extra_cull_margin = 16384
	camera.add_child(overlay)
	overlay.position.z = -1
	overlay.hide()

func build_debug() -> void:
	debug_layer = CanvasLayer.new()
	debug_layer.layer = 5
	add_child(debug_layer)
	debug_label = Label.new()
	debug_label.position = Vector2(20,180)
	debug_label.add_theme_font_override("font",load("res://assets/fonts/WangjiaUI.tres"))
	debug_label.add_theme_font_size_override("font_size",15)
	debug_label.add_theme_color_override("font_color",Color("E9DEC5"))
	debug_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	debug_label.add_theme_constant_override("shadow_offset_x",2)
	debug_label.add_theme_constant_override("shadow_offset_y",2)
	debug_layer.add_child(debug_label)
	debug_label.hide()

func source_visible(source: Node3D) -> bool:
	if not source.is_visible_in_tree():
		return false
	if source is MeshInstance3D:
		return source.transparency < 0.5 and source.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for mesh in source.find_children("*","GeometryInstance3D",true,false):
		if mesh.is_visible_in_tree() and mesh.transparency < 0.5 and mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			return true
	return false

func detect() -> bool:
	var start := Time.get_ticks_usec()
	blocked_samples = 0
	hit_labels.clear()
	var visible_sources: Dictionary = {}
	for offset in config.sample_offsets:
		var point := player.global_position + Vector3(offset[0],offset[1],offset[2])
		# Orthographic rays are parallel: never converge them at camera.position.
		var origin := camera.project_ray_origin(camera.unproject_position(point))
		var query := PhysicsRayQueryParameters3D.create(origin,point,int(config.collision_mask),[player.get_rid()])
		for attempt in 8:
			var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty():
				break
			if proxies.has(hit.rid) and not visible_sources.has(hit.rid):
				visible_sources[hit.rid] = source_visible(proxies[hit.rid].source)
			if proxies.has(hit.rid) and visible_sources[hit.rid]:
				blocked_samples += 1
				var label: String = proxies[hit.rid].label
				if label not in hit_labels:
					hit_labels.append(label)
				break
			query.exclude = query.exclude + [hit.rid]
	detection_usec = Time.get_ticks_usec()-start
	detection_total_usec += detection_usec
	detection_frames += 1
	return float(blocked_samples)/config.sample_offsets.size() >= float(config.blocked_fraction)

func reset_state() -> void:
	occluded = false
	blocked_samples = 0
	hit_labels.clear()
	candidate_time = 0
	last_candidate = false
	opacity = 0
	if overlay:
		overlay.hide()
		mask_view.render_target_update_mode = SubViewport.UPDATE_DISABLED

func set_enabled(value: bool) -> void:
	enabled = value
	reset_state()
	if not enabled:
		detection_usec = 0

func _process(delta: float) -> void:
	if not initialized:
		return
	if is_instance_valid(shared_detector):
		# Enemy visibility policy may additionally disable its own contour. F9
		# always controls both actors without adding a second input handler.
		var desired: bool = shared_detector.enabled and player.visible and player.get_meta("outline_allowed",true)
		if enabled != desired:
			set_enabled(desired)
	if camera.mode != last_mode or last_position.distance_to(player.global_position) > 2.0:
		reset_state()
	last_mode = camera.mode
	last_position = player.global_position
	var candidate := detect() if enabled else false
	if candidate != last_candidate:
		candidate_time = 0
		last_candidate = candidate
	candidate_time += delta
	if candidate != occluded and candidate_time >= float(config.enter_delay if candidate else config.exit_delay):
		occluded = candidate
	opacity = move_toward(opacity,1.0 if occluded else 0.0,delta/maxf(0.001,float(config.smooth_time)))
	if opacity > 0.001 and enabled:
		sync_renderer()
		overlay.show()
		mask_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		overlay.hide()
		mask_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if debug_label.visible:
		debug_label.text = "遮挡调试 F8 | 功能开关 F9\n视角 F%d  遮挡 %s (%d/%d)\n轮廓 %s  当前显示 %s  强度 %.2f  局部透明：关闭\n检测 %d μs | %s"%[camera.mode,"是" if occluded else "否",blocked_samples,config.sample_offsets.size(),"启用" if enabled else "禁用","是" if overlay.visible else "否",opacity,detection_usec,"、".join(hit_labels)]

func sync_renderer() -> void:
	var dimensions := Vector2i(camera.get_viewport().get_visible_rect().size)
	if mask_view.size != dimensions:
		mask_view.size = dimensions
	mask_camera.projection = camera.projection
	mask_camera.keep_aspect = camera.keep_aspect
	mask_camera.size = camera.size
	mask_camera.near = camera.near
	mask_camera.far = camera.far
	mask_camera.global_transform = camera.global_transform
	for i in originals.size():
		copies[i].global_transform = originals[i].global_transform
		copies[i].visible = originals[i].is_visible_in_tree()
	var center := -camera.to_local(player.global_position+Vector3.UP*0.85).z
	mask_material.set_shader_parameter("center_depth",center)
	outline_material.set_shader_parameter("center_depth",center)
	outline_material.set_shader_parameter("texel_size",Vector2.ONE/Vector2(dimensions))
	outline_material.set_shader_parameter("opacity",opacity)

func _unhandled_key_input(event: InputEvent) -> void:
	if debug_controls and initialized and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			debug_label.visible = not debug_label.visible
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F9:
			set_enabled(not enabled)
			get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if shared_detector == null:
		for rid in proxies:
			PhysicsServer3D.free_rid(rid)
		proxies.clear()
	if is_instance_valid(overlay):
		overlay.queue_free()
