extends SceneTree
## Round-two comparison: unchanged actual game camera, deterministic pose.
var game: Node3D
var stage := "before"
var variant := "final"
var window_frames := 180
var samples: Array[Dictionary] = []
var conditions: Dictionary

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("stage="):
			stage = arg.trim_prefix("stage=")
		if arg.begins_with("variant="):
			variant = arg.trim_prefix("variant=")
		if arg.begins_with("frames="):
			window_frames = int(arg.trim_prefix("frames="))
	call_deferred("run")

func freeze_pose(speed: float = 0.0, phase: float = 0.0) -> void:
	var visual := game.get_node("Player/Visual")
	visual.rotation.y = deg_to_rad(145.0)
	if visual.has_method("pose_at"):
		visual.set_process(false)
		visual.pose_at(phase, speed)

func take(name_value: String) -> void:
	for i in 16:
		await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var result := frame.save_png("res://screenshots/round2/%s_%s.png" % [stage, name_value])
	if result != OK:
		push_error("Capture failed")
	# Pixel crop from the same game render, with no second camera or zoom.
	if name_value in ["65", "85", "walk"]:
		var point: Vector2 = game.get_node("Camera3D").unproject_position(game.get_node("Player").position + Vector3(0, 0.8, 0))
		var rect := Rect2i(Vector2i(point) - Vector2i(110, 115), Vector2i(220, 230))
		frame.get_region(rect).save_png("res://screenshots/round2/%s_%s_character_crop.png" % [stage, name_value])
	print("CAPTURE %s %s" % [stage, name_value])

func benchmark() -> void:
	for window in 3:
		var times: Array[float] = []
		var previous := Time.get_ticks_usec()
		for i in window_frames:
			await process_frame
			var now := Time.get_ticks_usec()
			times.append(float(now - previous) / 1000.0)
			previous = now
		times.sort()
		var total := 0.0
		for value in times:
			total += value
		samples.append({"window": window + 1, "frames": times.size(), "mean_ms": total / times.size(), "p50_ms": times[times.size() / 2], "p95_ms": times[int(times.size() * 0.95)], "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native GPU display required")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute("res://screenshots/round2")
	root.size = Vector2i(1440, 1000)
	game = load("res://scenes/main.tscn").instantiate()
	if variant in ["baseline", "character"]:
		var story := game.get_node("EnvironmentStory")
		game.remove_child(story)
		story.free()
	if variant == "baseline":
		var upgraded_player := game.get_node("Player")
		var at: Transform3D = upgraded_player.transform
		game.remove_child(upgraded_player)
		upgraded_player.free()
		var legacy: Node3D = load("res://scenes/player/player.tscn").instantiate()
		legacy.name = "Player"
		legacy.transform = at
		game.add_child(legacy)
	if variant == "environment":
		game.get_node("EnvironmentStory").finish_enabled = false
	root.add_child(game)
	current_scene = game
	await process_frame
	var player: CharacterBody3D = game.get_node("Player")
	player.controls_enabled = false
	player.position = Vector3(0, 0, 2.3)
	player.velocity = Vector3.ZERO
	var camera: Camera3D = game.get_node("Camera3D")
	camera.reset_follow()
	camera.follow_enabled = false
	camera.set_mode(2)
	freeze_pose()
	game.set_local_lights(true)
	game.set_shadows(true)
	var light_config: Array[Dictionary] = []
	for light in get_nodes_in_group("shadow_lights"):
		light_config.append({"name": str(light.name), "energy": light.light_energy, "color": str(light.light_color), "transform": str(light.global_transform), "shadow": light.shadow_enabled})
	conditions = {"resolution": "1440x1000", "camera_size": camera.size, "camera_65_transform": str(camera.global_transform), "player_position": str(player.position), "visual_yaw": 145.0, "local_lights": true, "shadows": true, "lights": light_config, "environment_energy": game.get_node("WorldEnvironment").environment.ambient_light_energy}
	for i in 240:
		await process_frame
	await benchmark()
	await take("65")
	camera.set_mode(1)
	await take("85")
	camera.set_mode(2)
	if variant != "baseline":
		freeze_pose(3.2, 1.15)
		await take("walk")
		freeze_pose()
		player.position = Vector3(-2.2, 0, -2.65)
		await take("behind_shelf")
		player.position = Vector3(-2.2, 0, -0.95)
		await take("front_shelf")
	var file := FileAccess.open("res://tests/results/round2_%s_render.json" % stage, FileAccess.WRITE)
	file.store_string(JSON.stringify({"stage": stage, "variant": variant, "adapter": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(), "conditions": conditions, "windows": samples, "note": "Three warm %d-frame windows, vsync off. Frame timings include CPU/GPU scheduling; not a cross-hardware benchmark." % window_frames}, "\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit()
