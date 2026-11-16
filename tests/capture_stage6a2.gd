extends SceneTree
const P = preload("res://scripts/apartment/floor5_layout.gd")
var game: Node3D
var shots: Array = []

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n: await physics_frame

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func shot(label: String,at: Vector3,mode := 6,ratio := 1.0) -> void:
	# Each comparison starts without an unrelated earlier door's transient toast.
	# Dedicated feedback images below still capture real E messages.
	game.message_remaining = 0
	game.message_label.visible = false
	game.player.position = at
	game.camera.set_mode(mode)
	game.camera.target_size = game.camera.active_base_size*ratio
	game.camera.size = game.camera.target_size
	game.camera.reset_follow()
	await frames(40)
	await RenderingServer.frame_post_draw
	var path := "res://screenshots/stage6a2/"+label+".png"
	root.get_texture().get_image().save_png(path)
	shots.append({"path":path,"player":str(at),"mode":mode,"size":game.camera.size,"hidden_segments":game.structure_visibility.hidden_names(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"detection_mean_usec":float(game.structure_visibility.detection_total_usec)/maxi(1,game.structure_visibility.detection_frames)})
	print("CAPTURE "+label)

func run() -> void:
	root.size = Vector2i(1440,1000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage6a2")
	game = load("res://scenes/apartment/stage6a2_floor5.tscn").instantiate()
	root.add_child(game)
	await frames(30)
	game.player.set_physics_process(false)
	await shot("501_closed",P.SPAWN,6,0.7)
	game._unhandled_key_input(key(KEY_E))
	await frames(40)
	await shot("501_open",P.SPAWN,6,0.7)
	for mode in [1,2,5,6]: await shot("floor_overview_F%d"%mode,Vector3(-5.475,0.02,3.30),mode,1.8)
	await shot("corridor_501_502",Vector3(-5.475,0.02,1.11),6,0.7)
	await shot("doorplates_501_502_F5",Vector3(-5.475,0.02,1.11),5,0.65)
	game.player.visual.rotation.y = PI/2
	await shot("locked_502",Vector3(-5.95,0.02,1.11),6,0.6)
	game._unhandled_key_input(key(KEY_E))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/stage6a2/locked_502_feedback.png")
	await shot("corridor_503_504",Vector3(-5.475,0.02,5.46),6,0.7)
	await shot("doorplates_503_504_F5",Vector3(-5.475,0.02,5.46),5,0.65)
	await shot("stairs_closed",Vector3(-5.475,0.02,7.85),6,0.65)
	game._unhandled_key_input(key(KEY_E))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/stage6a2/stairs_feedback.png")
	await shot("501_window_preserved",Vector3(-0.02,0.02,-1.4),6,0.65)
	await shot("bathroom_inside",Vector3(2.15,0.02,1.45),6,0.65)
	await shot("bathroom_restored",Vector3(-0.15,0.02,-0.55),6)
	var output := FileAccess.open("res://tests/results/stage6a2_capture.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"screenshots":shots,"extra_feedback_screenshots":["locked_502_feedback.png","stairs_feedback.png"],"renderer":RenderingServer.get_video_adapter_name(),"meshes":game.find_children("*","MeshInstance3D",true,false).size(),"lights":game.find_children("*","Light3D",true,false).size(),"human_acceptance":"PENDING"},"\t"))
	output.close()
	game.queue_free()
	await process_frame
	quit()
