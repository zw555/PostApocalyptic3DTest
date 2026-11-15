extends SceneTree
var shots: Array[Dictionary] = []
var metrics: Array[Dictionary] = []
var common_pose := Vector3(-3.15,0,1.25)

func _initialize() -> void:
	call_deferred("run")

func take(game: Node3D, name_value: String) -> void:
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://screenshots/loot/%s.png"%name_value)
	var camera: Camera3D = game.get_node("Camera3D")
	shots.append({"file":name_value+".png","size":camera.size,"mode":camera.mode,"focus":str(camera.focus),"player_position":str(game.get_node("Player").position),"camera_transform":str(camera.global_transform),"lights":true,"shadows":true})
	print("CAPTURE ",name_value)

func count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += count_nodes(child)
	return total

func count_visible_products(node: Node) -> int:
	var total := 0
	if node is MultiMeshInstance3D and node.is_visible_in_tree():
		total += node.multimesh.instance_count
	for child in node.get_children():
		total += count_visible_products(child)
	return total

func benchmark(game: Node3D, stage: String) -> void:
	var windows: Array[Dictionary] = []
	for window in 3:
		var times: Array[float] = []
		var last := Time.get_ticks_usec()
		for i in 600:
			await process_frame
			var now := Time.get_ticks_usec()
			times.append((now-last)/1000.0)
			last = now
		times.sort()
		var total := 0.0
		for t in times:
			total += t
		windows.append({"frames":600,"mean_ms":total/600,"p50_ms":times[300],"p95_ms":times[570],"fps_from_mean":600000.0/total,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	var camera: Camera3D = game.get_node("Camera3D")
	metrics.append({"stage":stage,"windows":windows,"scene_nodes":count_nodes(game),"visible_products":count_visible_products(game),"camera_size":camera.size,"camera_transform":str(camera.global_transform),"player_position":str(game.get_node("Player").position),"search_ui_open":game.search_panel.visible if game.has_node("LootDisplay") else false})

func configure(game: Node3D) -> Camera3D:
	var player: CharacterBody3D = game.get_node("Player")
	player.controls_enabled = false
	player.position = common_pose
	player.get_node("Visual").set_process(false)
	player.get_node("Visual").pose_at(0.0,0.0)
	player.get_node("Visual").rotation.y = deg_to_rad(145)
	var camera: Camera3D = game.get_node("Camera3D")
	camera.reset_follow()
	camera.follow_enabled = false
	camera.set_process(false)
	camera.size = camera.default_size
	camera.target_size = camera.default_size
	camera.set_mode(2)
	game.set_local_lights(true)
	game.set_shadows(true)
	return camera

func gallery() -> void:
	var scene := Node3D.new()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.25
	scene.add_child(camera)
	camera.current = true
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("243237")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("b4c8d1")
	world.environment.ambient_light_energy = 0.7
	scene.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-25,0)
	light.light_energy = 0.75
	light.shadow_enabled = true
	scene.add_child(light)
	var m = load("res://scripts/procedural/mesh_factory.gd")
	m.box(scene,"Floor",Vector3(1.6,0.025,0.8),Vector3(0,-0.0125,0),"shelf_back")
	for kind in 3:
		var model := MeshInstance3D.new()
		model.mesh = load("res://scenes/props/loot/sku_%d_0.res"%kind)
		scene.add_child(model)
		model.position.x = (kind-1)*0.35
	root.add_child(scene)
	camera.global_position = Vector3(0,0.12,0)+Vector3(0,sin(deg_to_rad(65)),cos(deg_to_rad(65)))*2.5
	camera.look_at(Vector3(0,0.12,0),Vector3.UP)
	for i in 100:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/loot/product_prototypes.png")
	scene.queue_free()
	await process_frame

func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://screenshots/loot")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1440,1000)
	var baseline: Node3D = load("res://scenes/cad_convenience_store.tscn").instantiate()
	root.add_child(baseline)
	await process_frame
	configure(baseline)
	for i in 240:
		await process_frame
	await benchmark(baseline,"stage_4a")
	await take(baseline,"stage_4a_cad_65")
	baseline.queue_free()
	await process_frame
	var game: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var camera := configure(game)
	for i in 240:
		await process_frame
	await benchmark(game,"stage_4b_partial")
	await take(game,"partially_looted_65")
	game.get_node("Player").position = Vector3(0,0,2.3)
	camera.reset_follow()
	await take(game,"partially_looted_overview")
	configure(game)
	camera.set_mode(1)
	await take(game,"partially_looted_85")
	camera.set_mode(2)
	camera.size = camera.default_size*camera.closest_size_ratio
	camera.target_size = camera.size
	await take(game,"products_close_65")
	camera.set_mode(1)
	await take(game,"products_close_85")
	camera.set_mode(2)
	# A diagnostic side pose only; existing player camera controller is untouched.
	var focus: Vector3 = game.get_node("ConvenienceStore/Furniture/Gondola2").position+Vector3(0,0.75,0)
	camera.global_position = focus+Vector3(22.0*cos(deg_to_rad(65.0)),22.0*sin(deg_to_rad(65.0)),0)
	camera.look_at(focus,Vector3.UP)
	await take(game,"shelf_side_diagnostic")
	configure(game)
	game.open_search_panel()
	await take(game,"search_before")
	game.close_search_panel()
	await benchmark(game,"search_before")
	# Use the actual UI Button signal for the single-water claim.
	game.open_search_panel()
	camera.size = camera.default_size*camera.closest_size_ratio
	camera.target_size = camera.size
	await take(game,"search_before_close")
	game.search_panel.find_child("Take_water",true,false).pressed.emit()
	var first_removed: Array = game.loot.last_removed_ids.duplicate()
	await take(game,"search_after_one_water_close")
	camera.size = camera.default_size
	camera.target_size = camera.size
	await take(game,"search_after_one_water")
	game.take_all_button.pressed.emit()
	await take(game,"search_after_all")
	game.close_search_panel()
	await benchmark(game,"search_after")
	await take(game,"after_claim_scene")
	var evidence := {"first_water_slot":first_removed,"removed_slot_ids":first_removed+game.loot.last_removed_ids,"supplies":game.loot.player_supplies.duplicate(true),"state":game.loot.state.container.search_state,"remaining":game.loot.state.remaining(),"visible_products":game.loot.visible_products()}
	var file := FileAccess.open("res://tests/results/loot_render_comparison.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"resolution":"1440x1000","renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"conditions":"common character pose and fixed 65-degree orthographic size 13.8; original lights/shadows ON; UI closed during timings; vsync off, 240-frame warmup, three 600-frame windows per stage","metrics":metrics,"screenshots":shots,"claim_evidence":evidence},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	await gallery()
	quit()
