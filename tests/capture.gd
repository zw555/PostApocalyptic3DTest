extends SceneTree
## Native viewport capture from the actual running scene (not a mockup).
var game: Node3D
var metrics: Array[Dictionary] = []
func _initialize() -> void:
	call_deferred("run")

func take(file: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png("res://screenshots/" + file)
	metrics.append({"file": file, "fps_display": Engine.get_frames_per_second(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "rendered_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	print("CAPTURE %s: %s" % [file, error_string(result)])

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a GPU display, omit --headless.")
		quit(1)
		return
	root.size = Vector2i(1440, 1000)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.get_node("Player").controls_enabled = false
	var camera: Camera3D = game.get_node("Camera3D")
	camera.reset_follow()
	camera.follow_enabled = false
	# Warm up shaders and let the FPS average exclude scene startup.
	for i in 180:
		await process_frame
	camera.set_mode(1)
	await take("01_ortho_85.png")
	camera.set_mode(2)
	await take("02_ortho_65.png")
	game.set_local_lights(true)
	game.set_shadows(true)
	await take("03_lights_shadows_on.png")
	game.set_shadows(false)
	await take("04_dynamic_shadows_off.png")
	game.set_shadows(true)
	game.set_local_lights(false)
	await take("05_local_lights_off.png")
	game.set_local_lights(true)
	game.get_node("Player").position = Vector3(-2.2, 0, -2.65)
	await take("06_occlusion_behind_shelf.png")
	game.get_node("Player").position = Vector3(-2.2, 0, -0.95)
	await take("07_occlusion_in_front.png")
	var file := FileAccess.open("res://tests/results/render_metrics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "note": "Short, warmed native screenshot run; not a sustained gameplay benchmark.", "captures": metrics}, "\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit()
