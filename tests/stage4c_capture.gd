extends "res://tests/loot_capture.gd"

func take(game: Node3D, name_value: String) -> void:
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/stage4c/%s.png"%name_value)
	print("CAPTURE ",name_value)

func click_button(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	for pressed_value in [true,false]:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.position = point
		mouse.pressed = pressed_value
		root.push_input(mouse,true)
		await process_frame

func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage4c")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1440,1000)
	# Replay preserved 4-B UI/detection in this same engine process and hardware session.
	var baseline: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	baseline.set_script(load("res://tests/baseline_stage4c/scripts_loot_loot_main.gd"))
	baseline.get_node("LootDisplay").set_script(load("res://tests/baseline_stage4c/scripts_loot_loot_display_manager.gd"))
	root.add_child(baseline)
	await process_frame
	configure(baseline)
	for i in 240:
		await process_frame
	await benchmark(baseline,"stage4b_replayed_closed")
	baseline.queue_free()
	await process_frame
	var game: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var camera := configure(game)
	for i in 240:
		await process_frame
	await benchmark(game,"stage4c_before_closed")
	await take(game,"interaction_hint")
	game.open_search_panel()
	await take(game,"search_panel")
	camera.size = camera.default_size*camera.closest_size_ratio
	camera.target_size = camera.size
	await take(game,"shelf_before")
	await click_button(game.search_panel.find_child("Take_water",true,false))
	await take(game,"shelf_after_one_water")
	var first: Array = game.loot.last_removed_ids.duplicate()
	await click_button(game.take_all_button)
	await take(game,"player_inventory")
	camera.size = camera.default_size
	camera.target_size = camera.size
	await benchmark(game,"stage4c_panel_open")
	game.close_search_panel()
	await benchmark(game,"stage4c_after_closed")
	await take(game,"shelf_after_all")
	var evidence := {"supplies":game.loot.player_supplies.duplicate(),"remaining":game.loot.state.remaining(),"state":game.loot.state.container.search_state,"removed_ids":first+game.loot.last_removed_ids,"visible":game.loot.visible_products()}
	var record := {"resolution":"1440x1000","adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"metrics":metrics,"evidence":evidence,"input":"Actual viewport mouse press/release on Take_water and Take_all buttons","manual_acceptance":"PENDING"}
	var file := FileAccess.open("res://tests/results/stage4c_render.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(record,"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit(0 if int(evidence.supplies.get("water",0)) == 2 and evidence.remaining == 0 else 1)
