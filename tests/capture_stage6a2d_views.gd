extends "res://tests/capture_stage6a2c.gd"
var checks: Array = []
var diagnostic_rows: Array = []
var white: ImageTexture
var occluded_probe_pixels := 0

func select_state(angle: float,at: Vector3,mode := 6,ratio := 1.0) -> void:
	var entry: Node3D = game.get_node("Apartment/Architecture/EntryDoor")
	entry.moving = false
	entry.blocked = false
	entry.desired_open = angle > 0
	entry.rotation.y = entry.closed_yaw-deg_to_rad(angle)
	entry.sync_proxies()
	await set_view(at,mode,ratio)

func natural(label: String,angle: float,at: Vector3,mode := 6,ratio := 1.0) -> void:
	await select_state(angle,at,mode,ratio)
	await RenderingServer.frame_post_draw
	var path := "res://screenshots/stage6a2d/"+variant+"_"+label+".png"
	root.get_texture().get_image().save_png(path)
	shots.append({"path":path,"angle":angle,"position":str(at),"mode":mode,"size":game.camera.size})
	print("CAPTURE ",path)

func count_tag(picture: Image) -> int:
	picture.convert(Image.FORMAT_RGB8)
	var bytes := picture.get_data()
	var count := 0
	for i in range(0,bytes.size(),3):
		if int(bytes[i]) > int(bytes[i+1])+45 and int(bytes[i+2]) > int(bytes[i+1])+45: count += 1
	return count

func floor_raster(label: String,angle: float,at: Vector3,mode: int,reverse := false) -> int:
	await select_state(angle,at,mode)
	var floor_mesh: MeshInstance3D = game.get_node("Apartment/Architecture/Floor" if reverse else "Apartment/Corridor/Floor")
	var tagged: Array = [floor_mesh]
	if reverse: tagged.append_array(game.get_node("Apartment/Furniture/Bed").find_children("*","MeshInstance3D",true,false))
	var saved := {}
	for mesh in tagged:
		var material := mesh.material_override as ShaderMaterial
		if material == null or saved.has(material): continue
		saved[material] = [material.get_shader_parameter("base_color"),material.get_shader_parameter("base_texture")]
		material.set_shader_parameter("base_color",Color(1,0,1))
		material.set_shader_parameter("base_texture",white)
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var path := "res://tests/results/stage6a2d_raster/"+variant+"_"+label+".png"
	picture.save_png(path)
	var count := count_tag(picture)
	if variant == "after" and reverse and mode == 1 and angle > 0:
		var pixel: Vector2 = game.camera.unproject_position(Vector3(-1.5,0.035,0.7))
		var c := picture.get_pixelv(Vector2i(pixel))
		occluded_probe_pixels = 1 if c.r > c.g+0.18 and c.b > c.g+0.18 else 0
	for material in saved:
		material.set_shader_parameter("base_color",saved[material][0])
		material.set_shader_parameter("base_texture",saved[material][1])
	var row := {"variant":variant,"label":label,"angle":angle,"mode":mode,"position":str(at),"visible_neighbor_surface_pixels":count,"diagnostic_png":path}
	diagnostic_rows.append(row)
	print("RASTER ",row)
	return count

func add_check(label: String,passed: bool) -> void:
	checks.append({"test":label,"passed":passed})
	print("PASS " if passed else "FAIL ",label)

func run() -> void:
	root.size = Vector2i(1440,1000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage6a2d")
	DirAccess.make_dir_recursive_absolute("res://tests/results/stage6a2d_raster")
	var blank := Image.create(1,1,false,Image.FORMAT_RGBA8)
	blank.fill(Color.WHITE)
	white = ImageTexture.create_from_image(blank)
	var all_counts := {}
	for name in ["before","after"]:
		variant = name
		shots.clear()
		game = load("res://scenes/apartment/"+("stage6a2c_floor5.tscn" if variant == "before" else "stage6a2d_floor5.tscn")).instantiate()
		root.add_child(game)
		await frames(30)
		game.player.set_physics_process(false)
		var entry: Node3D = game.get_node("Apartment/Architecture/EntryDoor")
		var opened: float = rad_to_deg(entry.closed_yaw-entry.open_yaw)
		var counts := {}
		for mode in [1,2,5,6]:
			counts["closed_F%d"%mode] = await floor_raster("closed_F%d"%mode,0,Vector3(-3.95,0.02,0.02),mode)
			counts["partial_F%d"%mode] = await floor_raster("partial_F%d"%mode,15,Vector3(-3.95,0.02,0.02),mode)
			counts["open_F%d"%mode] = await floor_raster("open_F%d"%mode,opened,Vector3(-3.95,0.02,0.02),mode)
			counts["reverse_F%d"%mode] = await floor_raster("reverse_F%d"%mode,opened,Vector3(-5.2,0.02,1.11),mode,true)
			counts["reverse_closed_F%d"%mode] = await floor_raster("reverse_closed_F%d"%mode,0,Vector3(-5.2,0.02,1.11),mode,true)
			await natural("inside_open_F%d"%mode,opened,Vector3(-4.05,0.02,0.65),mode)
			await natural("reverse_open_F%d"%mode,opened,Vector3(-5.2,0.02,1.11),mode)
		await natural("inside_closed",0,Vector3(-3.95,0.02,0.02))
		await natural("inside_partial_15",15,Vector3(-3.95,0.02,0.02))
		await natural("inside_open",opened,Vector3(-3.95,0.02,0.02))
		await natural("inside_left",opened,Vector3(-4.05,0.02,0.65))
		await natural("inside_right",opened,Vector3(-4.15,0.02,1.25))
		await natural("inside_far",opened,Vector3(-0.15,0.02,-0.55))
		await natural("reverse_closed",0,Vector3(-5.2,0.02,1.11))
		await natural("bathroom",opened,Vector3(2.15,0.02,1.45))
		await select_state(opened,Vector3(-5.475,0.02,3.3))
		var stats := await benchmark()
		stats["natural_screenshots"] = shots.duplicate(true)
		if variant == "after":
			stats["native_fan_mean_usec"] = game.structure_visibility.fan_total_usec/float(maxi(game.structure_visibility.fan_refreshes,1))
			stats["camera_ray_queries"] = game.structure_visibility.camera_ray_queries
			stats["camera_ray_total_usec"] = game.structure_visibility.camera_ray_total_usec
		var output := FileAccess.open("res://tests/results/stage6a2d_"+variant+"_render.json",FileAccess.WRITE)
		output.store_string(JSON.stringify(stats,"\t"))
		output.close()
		all_counts[variant] = counts
		game.queue_free()
		await process_frame
	for mode in [1,2,5,6]:
		var before: Dictionary = all_counts.before
		var after: Dictionary = all_counts.after
		add_check("F%d closed native door reveals zero adjacent floor pixels"%mode,after["closed_F%d"%mode] == 0)
		add_check("F%d partly opened door actually renders local adjacent floor"%mode,after["partial_F%d"%mode] > 50)
		add_check("F%d fully opened door actually renders local adjacent floor"%mode,after["open_F%d"%mode] > 100)
		add_check("F%d reverse doorway view actually renders existing 501 surfaces"%mode,after["reverse_F%d"%mode] > 50)
		add_check("F%d closing real leaf removes reverse 501 surface pixels"%mode,after["reverse_closed_F%d"%mode] == 0)
		add_check("F%d camera-only predecessor loses area now visible from player eye"%mode,after["open_F%d"%mode] > before["open_F%d"%mode] or after["reverse_F%d"%mode] > before["reverse_F%d"%mode])
	add_check("Existing bed hides deeper floor in actual overhead raster",occluded_probe_pixels == 0)
	var failed := checks.filter(func(c): return not c.passed).size()
	var output := FileAccess.open("res://tests/results/stage6a2d_raster_validation.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":checks.size()-failed,"failed":failed,"checks":checks,"rows":diagnostic_rows,"note":"Runtime magenta tags on EXISTING neighbor surfaces (hall floor outward, 501 floor/bed materials reverse); natural delivery PNGs are unmodified. Native geometry, ray, shader and camera depth participate. Not human acceptance."},"\t"))
	output.close()
	quit(0 if failed == 0 else 1)
