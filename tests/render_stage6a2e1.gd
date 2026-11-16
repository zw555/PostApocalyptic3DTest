extends "res://tests/capture_stage6a2e1.gd"
var rendered_rows: Array = []
var raster_checks: Array = []

func test_result(label: String,passed: bool) -> void:
	raster_checks.append({"test":label,"passed":passed})
	print("PASS " if passed else "FAIL ",label)

func neighbor_pixels(at: Vector3,label: String,angle: float) -> int:
	game.player.position = at
	game.player.velocity = Vector3.ZERO
	var door: Node3D = game.get_node("Apartment/Architecture/EntryDoor")
	door.rotation.y = door.closed_yaw-deg_to_rad(angle)
	door.moving = false
	door.desired_open = angle > 0
	door.sync_proxies()
	game.camera.reset_follow()
	await frames(40)
	var p: Node = game.structure_visibility
	var mesh: MeshInstance3D = game.get_node("Apartment/Architecture/Floor" if p.adjacent_region() == "apartment_501" else "Apartment/Corridor/Floor")
	var authored: Material = mesh.material_override
	var tagged: Material = authored.duplicate()
	if tagged is ShaderMaterial:
		tagged.set_shader_parameter("base_color",Color(1,0,1))
		tagged.set_shader_parameter("base_texture",white)
	else:
		tagged.albedo_color = Color(1,0,1)
		tagged.albedo_texture = white
	mesh.material_override = tagged
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var count := count_tag(picture)
	picture.save_png("res://tests/results/stage6a2e1_raster/"+variant+"_"+label+".png")
	mesh.material_override = authored
	rendered_rows.append({"version":variant,"label":label,"position":str(at),"confirmed_region":p.current_region_id,"adjacent":p.adjacent_region(),"region_weight":p.area_weights.get(p.adjacent_region(),0.0),"neighbor_floor_pixels":count,"angle":angle})
	return count

func run() -> void:
	root.size = Vector2i(1440,1000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute("res://tests/results/stage6a2e1_raster")
	var blank := Image.create(1,1,false,Image.FORMAT_RGBA8)
	blank.fill(Color.WHITE)
	white = ImageTexture.create_from_image(blank)
	var old_problem := -1
	for name in ["before","after"]:
		variant = name
		game = load("res://tests/baselines/stage6a2e1/baseline.tscn" if name == "before" else "res://scenes/apartment/stage6a2e_floor5.tscn").instantiate()
		root.add_child(game)
		await frames(35)
		game.player.set_physics_process(false)
		game.camera.set_mode(2)
		await select_state(84.270422,Vector3(-5.2,0.02,0.92),2)
		for i in 15:
			var x := -4.8+i*0.05
			var count := await neighbor_pixels(Vector3(x,0.02,0.92),"scan_%02d"%i,84.270422)
			if variant == "after": test_result("F2 actual neighbor surface never vanishes at X %.2f"%x,count > 30)
		await select_state(84.270422,Vector3(-5.2,0.02,0.92),2)
		var exact := await neighbor_pixels(Vector3(-4.48,0.02,0.92),"exact_problem",84.270422)
		if name == "before": old_problem = exact
		else:
			test_result("Unmodified original E is reproduced as zero pixels",old_problem == 0)
			test_result("Same camera and stance now renders neighboring content",exact > 30)
			for mode in [1,2,5,6]:
				await select_state(84.270422,Vector3(-5.2,0.02,0.92),mode)
				var opened := await neighbor_pixels(Vector3(-4.48,0.02,0.92),"open_F%d"%mode,84.270422)
				var closed := await neighbor_pixels(Vector3(-5.2,0.02,0.92),"closed_F%d"%mode,0)
				test_result("F%d actual open problem stance is visible"%mode,opened > 30)
				test_result("F%d actual closed leaf has zero neighbor pixels"%mode,closed == 0)
		game.queue_free()
		await process_frame
	var failed: int = raster_checks.filter(func(c):return not c.passed).size()
	var file := FileAccess.open("res://tests/results/stage6a2e1_raster_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":raster_checks.size()-failed,"failed":failed,"checks":raster_checks,"rows":rendered_rows,"manual":"PENDING"},"\t"))
	quit(0 if failed == 0 else 1)
