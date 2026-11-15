extends "res://tests/stage4d1_capture.gd"
func run() -> void:
	root.size = Vector2i(1440,1000)
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage4d1")
	var game: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var camera := configure(game)
	game.player.position = Vector3(5.75,0.02,-2.125)
	for i in 600:
		await process_frame
	await shot("unselected_no_target")
	var unselected: bool = not game.loot.highlight.display.visible and game.loot.highlight.current_id.is_empty()
	game.player.position = common_pose
	game.player.visual.rotation.y = -PI/2
	camera.size = 24.84
	camera.target_size = 24.84
	await shot("selected_far")
	var record := {"unselected_has_no_target":unselected,"far_target":game.loot.highlight.current_id,"far_size":camera.size}
	var file := FileAccess.open("res://tests/results/stage4d1_extra_capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(record,"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit(0 if unselected else 1)
