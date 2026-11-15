extends "res://tests/loot_capture.gd"

func shot(name_value: String) -> void:
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/stage4d2/"+name_value+".png")
	print("CAPTURE ",name_value)

func frame_at(camera: Camera3D, focus: Vector3, size_value: float, angle: float = 65.0) -> void:
	camera.size = size_value
	camera.target_size = size_value
	camera.global_position = focus+Vector3(0,sin(deg_to_rad(angle)),cos(deg_to_rad(angle)))*22
	camera.look_at(focus,Vector3.UP)

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1440,1000)
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage4d2")
	var game: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var camera := configure(game)
	game.player.visual.rotation.y = -PI/2
	game.open_search_panel()
	game.take_all()
	game.close_search_panel()
	camera.size = 8.28
	camera.target_size = camera.size
	for i in 600:
		await process_frame
	await benchmark(game,"localized_near02_depleted")
	await shot("performance_near02")
	# Fresh runtime for unclaimed overview; no inventory/config changes for screenshots.
	game.queue_free()
	await process_frame
	game = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await process_frame
	camera = configure(game)
	game.player.position = Vector3(0,0,2.3)
	game.player.visual.rotation.y = -PI/2
	camera.reset_follow()
	await shot("store65")
	camera.set_mode(1)
	await shot("store85")
	camera.set_mode(2)
	frame_at(camera,Vector3(-0.5,2.35,-3.8),5.0)
	await shot("shop_sign")
	frame_at(camera,Vector3(3.0,1.20,-2.35),3.3)
	await shot("checkout_close")
	frame_at(camera,Vector3(3.25,0.95,-3.825),2.5)
	await shot("sink_close")
	game.player.position = common_pose
	game.player.visual.rotation.y = -PI/2
	camera.reset_follow()
	camera.size = 13.8
	camera.target_size = 13.8
	await shot("amber_highlight")
	camera.size = 8.28
	camera.target_size = 8.28
	await shot("products_game_near")
	var file := FileAccess.open("res://tests/results/stage4d2_render.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"metrics":metrics,"resolution":"1440x1000","adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"manual_acceptance":"PENDING"},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	await product_gallery()
	quit()

func product_gallery() -> void:
	var stage := Node3D.new()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.35
	stage.add_child(camera)
	camera.current = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("354340")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_energy = 0.8
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-25,0)
	stage.add_child(light)
	var library = load("res://scripts/loot/store_product_visuals.gd").new()
	var types := ["water","drink","boxed_food","canned_food"]
	for i in 4:
		var mesh := MeshInstance3D.new()
		mesh.mesh = library.mesh_for(types[i]+"_0_AVAILABLE")
		mesh.position.x = (i-1.5)*0.36
		stage.add_child(mesh)
	root.add_child(stage)
	camera.position = Vector3(0,2.12,0.94)
	camera.look_at(Vector3(0,0.12,0),Vector3.UP)
	await shot("four_chinese_products")
	for i in 4:
		for child in stage.get_children():
			if child is MeshInstance3D:
				child.visible = is_equal_approx(child.position.x,(i-1.5)*0.36)
		camera.size = 0.6
		var focus := Vector3((i-1.5)*0.36,0.13,0)
		camera.global_position = focus+Vector3(0,sin(deg_to_rad(35)),cos(deg_to_rad(35)))*2.5
		camera.look_at(focus,Vector3.UP)
		await shot("product_"+types[i])
	stage.queue_free()
	await process_frame
