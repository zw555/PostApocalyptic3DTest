extends "res://tests/loot_capture.gd"

func run() -> void:
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/baseline_stage5a/manifest.json"))
	for entry in manifest:
		if entry.path == "scripts/camera_controller.gd" and FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper():
			printerr("Pre-implementation baseline is immutable. Use stage5a_capture.gd for paired feature-off/on measurements.")
			quit(2)
			return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1440,1000)
	var game: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var camera := configure(game)
	game.player.visual.rotation.y = -PI/2
	for zone in ["clear", "shelf"]:
		game.player.position = Vector3(-1.05,0,0) if zone == "clear" else Vector3(-2.1,0,-2.25)
		camera.set_mode(6)
		camera.size = 13.8
		camera.target_size = 13.8
		camera.reset_follow()
		for i in 180:
			await process_frame
		await benchmark(game,zone)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://screenshots/stage5a/baseline_"+zone+".png")
	var file := FileAccess.open("res://tests/results/stage5a_baseline.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"metrics":metrics,"resolution":str(root.size),"vsync":false,"source":"before Stage 5-A implementation"},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit()
