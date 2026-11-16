extends SceneTree

func distance(a: Array,b: Array) -> float:
	return maxf(absf(a[0]-b[0]),maxf(absf(a[1]-b[1]),absf(a[2]-b[2])))

func _initialize() -> void:
	call_deferred("run")

func sample(image: Image,pixel: Vector2) -> Array:
	var c := image.get_pixelv(Vector2i(pixel))
	return [c.r,c.g,c.b]

func run() -> void:
	root.size = Vector2i(1440,1000)
	var game: Node3D = load("res://scenes/apartment/stage6a2c_floor5.tscn").instantiate()
	root.add_child(game)
	game.player.set_physics_process(false)
	game.player.position = Vector3(-3.95,0.02,0.02)
	game.camera.set_mode(6)
	game.camera.target_size = game.camera.active_base_size*1.3
	game.camera.size = game.camera.target_size
	game.camera.reset_follow()
	for i in 35: await physics_frame
	var near_pixel: Vector2 = game.camera.unproject_position(Vector3(-5.5,0.03,-0.45))
	var far_pixel: Vector2 = game.camera.unproject_position(Vector3(-5.5,0.03,6))
	var old_png := Image.load_from_file("res://screenshots/stage6a2c/before_aperture_open.png")
	var open_png := Image.load_from_file("res://screenshots/stage6a2c/after_aperture_open.png")
	var closed_png := Image.load_from_file("res://screenshots/stage6a2c/after_aperture_closed.png")
	var old := {"near":sample(old_png,near_pixel),"far":sample(old_png,far_pixel),"background":sample(old_png,Vector2(1400,20))}
	var opened := {"near":sample(open_png,near_pixel),"far":sample(open_png,far_pixel),"background":sample(open_png,Vector2(1400,20))}
	var closed := {"near":sample(closed_png,near_pixel)}
	var checks := [
		{"test":"Old always-expanded corridor is visible outside portal","passed":distance(old.far,old.background) > 0.04},
		{"test":"Corrected open door keeps far hall outside aperture hidden","passed":distance(opened.far,opened.background) < 0.01},
		{"test":"Corrected near aperture still draws actual hallway floor","passed":distance(opened.near,opened.background) > 0.04},
		{"test":"Closing and opening real leaf changes near aperture pixels","passed":distance(opened.near,closed.near) > 0.01}
	]
	var failed := 0
	for check in checks:
		print("PASS " if check.passed else "FAIL ",check.test)
		if not check.passed: failed += 1
	var output := FileAccess.open("res://tests/results/stage6a2c_pixel_validation.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":checks.size()-failed,"failed":failed,"checks":checks,"near_pixel":str(near_pixel),"far_pixel":str(far_pixel),"before":old,"opened":opened,"closed":closed,"source":"Actual Vulkan-captured pixels; not human acceptance"},"\t"))
	output.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
