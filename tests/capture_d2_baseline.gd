extends "res://tests/loot_capture.gd"
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1440,1000)
	var game: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var camera := configure(game)
	game.player.visual.rotation.y = -PI/2
	game.open_search_panel()
	game.take_all()
	game.close_search_panel()
	camera.size = 8.28
	camera.target_size = 8.28
	for i in 240:
		await process_frame
	await benchmark(game,"before_near02_depleted")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/baseline_stage4d2/near_before.png")
	var file := FileAccess.open("res://tests/baseline_stage4d2/performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"metrics":metrics,"adapter":RenderingServer.get_video_adapter_name(),"resolution":"1440x1000","meaning":"Same near 65-degree shelf02 depleted state as the screenshot displaying about 54 FPS; actual multi-window timing."},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit()

