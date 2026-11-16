extends SceneTree
## Analyze actual captured PNGs, using the same camera to locate old shell pixels.
const P = preload("res://scripts/apartment/floor5_layout.gd")

func _initialize() -> void:
	call_deferred("run")

func error_at(picture: Image,pixel: Vector2,background: Color) -> float:
	var error := 0.0
	for x in range(-1,2):
		for y in range(-1,2):
			var c := picture.get_pixelv(Vector2i(pixel)+Vector2i(x,y))
			error += maxf(absf(c.r-background.r),maxf(absf(c.g-background.g),absf(c.b-background.b)))
	return error/9

func run() -> void:
	root.size = Vector2i(1440,1000)
	var game: Node3D = load("res://scenes/apartment/stage6a2b_regions_floor5.tscn").instantiate()
	root.add_child(game)
	game.player.set_physics_process(false)
	game.player.position = Vector3(-5.475,0.02,3.3)
	game.camera.set_mode(1)
	game.camera.target_size = game.camera.active_base_size*1.8
	game.camera.size = game.camera.target_size
	game.camera.reset_follow()
	for i in 35: await physics_frame
	var before := Image.load_from_file("res://screenshots/stage6a2b_regions/before_overview_F1.png")
	var after := Image.load_from_file("res://screenshots/stage6a2b_regions/after_overview_F1.png")
	var background := after.get_pixel(1400,40)
	var tests: Array = []
	for number in ["502","503","504"]:
		var bounds: Rect2 = P.ROOMS[number]
		var center := bounds.get_center()
		var points := {"floor":Vector3(center.x,0.03,center.y),"north":Vector3(center.x,2.62,bounds.position.y+0.075),"south":Vector3(center.x,2.62,bounds.end.y-0.075),"outer":Vector3(bounds.end.x-0.075 if number == "503" else bounds.position.x+0.075,2.62,center.y)}
		for label in points:
			var pixel: Vector2 = game.camera.unproject_position(points[label])
			var old_error := error_at(before,pixel,background)
			var new_error := error_at(after,pixel,background)
			var passed := new_error < 0.015 and old_error > 0.05
			tests.append({"test":number+" "+label+" no longer draws an empty-box surface","passed":passed,"pixel":str(pixel),"before_background_error":old_error,"after_background_error":new_error})
			print("PASS " if passed else "FAIL ",tests.back().test," ",old_error," -> ",new_error)
	var failed := tests.filter(func(t): return not t.passed).size()
	var output := FileAccess.open("res://tests/results/stage6a2b_regions_pixel_validation.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":tests.size()-failed,"failed":failed,"tests":tests,"source":"Actual Godot before/after PNGs; headless projection/pixel analysis only","human_acceptance":"PENDING"},"\t"))
	output.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
