extends SceneTree
const L = preload("res://scripts/apartment/apartment_layout.gd")
var game: Node3D
var shots: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count: await physics_frame

func shot(label: String) -> void:
	await frames(10)
	await RenderingServer.frame_post_draw
	var path := "res://screenshots/stage6a1/"+label+".png"
	root.get_texture().get_image().save_png(path)
	shots.append(path)
	print("CAPTURE "+label)

func run() -> void:
	root.size = Vector2i(1440,1000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage6a1")
	game = load("res://scenes/apartment/stage6a1_apartment.tscn").instantiate()
	root.add_child(game)
	await frames(24)
	game.player.set_physics_process(false)
	game.player.position = L.ANCHORS.Living
	for mode in [1,2,5,6]:
		game.camera.set_mode(mode)
		game.camera.reset_follow()
		await shot("F%d_overview"%mode)
	for area in ["Bedside","Kitchen","Bathroom"]:
		game.player.position = L.ANCHORS[area]
		game.camera.set_mode(6)
		game.camera.target_size = game.camera.active_base_size*0.6
		game.camera.size = game.camera.target_size
		game.camera.reset_follow()
		await shot(area+"_close")
	game.show_full_walls = true
	game.camera.target_size = game.camera.active_base_size
	game.camera.size = game.camera.target_size
	game.player.position = L.SPAWN
	game.camera.reset_follow()
	await shot("F6_full_walls_entry")
	var file := FileAccess.open("res://tests/results/stage6a1_render.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"screenshots":shots,"renderer":RenderingServer.get_video_adapter_name(),"occlusion_initialized":game.occlusion.initialized,"manual_acceptance":"PENDING"},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit()
