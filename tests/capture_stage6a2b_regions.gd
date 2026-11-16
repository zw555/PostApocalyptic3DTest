extends SceneTree
const P = preload("res://scripts/apartment/floor5_layout.gd")
var game: Node3D
var variant := "before"
var shots: Array = []
var roi_values := {}

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count: await physics_frame

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func set_view(at: Vector3,mode: int,ratio: float) -> void:
	game.player.position = at
	game.player.velocity = Vector3.ZERO
	game.message_remaining = 0
	game.camera.set_mode(mode)
	game.camera.target_size = game.camera.active_base_size*ratio
	game.camera.size = game.camera.target_size
	game.camera.reset_follow()
	await frames(35)

func luminance(picture: Image,pixel: Vector2) -> float:
	var total := 0.0
	for x in range(-3,4):
		for y in range(-3,4):
			var at := Vector2i(pixel)+Vector2i(x,y)
			at.x = clampi(at.x,0,picture.get_width()-1)
			at.y = clampi(at.y,0,picture.get_height()-1)
			var c := picture.get_pixelv(at)
			total += c.r*0.2126+c.g*0.7152+c.b*0.0722
	return total/49

func shot(label: String,at: Vector3,mode := 6,ratio := 1.0) -> void:
	await set_view(at,mode,ratio)
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var path := "res://screenshots/stage6a2b_regions/"+variant+"_"+label+".png"
	picture.save_png(path)
	if label == "overview_F1":
		for number in ["502","503","504"]:
			var center: Vector2 = P.ROOMS[number].get_center()
			roi_values[number] = luminance(picture,game.camera.unproject_position(Vector3(center.x,0.03,center.y)))
	shots.append({"path":path,"position":str(at),"mode":mode,"size":game.camera.size,"hidden_walls":game.structure_visibility.hidden_names()})
	print("CAPTURE "+path)

func benchmark() -> Dictionary:
	await set_view(Vector3(-5.475,0.02,3.30),6,1.0)
	for i in 180: await process_frame
	var samples: Array[float] = []
	var draws := 0.0
	var start := Time.get_ticks_usec()
	var previous := start
	while samples.size() < 360 or Time.get_ticks_usec()-start < 6000000:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		samples.append((now-previous)/1000.0)
		previous = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		await process_frame
	var elapsed := (Time.get_ticks_usec()-start)/1000000.0
	var sorted := samples.duplicate()
	sorted.sort()
	var windows: Array = []
	for w in 3:
		var first := int(w*samples.size()/3.0)
		var last := int((w+1)*samples.size()/3.0)
		var total := 0.0
		for i in range(first,last): total += samples[i]
		windows.append({"fps":1000.0*(last-first)/total,"mean_ms":total/(last-first)})
	return {"warmup_frames":180,"samples":samples.size(),"elapsed_seconds":elapsed,"fps":samples.size()/elapsed,"mean_ms":elapsed*1000/samples.size(),"median_ms":sorted[int(samples.size()*0.5)],"p95_ms":sorted[int(samples.size()*0.95)],"draw_calls":draws/samples.size(),"windows":windows,"resolution":[1440,1000],"mode":6,"size":game.camera.size,"player":str(game.player.position),"meshes":game.find_children("*","MeshInstance3D",true,false).size(),"lights":game.find_children("*","Light3D",true,false).size()}

func run() -> void:
	root.size = Vector2i(1440,1000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage6a2b_regions")
	var variants := ["before","after"]
	var ran_after := false
	if "--before-only" in OS.get_cmdline_user_args(): variants = ["before"]
	if "--after-only" in OS.get_cmdline_user_args(): variants = ["after"]
	for name in variants:
		variant = name
		if variant == "after": ran_after = true
		shots.clear()
		roi_values.clear()
		game = load("res://scenes/apartment/"+("stage6a2b_floor5.tscn" if variant == "before" else "stage6a2b_regions_floor5.tscn")).instantiate()
		root.add_child(game)
		await frames(30)
		game.player.set_physics_process(false)
		game._unhandled_key_input(key(KEY_E))
		await frames(35)
		var stats := await benchmark()
		for mode in [1,2,5,6]: await shot("overview_F%d"%mode,Vector3(-5.475,0.02,3.30),mode,1.8)
		await shot("501_living",Vector3(-0.15,0.02,-0.55))
		await shot("501_threshold",Vector3(-4.55,0.02,1.08),6,0.7)
		await shot("corridor_501_502",Vector3(-5.475,0.02,1.11),6,0.7)
		await shot("corridor_503_504",Vector3(-5.475,0.02,5.46),6,0.7)
		await shot("stairs",Vector3(-5.475,0.02,7.85),6,0.7)
		await shot("bathroom",Vector3(2.15,0.02,1.45),6,0.65)
		await shot("returned_501",Vector3(-0.15,0.02,-0.55))
		stats["screenshots"] = shots.duplicate(true)
		stats["placeholder_luminance_F1"] = roi_values.duplicate()
		stats["renderer"] = RenderingServer.get_video_adapter_name()
		stats["human_acceptance"] = "PENDING"
		var output := FileAccess.open("res://tests/results/stage6a2b_regions_"+variant+"_render.json",FileAccess.WRITE)
		output.store_string(JSON.stringify(stats,"\t"))
		output.close()
		game.queue_free()
		await process_frame
	quit()


