extends SceneTree
const L = preload("res://scripts/apartment/apartment_layout.gd")
var game: Node3D
var shots: Array = []
var prefix := ""

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for i in 35: await physics_frame
	await RenderingServer.frame_post_draw

func shot(name: String,at: Vector3,mode: int,ratio := 1.0,full := false) -> void:
	game.player.position = at
	game.show_full_walls = full
	game.camera.set_mode(mode)
	game.camera.target_size = game.camera.active_base_size*ratio
	game.camera.size = game.camera.target_size
	game.camera.reset_follow()
	await settle()
	var path := "res://screenshots/stage6a1c/"+prefix+name+".png"
	root.get_texture().get_image().save_png(path)
	var entry := {"path":path,"mode":mode,"size":game.camera.size,"position":str(at),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	if prefix == "after_":
		entry["hidden_bathroom_segments"] = game.bathroom_visibility.hidden_names()
		entry["bath_detection_mean_usec"] = float(game.bathroom_visibility.detection_total_usec)/maxi(1,game.bathroom_visibility.detection_frames)
	shots.append(entry)
	print("CAPTURE "+path)

func run() -> void:
	root.size = Vector2i(1440,1000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage6a1c")
	for variant in ["b","c"]:
		prefix = "before_" if variant == "b" else "after_"
		game = load("res://scenes/apartment/stage6a1"+variant+"_apartment.tscn").instantiate()
		root.add_child(game)
		await settle()
		game.player.set_physics_process(false)
		for mode in [1,2,5,6]: await shot("living_F%d"%mode,L.ANCHORS.Living,mode)
		await shot("bathroom_inside_F6",L.ANCHORS.Shower,6,0.6)
		for mode in [1,2,5]: await shot("bathroom_inside_F%d"%mode,L.ANCHORS.Shower,mode,0.6)
		await shot("bathroom_doorway_F6",Vector3(2.9,0.02,-0.65),6,0.6)
		await shot("bathroom_full_F6",L.ANCHORS.Shower,6,0.6,true)
		await shot("window_F6",Vector3(-0.02,0.02,-1.40),6,0.6,true)
		await shot("window_F2",Vector3(-0.02,0.02,-1.40),2,0.6,true)
		await shot("entry_F6",L.SPAWN,6,0.7)
		# Same live instance: leaving the bathroom restores it without reloading.
		await shot("bathroom_returned_F6",L.ANCHORS.Living,6)
		game.queue_free()
		await process_frame
	var output := FileAccess.open("res://tests/results/stage6a1c_capture.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"screenshots":shots,"renderer":RenderingServer.get_video_adapter_name(),"human_acceptance":"PENDING"},"\t"))
	output.close()
	quit()
