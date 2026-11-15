extends "res://tests/loot_capture.gd"
var visibility: Array[Dictionary] = []
var mask_material: StandardMaterial3D
var mask_region: Rect2i
var capture_game: Node3D

func shot(name_value: String) -> void:
	# The root is frozen during mask probes; refresh HUD/target once for this pose.
	capture_game._process(0.0)
	if not capture_game.is_processing():
		capture_game.hint.hide()
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/stage4d3/"+name_value+".png")
	shots.append({"file":name_value,"mode":capture_game.camera.mode,"pitch":capture_game.camera.elevation,"yaw":capture_game.camera.heading,"size":capture_game.camera.size,"player":str(capture_game.player.position),"hud":capture_game.status.text,"walls_hidden":capture_game.camera.wall_debug.walls_hidden})
	print("CAPTURE ",name_value)

func pixel_count() -> int:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var count := 0
	for y in range(mask_region.position.y,mask_region.end.y):
		for x in range(mask_region.position.x,mask_region.end.x):
			var color := image.get_pixel(x,y)
			count += int(color.r > 0.9 and color.g < 0.08 and color.b > 0.9)
	return count

func visibility_probe(game: Node3D, zone: String, point: Vector3, mode: int) -> void:
	game.player.position = point
	game.camera.reset_follow()
	game.camera.set_mode(mode)
	game.camera.size = 13.8
	game.camera.target_size = 13.8
	var first: Vector2 = game.camera.unproject_position(point+Vector3(-0.75,-0.1,-0.75))
	var bounds := Rect2(first,Vector2.ZERO)
	for x in [-0.75,0.75]:
		for y in [-0.1,1.9]:
			for z in [-0.75,0.75]:
				bounds = bounds.expand(game.camera.unproject_position(point+Vector3(x,y,z)))
	bounds = bounds.grow(5).intersection(Rect2(Vector2.ZERO,root.size))
	mask_region = Rect2i(bounds.position.floor(),bounds.size.ceil())
	await shot("occlusion_%s_F%d"%[zone,mode])
	var players: Array = game.player.get_node("Visual").find_children("*","MeshInstance3D",true,false)
	var originals: Dictionary = {}
	for mesh in players:
		originals[mesh] = mesh.material_override
		mesh.material_override = mask_material
	await process_frame
	var seen: int = await pixel_count()
	var surroundings: Dictionary = {}
	for mesh in game.find_children("*","GeometryInstance3D",true,false):
		if mesh not in players:
			surroundings[mesh] = mesh.visible
			mesh.hide()
	await process_frame
	var reference: int = await pixel_count()
	for mesh in surroundings:
		mesh.visible = surroundings[mesh]
	for mesh in originals:
		mesh.material_override = originals[mesh]
	visibility.append({"zone":zone,"mode":mode,"player":str(point),"visible_pixels":seen,"reference_pixels":reference,"visible_fraction":float(seen)/maxi(1,reference),"fully_occluded":seen == 0 and reference > 0})

func benchmark_view(game: Node3D, mode: int) -> void:
	var windows: Array[Dictionary] = []
	for window in 3:
		var times: Array[float] = []
		var last := Time.get_ticks_usec()
		for i in 600:
			await process_frame
			var now := Time.get_ticks_usec()
			times.append((now-last)/1000.0)
			last = now
		times.sort()
		var sum := 0.0
		for value in times:
			sum += value
		windows.append({"frames":600,"mean_ms":sum/600,"p95_ms":times[570],"fps":600000.0/sum,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"rendered_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)})
	metrics.append({"mode":mode,"pitch":game.camera.elevation,"yaw":game.camera.heading,"size":game.camera.size,"player":str(game.player.position),"focus":str(game.camera.focus),"product_instances":count_visible_products(game),"nodes":count_nodes(game),"windows":windows})

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# A desktop resize must not invalidate fixed-resolution image/visibility probes.
	root.mode = Window.MODE_WINDOWED
	root.set_flag(Window.FLAG_RESIZE_DISABLED,true)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	root.size = Vector2i(1440,1000)
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage4d3")
	var game: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	capture_game = game
	root.add_child(game)
	await process_frame
	var camera := configure(game)
	game.player.position = Vector3(-1.05,0,0)
	game.player.visual.rotation.y = -PI/2
	camera.reset_follow()
	for mode in [1,2,5,6]:
		camera.set_mode(mode)
		camera.size = 16.5
		camera.target_size = 16.5
		for i in 240:
			await process_frame
		await benchmark_view(game,mode)
		await shot("store_F%d"%mode)
	game.set_process(false)
	game.hint.hide()
	mask_material = StandardMaterial3D.new()
	mask_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mask_material.albedo_color = Color(1,0,1)
	var points := {"west_wall":Vector3(-5.52,0,-0.5),"north_cold":Vector3(-3.2,0,-2.80),"shelf01_back":Vector3(-4.55,0,-2.25),"shelf02_back":Vector3(-2.1,0,-2.25),"shelf03_back":Vector3(0,0,-2.25),"checkout":Vector3(2.7,0,-1.60),"island_cold":Vector3(1.1,0,1.0),"entry":Vector3(5.75,0,-2.125)}
	for mode in [1,2,5,6]:
		for zone in points:
			await visibility_probe(game,zone,points[zone],mode)
	camera.set_mode(5)
	game.player.position = Vector3(-1.05,0,0)
	camera.reset_follow()
	camera.size = 8.28
	camera.target_size = 8.28
	await shot("player_close45")
	game.player.position = Vector3(-3.15,0,1.25)
	camera.reset_follow()
	await shot("shelf_close45")
	game.player.position = Vector3(2.7,0,-1.60)
	camera.reset_follow()
	await shot("checkout_close45")
	game.player.position = Vector3(-2.1,0,-2.25)
	camera.reset_follow()
	camera.wall_debug.toggle()
	await shot("shelf02_back45_walls_hidden")
	camera.wall_debug.toggle()
	var file := FileAccess.open("res://tests/results/stage4d3_render.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"metrics":metrics,"visibility":visibility,"screenshots":shots,"resolution":"1440x1000","adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"manual_acceptance":"PENDING"},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit()
