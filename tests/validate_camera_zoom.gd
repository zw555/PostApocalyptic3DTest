extends SceneTree
var results: Array[Dictionary] = []
var game: Node3D
var camera: Camera3D

func _initialize() -> void:
	call_deferred("run")

func check(label: String, ok: bool) -> void:
	results.append({"test": label, "passed": ok})
	print("%s %s" % ["PASS" if ok else "FAIL", label])

func wheel(button: MouseButton, factor: float = 1.0, pressed: bool = true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.factor = factor
	event.pressed = pressed
	event.position = Vector2(700, 400)
	event.global_position = event.position
	return event

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func smooth(seconds: float = 2.0, fps: int = 60) -> void:
	for i in int(seconds * fps):
		camera._process(1.0 / fps)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	camera = game.get_node("Camera3D")
	camera.set_process(false)
	camera.follow_enabled = false
	var player: CharacterBody3D = game.get_node("Player")
	player.controls_enabled = false
	var body_before := player.transform
	var capsule_before: Transform3D = player.get_node("CollisionShape3D").transform
	var focus_before: Vector3 = camera.focus
	var pose_before := camera.global_transform
	var fov_before := camera.fov
	check("Default orthographic size is 13.8", camera.projection == Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(camera.default_size, 13.8) and is_equal_approx(camera.size, camera.default_size) and is_equal_approx(camera.target_size, camera.default_size))
	camera._unhandled_input(wheel(MOUSE_BUTTON_WHEEL_UP))
	check("Wheel up divides target by 1.1 without snapping", is_equal_approx(camera.target_size, camera.default_size / 1.1) and is_equal_approx(camera.size, camera.default_size))
	camera._process(1.0 / 60.0)
	check("Zoom eases toward the target", camera.size < camera.default_size and camera.size > camera.target_size)
	camera._unhandled_input(wheel(MOUSE_BUTTON_WHEEL_DOWN))
	check("Opposite wheel restores target proportionally", is_equal_approx(camera.target_size, camera.default_size))
	var minimum: float = camera.default_size * camera.closest_size_ratio
	var maximum: float = camera.default_size * camera.farthest_size_ratio
	for i in 1000:
		camera._unhandled_input(wheel(MOUSE_BUTTON_WHEEL_UP))
	smooth()
	check("Rapid zoom in clamps at default x 0.6", is_equal_approx(camera.target_size, minimum) and is_equal_approx(camera.size, minimum))
	check("HUD multiplier grows when zooming in", is_equal_approx(camera.get_zoom_multiplier(), 1.0 / 0.6))
	for i in 1000:
		camera._unhandled_input(wheel(MOUSE_BUTTON_WHEEL_DOWN))
	smooth()
	check("Rapid zoom out clamps at default x 1.8", is_equal_approx(camera.target_size, maximum) and is_equal_approx(camera.size, maximum))
	var finite := true
	for i in 2000:
		camera._unhandled_input(wheel(MOUSE_BUTTON_WHEEL_UP if i % 2 == 0 else MOUSE_BUTTON_WHEEL_DOWN, 1000000.0))
		camera._process(1.0 / 240.0)
		finite = finite and is_finite(camera.size) and is_finite(camera.target_size) and camera.target_size >= minimum and camera.target_size <= maximum
	check("Rapid high-factor scrolling stays finite and bounded", finite)
	var target_before: float = camera.target_size
	camera._unhandled_input(wheel(MOUSE_BUTTON_WHEEL_UP, NAN))
	camera._unhandled_input(wheel(MOUSE_BUTTON_WHEEL_UP, INF))
	camera._unhandled_input(wheel(MOUSE_BUTTON_WHEEL_UP, 1.0, false))
	camera._unhandled_input(wheel(MOUSE_BUTTON_WHEEL_LEFT))
	check("Invalid factors, release and horizontal scroll are ignored", camera.target_size == target_before)
	camera.size = camera.default_size
	camera.target_size = minimum
	smooth(0.5, 30)
	var at_30: float = camera.size
	camera.size = camera.default_size
	smooth(0.5, 144)
	check("30 and 144 FPS smoothing match at equal elapsed time", absf(camera.size - at_30) < 0.00005)
	var size_before: float = camera.size
	target_before = camera.target_size
	var modes_preserved := true
	for mode_key in [KEY_F1, KEY_F2]:
		game._unhandled_key_input(key(mode_key))
		modes_preserved = modes_preserved and camera.size == size_before and camera.target_size == target_before
	check("F1/F2 preserve both current size and zoom target", modes_preserved and camera.mode == 2)
	check("Zoom changes no focus/pose/FOV/body/collision", camera.focus == focus_before and camera.global_transform.is_equal_approx(pose_before) and camera.fov == fov_before and player.transform == body_before and player.get_node("CollisionShape3D").transform == capsule_before)
	camera._unhandled_input(key(KEY_HOME))
	check("Home targets startup default", camera.target_size == camera.default_size)
	smooth()
	check("Home smoothly restores 1.0x", is_equal_approx(camera.size, camera.default_size) and is_equal_approx(camera.get_zoom_multiplier(), 1.0))
	game._process(0.0)
	check("Debug HUD shows actual zoom multiplier", game.status.text.contains("ZOOM 1.0×"))
	# Exercise real Viewport dispatch so GUI consumption is tested, not assumed.
	var overlay := CanvasLayer.new()
	overlay.layer = 50
	var menu := Control.new()
	menu.position = Vector2(600, 300)
	menu.size = Vector2(300, 300)
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	var gui_events := [0]
	menu.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			gui_events[0] += 1
			menu.accept_event()
	)
	root.add_child(overlay)
	overlay.add_child(menu)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(700,400)
	motion.global_position = motion.position
	root.push_input(motion, true)
	target_before = camera.target_size
	root.push_input(wheel(MOUSE_BUTTON_WHEEL_UP), true)
	check("GUI-consumed wheel does not zoom camera", gui_events[0] == 1 and camera.target_size == target_before)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.push_input(motion, true)
	root.push_input(wheel(MOUSE_BUTTON_WHEEL_UP), true)
	check("Unhandled Viewport wheel reaches camera", camera.target_size < target_before)
	root.push_input(key(KEY_HOME), true)
	check("Unhandled Viewport Home resets zoom", camera.target_size == camera.default_size)
	overlay.queue_free()
	# A non-default zoom must leave the existing following calculation intact.
	camera._unhandled_input(wheel(MOUSE_BUTTON_WHEEL_UP))
	size_before = camera.size
	camera.follow_enabled = true
	player.position.x += 1.0
	camera._process(1.0 / 60.0)
	check("Following remains smooth while zoom is active", camera.focus.x > focus_before.x and camera.focus.x < focus_before.x + 1.0 and camera.size < size_before and camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
	var configured := Camera3D.new()
	configured.set_script(camera.get_script())
	configured.view_size = 20.0
	root.add_child(configured)
	for i in 100:
		configured._unhandled_input(wheel(MOUSE_BUTTON_WHEEL_DOWN))
	check("Bounds follow configured startup size rather than hardcoded 13.8", configured.default_size == 20.0 and is_equal_approx(configured.target_size, 36.0))
	configured.queue_free()
	camera.make_current()
	var failed := results.filter(func(r): return not r.passed).size()
	var file := FileAccess.open("res://tests/results/camera_zoom_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": results.size() - failed, "failed": failed, "default_size": camera.default_size, "min_size": minimum, "max_size": maximum, "manual_acceptance": "PENDING: no human interaction or rendering-quality acceptance performed.", "tests": results}, "\t"))
	file.close()
	game.queue_free()
	await process_frame
	print("ZOOM: %d passed, %d failed" % [results.size() - failed, failed])
	quit(0 if failed == 0 else 1)
