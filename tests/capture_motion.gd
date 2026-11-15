extends SceneTree
## Native actual-input animation evidence. Run with --fixed-fps 30, no headless.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1440,1000)
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var player: CharacterBody3D = game.get_node("Player")
	var camera: Camera3D = game.get_node("Camera3D")
	camera.set_mode(2)
	for i in 90:
		await process_frame
	for state in ["idle", "walk"]:
		DirAccess.make_dir_recursive_absolute("res://screenshots/round2/motion/" + state)
		if state == "walk":
			Input.action_press("move_right")
		for i in 36:
			await process_frame
			await RenderingServer.frame_post_draw
			var point := camera.unproject_position(player.position + Vector3(0,0.8,0))
			var rect := Rect2i(Vector2i(point)-Vector2i(160,160),Vector2i(320,320))
			root.get_texture().get_image().get_region(rect).save_png("res://screenshots/round2/motion/%s/%02d.png" % [state,i])
		Input.action_release("move_right")
	print("MOTION CAPTURE: actual WASD action, final X=", player.position.x)
	game.queue_free()
	await process_frame
	quit()
