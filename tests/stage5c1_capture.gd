extends SceneTree

var game: Node3D
var shots: Array[Dictionary] = []
var checks: Array[Dictionary] = []
var performance_samples: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func wait_frames(count: int) -> void:
	for i in count:
		await process_frame
	await RenderingServer.frame_post_draw

func check(label: String, ok: bool, detail := "") -> void:
	checks.append({"test":label,"passed":ok,"detail":detail})
	print("%s %s %s"%["PASS" if ok else "FAIL",label,detail])

func capture(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "res://screenshots/stage5c1/"+name_value+".png"
	var error := image.save_png(path)
	check("Saved "+name_value,error == OK)
	shots.append({"file":path,"mode":game.camera.mode,"pitch":game.camera.elevation,"size":game.camera.size,"attack_elapsed":game.melee_controller.attack_elapsed,"player":str(game.player.position),"facing":str(-game.player.visual.global_basis.z),"zombie":str(game.zombie.position)})

func click_target() -> void:
	game.aim_controller.update_from_screen(game.camera.unproject_position(game.zombie.global_position),1.0)
	var motion := InputEventMouseMotion.new()
	motion.position = game.camera.unproject_position(game.zombie.global_position)
	root.push_input(motion,true)
	await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = motion.position
	var before: int = game.melee_controller.attack_count
	root.push_input(event,true)
	check("Native click starts capture swing",game.melee_controller.attack_count == before+1)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)

func median(values: Array[float], fraction := 0.5) -> float:
	values.sort()
	return values[mini(values.size()-1,int(values.size()*fraction))]

func profile(enabled: bool, sample_index: int) -> void:
	game.aim_controller.set_process(enabled)
	game.melee_controller.set_physics_process(enabled)
	game.melee_controller.visual.set_process(enabled)
	game.melee_controller.visual.weapon_pivot.visible = enabled
	game.melee_controller.debug_enabled = false
	game.melee_controller.debug_mesh.visible = false
	game.melee_controller.debug_label.visible = false
	var warmup_started := Time.get_ticks_msec()
	while Time.get_ticks_msec()-warmup_started < 1100:
		await process_frame
		await RenderingServer.frame_post_draw
	var walls: Array[float] = []
	var process: Array[float] = []
	var physics: Array[float] = []
	var draws: Array[float] = []
	var last := Time.get_ticks_usec()
	var sample_started := last
	while walls.size() < 120 or Time.get_ticks_usec()-sample_started < 1500000:
		await process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		walls.append((now-last)/1000.0)
		last = now
		process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	performance_samples.append({"melee_enabled":enabled,"sample":sample_index,"frames":walls.size(),"wall_seconds":(Time.get_ticks_usec()-sample_started)/1000000.0,"frame_median_ms":median(walls),"frame_p95_ms":median(walls,0.95),"process_median_ms":median(process),"physics_median_ms":median(physics),"draw_calls_median":median(draws)})

func run() -> void:
	create_timer(180).timeout.connect(func(): push_error("Stage5C1 render watchdog"); quit(2))
	if DisplayServer.get_name() == "headless":
		push_error("Rendered verification requires a real display")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage5c1")
	root.size = Vector2i(1440,1000)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game = load("res://scenes/combat/stage5c1_melee_validation.tscn").instantiate()
	root.add_child(game)
	await wait_frames(24)
	game.zombie.ai_enabled = false
	game.player.controls_enabled = true
	game.player.set_physics_process(false)
	game.aim_controller.set_process(false)
	game.camera.follow_enabled = false
	game.camera.set_process(false)
	game.player.position = Vector3(-3.15,0.02,0.3)
	game.zombie.position = Vector3(-3.15,0.02,-0.85)
	game.camera.reset_follow()
	for mode_value in [5,2,1]:
		game.camera.set_mode(mode_value)
		game.aim_controller.update_from_screen(game.camera.unproject_position(game.zombie.global_position),1.0)
		await wait_frames(50)
		await capture("aim_mode_%d"%mode_value)
		await click_target()
		while game.melee_controller.attack_elapsed < 0.26:
			await process_frame
		await RenderingServer.frame_post_draw
		check("Visible mid-swing in mode %d"%mode_value,game.melee_controller.attack_elapsed < 0.40 and game.melee_controller.visual.trail.visible and game.melee_controller.visual.attack_time < 0.55)
		await capture("attack_mode_%d"%mode_value)
		await wait_frames(50)
		check("World hit in rendered mode %d"%mode_value,game.melee_controller.last_target == game.zombie)
	game.camera.set_mode(2)
	game.melee_controller.debug_enabled = true
	await wait_frames(8)
	check("Debug fan and text visible",game.melee_controller.debug_mesh.visible and game.melee_controller.debug_label.visible)
	await capture("range_debug_65")
	game.melee_controller.debug_enabled = false
	await wait_frames(3)
	check("Disabling debug hides fan and label",not game.melee_controller.debug_mesh.visible and not game.melee_controller.debug_label.visible)
	# Short alternating samples in one unchanged scene. This measures idle
	# component overhead, not a historical before/after or active combat load.
	for i in 4:
		await profile(i%2 == 1,i)
	var failed := checks.filter(func(item): return not item.passed).size()
	var file := FileAccess.open("res://tests/results/stage5c1_render.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":checks.size()-failed,"failed":failed,"tests":checks,"screenshots":shots,"manual_acceptance":"PENDING","resolution":str(root.size),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"performance":performance_samples,"performance_scope":"Same process idle components off/on, AI disabled, 1.1s real warmup and >=1.5s real sampling per round, fixed simulation FPS; no historical baseline or active-combat benchmark."},"\t"))
	file.close()
	game.queue_free()
	await wait_frames(2)
	quit(0 if failed == 0 else 1)
