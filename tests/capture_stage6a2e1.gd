extends "res://tests/capture_stage6a2d_views.gd"
var trace: Array = []

func shot_at(label: String,at: Vector3,from_hall := true) -> void:
	await select_state(84.270422,Vector3(-5.2 if from_hall else -4.0,0.02,0.92),2)
	await set_view(at,2,1.0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/stage6a2e1/"+variant+"_"+label+".png")
	var p: Node = game.structure_visibility
	trace.append({"label":label,"position":str(at),"raw":p.region_at(at),"confirmed":p.current_region_id,"weights":p.area_weights.duplicate(),"field_sum":sum_field(p.field_values)})

func sum_field(values: PackedFloat32Array) -> float:
	var total := 0.0
	for value in values: total += value
	return total

func run() -> void:
	variant = "before" if "--before" in OS.get_cmdline_user_args() else "after"
	root.size = Vector2i(1440,1000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage6a2e1")
	game = load("res://tests/baselines/stage6a2e1/baseline.tscn" if variant == "before" else "res://scenes/apartment/stage6a2e_floor5.tscn").instantiate()
	root.add_child(game)
	await frames(35)
	game.player.set_physics_process(false)
	await shot_at("x448_z082",Vector3(-4.48,0.02,0.82))
	await shot_at("x434_z082",Vector3(-4.34,0.02,0.82))
	await shot_at("x470_z082",Vector3(-4.70,0.02,0.82))
	await shot_at("x448_z092_valid",Vector3(-4.48,0.02,0.92))
	await shot_at("x4525_plane",Vector3(-4.525,0.02,0.92))
	await shot_at("x470_reverse",Vector3(-4.70,0.02,0.92),false)
	var file := FileAccess.open("res://tests/results/stage6a2e1_"+variant+"_screens.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(trace,"\t"))
	quit()
