extends "res://tests/capture_stage6a2d_views.gd"
var sequence_rows: Array = []

func still(label: String,angle: float,at: Vector3,mode := 6) -> void:
	await select_state(angle,at,mode)
	await RenderingServer.frame_post_draw
	var path := "res://screenshots/stage6a2e/"+variant+"_"+label+".png"
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ",path)

func sequence(opened: float) -> void:
	await select_state(opened,Vector3(-5.2,0.02,1.11),6)
	for index in 180:
		# move_and_slide must execute in a physical step, not in a post-draw
		# continuation whose render delta varies with PNG encoding time.
		await physics_frame
		# Physical movement over the same open doorway, normal camera following.
		var destination := Vector3(-4.05,0.02,1.11) if index < 90 else Vector3(-5.2,0.02,1.11)
		var diff: Vector3 = destination-game.player.position
		diff.y = 0
		var direction := diff.normalized()*minf(0.28,diff.length()*2)
		var right: Vector3 = game.camera.global_basis.x
		var back: Vector3 = game.camera.global_basis.z
		right.y = 0
		back.y = 0
		game.player.step_motion(Vector2(direction.dot(right.normalized()),direction.dot(back.normalized())),1.0/60)
		if index%3 == 0:
			await RenderingServer.frame_post_draw
			var path := "res://screenshots/stage6a2e/sequence/"+variant+"_%03d.png"%(index/3)
			root.get_texture().get_image().save_png(path)
			sequence_rows.append({"variant":variant,"frame":index,"path":path,"position":str(game.player.position),"region":game.structure_visibility.current_region_id,"room_weight":game.structure_visibility.area_weights.apartment_501})

func run() -> void:
	root.size = Vector2i(1440,1000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage6a2e/sequence")
	for name in ["before","after"]:
		variant = name
		game = load("res://scenes/apartment/stage6a2"+("d" if name == "before" else "e")+"_floor5.tscn").instantiate()
		root.add_child(game)
		await frames(35)
		game.player.set_physics_process(false)
		var entry: Node3D = game.get_node("Apartment/Architecture/EntryDoor")
		var opened: float = rad_to_deg(entry.closed_yaw-entry.open_yaw)
		for mode in [1,2,5,6]:
			await still("hall_open_F%d"%mode,opened,Vector3(-5.2,0.02,1.11),mode)
		await still("closed",0,Vector3(-5.2,0.02,1.11))
		await still("partial",30,Vector3(-5.2,0.02,1.11))
		await still("inside",opened,Vector3(-3.95,0.02,0.02))
		await sequence(opened)
		var stats := await benchmark()
		if variant == "after":
			stats["native_sight_mean_usec"] = game.structure_visibility.sight_total_usec/float(maxi(1,game.structure_visibility.sight_refreshes))
		var performance_file := FileAccess.open("res://tests/results/stage6a2e_"+variant+"_performance.json",FileAccess.WRITE)
		performance_file.store_string(JSON.stringify(stats,"\t"))
		game.queue_free()
		await process_frame
	var file := FileAccess.open("res://tests/results/stage6a2e_sequence.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(sequence_rows,"\t"))
	quit()
