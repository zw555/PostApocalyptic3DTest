extends "res://tests/loot_capture.gd"

func shot(name_value: String) -> void:
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/stage4d1/"+name_value+".png")
	print("CAPTURE ",name_value)

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1440,1000)
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage4d1")
	var game: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var camera := configure(game)
	game.player.visual.rotation.y = -PI/2
	# Let pipeline compilation and the HUD FPS interval settle before screenshots.
	for i in 600:
		await process_frame
	# Same content/camera with only the proxy hidden to illustrate an unselected shelf.
	await process_frame
	game.loot.highlight.hide()
	await shot("unselected")
	game.loot.highlight.show()
	await shot("selected_stocked")
	camera.size = 8.28
	camera.target_size = 8.28
	await shot("selected_near65")
	camera.set_mode(1)
	await shot("selected_near85")
	camera.set_mode(2)
	game.open_search_panel()
	await shot("loot_panel")
	game.take_all()
	game.close_search_panel()
	for i in 240:
		await process_frame
	await benchmark(game,"after_near02_depleted_highlight_on")
	await shot("depleted_near")
	game.loot.highlight.hide()
	await benchmark(game,"after_near02_depleted_highlight_off")
	game.loot.highlight.show()
	await benchmark(game,"after_near02_depleted_highlight_on_repeat")
	camera.size = 13.8
	camera.target_size = 13.8
	await shot("selected_depleted")
	game.player.position = Vector3(0,0,2.3)
	game.player.visual.rotation.y = -PI/2
	camera.reset_follow()
	await shot("scarce_store")
	var file := FileAccess.open("res://tests/results/stage4d1_render.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"metrics":metrics,"resolution":"1440x1000","adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"manual_acceptance":"PENDING"},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit()
