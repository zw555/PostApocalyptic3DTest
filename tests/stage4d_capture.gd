extends "res://tests/stage4c_capture.gd"
var update_times: Array[int] = []

func take(game: Node3D, name_value: String) -> void:
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/stage4d/%s.png"%name_value)
	print("CAPTURE ",name_value)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage4d")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1440,1000)
	var game: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var camera := configure(game)
	game.player.visual.rotation.y = -PI/2
	for i in 240:
		await process_frame
	await benchmark(game,"store_before")
	await take(game,"shelf02_before_default")
	camera.size = 8.28
	camera.target_size = camera.size
	await take(game,"shelf02_before")
	game.open_search_panel()
	await take(game,"shelf02_panel")
	await click_button(game.search_panel.find_child("Take_water",true,false))
	await take(game,"shelf02_after_one")
	await click_button(game.take_all_button)
	update_times.append(game.loot.last_update_usec)
	var shelf02: Dictionary = game.loot.Catalog.statistics(game.loot.state.container)
	await take(game,"shelf02_empty_panel")
	game.close_search_panel()
	await take(game,"shelf02_after_all")
	await take(game,"damaged_close_65")
	camera.set_mode(1)
	await take(game,"damaged_close_85")
	configure(game)
	game.player.visual.rotation.y = -PI/2
	await benchmark(game,"after_shelf02")
	var approaches: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/stage4d_validation.json")).approaches
	var cold_id := "cad/NorthFreezer2"
	var pos: Array = approaches[cold_id]
	game.player.position = Vector3(pos[0],pos[1],pos[2])
	game.player.visual.look_at(Vector3(-3.204,0,-3.728),Vector3.UP)
	await physics_frame
	camera.reset_follow()
	# Keep the freezer and its contents above the bottom UI, diagnostic framing only.
	camera.focus = Vector3(0,0.75,0)
	camera.global_position = camera.focus+Vector3(0,sin(deg_to_rad(65)),cos(deg_to_rad(65)))*22.0
	camera.look_at(camera.focus,Vector3.UP)
	game.open_search_panel()
	await take(game,"freezer_panel")
	game.close_search_panel()
	var per_container: Dictionary = {}
	for id in game.loot.states:
		var approach: Array = approaches[id]
		game.player.position = Vector3(approach[0],approach[1],approach[2])
		await physics_frame
		game.loot.search(game.player.position,id)
		var requests: Dictionary = game.loot.state.all_requests()
		if not requests.is_empty():
			var response: Dictionary = game.loot.take(game.player.position,requests)
			if not response.ok:
				push_error(str(response))
				quit(1)
				return
			update_times.append(game.loot.last_update_usec)
		per_container[id] = game.loot.Catalog.statistics(game.loot.state.container)
	configure(game)
	game.player.visual.rotation.y = -PI/2
	await benchmark(game,"store_depleted")
	game.player.position = Vector3(0,0,2.3)
	camera.reset_follow()
	await take(game,"store_depleted_65")
	camera.set_mode(1)
	await take(game,"store_depleted_85")
	var record := {"metrics":metrics,"update_usec":update_times,"shelf02_after":shelf02,"all_after":per_container,"supplies":game.loot.player_supplies,"resolution":"1440x1000","renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"manual_acceptance":"PENDING"}
	var file := FileAccess.open("res://tests/results/stage4d_render.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(record,"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit()
