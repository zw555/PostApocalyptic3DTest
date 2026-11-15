extends SceneTree
const Layout = preload("res://scripts/cad/store_layout_data.gd")
var records: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func counts(node: Node) -> Dictionary:
	var result := {"nodes":1,"mesh_instances":int(node is MeshInstance3D),"multimesh_nodes":int(node is MultiMeshInstance3D),"rendered_product_instances":0,"legacy_products":int(str(node.name).begins_with("Stock_") or str(node.name).begins_with("ColdStock"))}
	if node is MultiMeshInstance3D and node.is_visible_in_tree():
		result.rendered_product_instances = node.multimesh.instance_count
	for child in node.get_children():
		var found := counts(child)
		for key in result:
			result[key] += found[key]
	return result

func take(game: Node3D, label: String) -> void:
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/cad/%s.png"%label)
	var camera: Camera3D = game.get_node("Camera3D")
	print("CAPTURE ",label)
	var record := {"file":label+".png","camera_mode":camera.mode,"size":camera.size,"focus":camera.focus,"player_position":game.get_node("Player").position,"zoom":camera.get_zoom_multiplier()}
	records.append(record)

func benchmark(game: Node3D, label: String) -> Dictionary:
	var windows: Array[Dictionary] = []
	for run_index in 3:
		var times: Array[float] = []
		var previous := Time.get_ticks_usec()
		for frame_index in 600:
			await process_frame
			var now := Time.get_ticks_usec()
			times.append(float(now-previous)/1000.0)
			previous = now
		times.sort()
		var total := 0.0
		for value in times:
			total += value
		windows.append({"frames":600,"mean_ms":total/600,"p50_ms":times[300],"p95_ms":times[570],"fps_from_mean":600000.0/total,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	return {"scene":label,"counts":counts(game),"windows":windows}

func configure(game: Node3D) -> Camera3D:
	game.get_node("Player").controls_enabled = false
	game.get_node("Player").position = Vector3(0,0,2.3)
	game.get_node("Player/Visual").set_process(false)
	game.get_node("Player/Visual").pose_at(0.0,0.0)
	game.get_node("Player/Visual").rotation.y = deg_to_rad(145)
	var camera: Camera3D = game.get_node("Camera3D")
	camera.reset_follow()
	camera.follow_enabled = false
	camera.set_process(false)
	camera.set_mode(2)
	game.set_local_lights(true)
	game.set_shadows(true)
	return camera

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native display required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://screenshots/cad")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1440,1000)
	var performance: Array[Dictionary] = []
	for variant in ["original","cad"]:
		var path := "res://scenes/main.tscn" if variant == "original" else "res://scenes/cad_convenience_store.tscn"
		var game: Node3D = load(path).instantiate()
		root.add_child(game)
		await process_frame
		var camera := configure(game)
		for i in 240:
			await process_frame
		performance.append(await benchmark(game,variant))
		await take(game,variant+"_65")
		if variant == "cad":
			game.get_node("ConvenienceStore/GroupedProducts").visible = false
			await take(game,"cad_stock_hidden")
			game.get_node("ConvenienceStore/GroupedProducts").visible = true
			camera.set_mode(1)
			await take(game,"cad_85")
			# Explicit overview adaptation: same camera, centre focus, size 15m.
			camera.focus = Vector3(0,0.75,0)
			camera.size = 15.0
			camera.target_size = 15.0
			camera.apply_pose()
			await take(game,"cad_overview")
			camera.set_mode(2)
			game.get_node("Player").position = Vector3(-1.05,0,0.1)
			camera.reset_follow()
			camera.size = camera.default_size*camera.closest_size_ratio
			camera.target_size = camera.size
			await take(game,"cad_character_close")
		game.queue_free()
		await process_frame
	var file := FileAccess.open("res://tests/results/cad_render_comparison.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"resolution":"1440x1000","renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"conditions":"same camera/controller, common player pose, size 13.8, identical light transforms/energies, local lights and shadows ON, vsync off, 240-frame warmup then 3x600 frames each","performance":performance,"screenshots":records},"\t"))
	file.close()
	quit()
