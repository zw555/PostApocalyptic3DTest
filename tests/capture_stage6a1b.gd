extends SceneTree
const L = preload("res://scripts/apartment/apartment_layout.gd")
var game: Node3D
var shots: Array = []
var baseline := false

func _initialize() -> void:
	baseline = "--baseline" in OS.get_cmdline_user_args()
	call_deferred("run")

func frames(count: int) -> void:
	for i in count: await process_frame

func shot(label: String) -> void:
	await frames(30)
	await RenderingServer.frame_post_draw
	var path := "res://screenshots/stage6a1b/"+("before_" if baseline else "after_")+label+".png"
	root.get_texture().get_image().save_png(path)
	shots.append(path)

func run() -> void:
	root.size = Vector2i(1440,1000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage6a1b")
	var scene := "res://scenes/apartment/stage6a1_apartment.tscn" if baseline else "res://scenes/apartment/stage6a1b_apartment.tscn"
	game = load(scene).instantiate()
	root.add_child(game)
	await frames(60)
	game.player.set_physics_process(false)
	game.player.position = L.ANCHORS.Living
	game.camera.set_mode(6)
	game.camera.reset_follow()
	await frames(180)
	var samples: Array[float] = []
	var draws: Array = []
	var previous := Time.get_ticks_usec()
	var total_start := previous
	while samples.size() < 360 or Time.get_ticks_usec()-total_start < 6000000:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		samples.append((now-previous)/1000.0)
		previous = now
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		await process_frame
	var elapsed := (Time.get_ticks_usec()-total_start)/1000000.0
	var sorted := samples.duplicate()
	sorted.sort()
	var windows: Array = []
	for w in 3:
		var sum_ms := 0.0
		var start := int(w*samples.size()/3.0)
		var end := int((w+1)*samples.size()/3.0)
		for i in range(start,end): sum_ms += samples[i]
		windows.append({"mean_ms":sum_ms/(end-start),"fps":1000.0*(end-start)/sum_ms})
	var draw_sum := 0.0
	for value in draws: draw_sum += value
	var light_count := game.find_children("*","Light3D",true,false).size()
	var mesh_count := game.find_children("*","MeshInstance3D",true,false).size()
	var count := samples.size()
	var stats := {"scene":scene,"resolution":[1440,1000],"camera":6,"size":game.camera.size,"position":str(game.player.position),"warmup_frames":180,"samples":count,"elapsed_seconds":elapsed,"fps":count/elapsed,"mean_frame_ms":elapsed*1000/count,"median_ms":sorted[int(count*0.5)],"p95_ms":sorted[int(count*0.95)],"windows":windows,"draw_calls_mean":draw_sum/count,"meshes":mesh_count,"lights":light_count,"nodes":game.find_children("*","Node",true,false).size(),"renderer":RenderingServer.get_video_adapter_name()}
	await shot("F6_overview")
	for mode in [1,2,5]:
		game.camera.set_mode(mode)
		game.camera.reset_follow()
		await shot("F%d_overview"%mode)
	for area in ["Entry","Kitchen","Bathroom","Bedside"]:
		game.player.position = L.SPAWN if area == "Entry" else L.ANCHORS[area]
		game.camera.set_mode(6)
		game.camera.target_size = game.camera.active_base_size*0.6
		game.camera.size = game.camera.target_size
		game.camera.reset_follow()
		await shot(area+"_close")
	game.show_full_walls = true
	game.player.position = L.ANCHORS.Bathroom
	game.camera.reset_follow()
	game.update_cutaway()
	await shot("Bathroom_full_walls" )
	stats["screenshots"] = shots
	stats["human_acceptance"] = "PENDING"
	var output := FileAccess.open("res://tests/results/stage6a1b_"+("before" if baseline else "after")+"_render.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(stats,"\t"))
	output.close()
	print(JSON.stringify(stats))
	game.queue_free()
	await process_frame
	quit()
